import '../../domain/entities/model_params.dart';
import '../../domain/entities/parameter_spec.dart';
import '../../domain/parameters/parameter_catalog.dart';
import '../../domain/parameters/parameter_value_codec.dart';

/// Builds the `llama-cli` argument vector for [ModelParams].
///
/// The typed fields come first, in the fixed order below, followed by the
/// catalog parameters stored in [ModelParams.params] in catalog order. The
/// resulting list is an argument vector: tokens are never shell-quoted.
final class ModelArgumentBuilder {
  /// Creates a builder.
  ///
  /// [catalog] supplies the declaration order and the flag spelling of the
  /// generic parameters stored in [ModelParams.params].
  const ModelArgumentBuilder({this.catalog = ParameterCatalog.v080});

  /// Catalog that describes the generic parameters.
  final ParameterCatalog catalog;

  /// Returns the raw argument tokens for [params].
  ///
  /// The typed block is `-m`, `-c`, `-t`, `-ngl`, `--temp`, `--top-k`,
  /// `--top-p` and `-b`. The model path is omitted when it is empty and the
  /// batch size is omitted when it is absent or zero. Every other embedded
  /// parameter follows in catalog order.
  ///
  /// `chat-template` is typed on [ModelParams] but is emitted at its catalog
  /// position, between `--min-p` and the server flags. A typed template wins
  /// over a stale map entry; an absent typed template still falls back to the
  /// map, matching `ParameterValues.valueForModel`.
  List<String> build(ModelParams params) {
    final arguments = <String>[];

    if (params.modelPath.isNotEmpty) {
      arguments.addAll(['-m', params.modelPath]);
    }

    arguments.addAll([
      '-c',
      '${params.contextSize}',
      '-t',
      '${params.threads}',
      '-ngl',
      '${params.gpuLayers}',
      '--temp',
      '${params.temperature}',
      '--top-k',
      '${params.topK}',
      '--top-p',
      '${params.topP}',
    ]);

    final batch = _batchSize(params);
    if (batch != null && batch != '0') {
      arguments.addAll(['-b', batch]);
    }

    _appendParameters(arguments, params);
    return arguments;
  }

  /// Returns the canonical `batch-size` value stored on [params], or `null`.
  ///
  /// The batch size is not a typed [ModelParams] field, so it lives in the
  /// catalog map and is emitted inside the typed block. An invalid value is a
  /// document error: failing here beats emitting garbage on the command line.
  String? _batchSize(ModelParams params) {
    final raw = params.params['batch-size'];
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final spec = catalog.byId('batch-size');
    if (spec == null) {
      return null;
    }
    try {
      return ParameterValueCodec.parse(spec, raw);
    } on FormatException catch (error) {
      throw ArgumentError.value(raw, spec.id, error.message);
    }
  }

  /// Appends the remaining embedded catalog parameters in catalog order.
  ///
  /// Iterating the catalog, not the map, keeps the vector independent of the
  /// map's insertion order. Ids already emitted in the typed block are skipped,
  /// and managed, unsupported and removed parameters never reach the command
  /// line: the validator rejects them, and skipping them here keeps a
  /// hand-edited document from producing an ambiguous command.
  void _appendParameters(List<String> arguments, ModelParams params) {
    for (final spec in catalog.parameters) {
      // The chat template has a typed field, so the map entry is only a
      // fallback for a hand-edited document.
      if (spec.id == 'chat-template' &&
          params.chatTemplate != null &&
          params.chatTemplate!.isNotEmpty) {
        if (spec.flags.isNotEmpty && spec.appliesTo(ParamSurface.embedded)) {
          arguments.addAll([_preferredFlag(spec), params.chatTemplate!]);
        }
        continue;
      }
      final raw = params.params[spec.id];
      if (raw == null) {
        continue;
      }
      if (_typedIds.contains(spec.id) ||
          spec.owner != null ||
          spec.exposure != ParamExposure.configurable ||
          !spec.appliesTo(ParamSurface.embedded) ||
          spec.flags.isEmpty) {
        continue;
      }

      final value = _parse(spec, raw);
      if (value == null) {
        continue;
      }
      final flag = _preferredFlag(spec);

      if (spec.type == ParamValueType.bool && spec.arity == 0) {
        switch (value) {
          case 'true':
            arguments.add(flag);
          case 'false':
            final negated = spec.negatedFlag;
            if (negated != null) {
              arguments.add(negated);
            }
        }
        continue;
      }

      if (spec.arity == 2) {
        arguments.addAll([flag, ...value.split('\n')]);
        continue;
      }

      if (spec.repeatable) {
        for (final item in value.split('\n')) {
          arguments.addAll([flag, item]);
        }
        continue;
      }

      arguments.addAll([flag, value]);
    }
  }

  /// Returns the canonical form of [raw], or `null` when it means "not set".
  ///
  /// The validator is the normal gate, so an invalid stored value is a
  /// programming or document error; failing here beats emitting garbage.
  String? _parse(ParameterSpec spec, String raw) {
    try {
      return ParameterValueCodec.parse(spec, raw);
    } on FormatException catch (error) {
      throw ArgumentError.value(raw, spec.id, error.message);
    }
  }

  /// Returns the long form of the parameter when it has one.
  static String _preferredFlag(ParameterSpec spec) => spec.flags.firstWhere(
    (flag) => flag.startsWith('--'),
    orElse: () => spec.flags.first,
  );

  /// Ids the typed block already covers.
  ///
  /// `batch-size` has no typed field but is emitted with the block, so the
  /// generic loop must not repeat it.
  static const Set<String> _typedIds = {
    'model',
    'ctx-size',
    'threads',
    'gpu-layers',
    'temp',
    'top-k',
    'top-p',
    'batch-size',
  };
}
