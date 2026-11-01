/// Generates the `llama.cpp` parameter catalog for the pinned tag.
///
/// Reads the vendored `common/arg.cpp`, parses every `add_opt(common_arg(...))`
/// block, applies the reviewed overrides, and writes:
///
/// * `catalog/llama_args.v0.8.0.yaml` — the reviewed catalog document;
/// * `lib/src/data/catalog/parameter_catalog.generated.dart` — the const Dart
///   catalog.
///
/// Run with `--check` to compare instead of write; drift exits with code 1.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
// The tool runs before the generated part is guaranteed to exist, so it
// imports the three building blocks directly instead of the public barrel.
import 'package:llama_pulse_core/src/data/catalog/catalog_digest.dart';
import 'package:llama_pulse_core/src/data/catalog/upstream_arg_parser.dart';
import 'package:llama_pulse_core/src/data/config/yaml_encoder.dart';
import 'package:llama_pulse_core/src/domain/entities/parameter_spec.dart';
import 'package:yaml/yaml.dart';

const _tag = 'v0.8.0';
const _sourceRelative = 'third_party/llama_cpp/v0.8.0/source/arg.cpp';
const _catalogRelative =
    'packages/llama_pulse_core/catalog/llama_args.v0.8.0.yaml';
const _overridesRelative =
    'packages/llama_pulse_core/catalog/llama_args.v0.8.0.overrides.yaml';
const _dartRelative =
    'packages/llama_pulse_core/lib/src/data/catalog/'
    'parameter_catalog.generated.dart';

void main(List<String> arguments) {
  final check = arguments.contains('--check');
  try {
    final root = _repoRoot();
    final result = _generate(root);
    // The emitter is deliberately simple; let the SDK formatter own Dart
    // layout so a hand-run `dart format` never produces a diff.
    final dart = _formatted(result.dart);
    final yamlFile = File('${root.path}/$_catalogRelative');
    final dartFile = File('${root.path}/$_dartRelative');
    if (check) {
      final drift = <String>[
        if (!yamlFile.existsSync() ||
            yamlFile.readAsStringSync() != result.yaml)
          _catalogRelative,
        if (!dartFile.existsSync() || dartFile.readAsStringSync() != dart)
          _dartRelative,
      ];
      if (drift.isNotEmpty) {
        stderr.writeln(
          'catalog is out of date: ${drift.join(', ')}\n'
          'run: dart run tool/args/generate_catalog.dart',
        );
        exitCode = 1;
        return;
      }
      stdout.writeln(
        'catalog is up to date '
        '(${result.parameters} parameters, digest ${result.digest})',
      );
      return;
    }
    yamlFile.parent.createSync(recursive: true);
    yamlFile.writeAsStringSync(result.yaml);
    dartFile.parent.createSync(recursive: true);
    dartFile.writeAsStringSync(dart);
    stdout.writeln(
      'wrote ${result.parameters} parameters, ${result.groups} groups, '
      'digest ${result.digest}',
    );
  } on GeneratorError catch (error) {
    stderr.writeln('error: ${error.message}');
    exitCode = 1;
  }
}

/// A generation failure with an actionable message.
final class GeneratorError implements Exception {
  /// Creates a generator error.
  const GeneratorError(this.message);

  /// Human-readable explanation.
  final String message;
}

final class _Generated {
  const _Generated({
    required this.yaml,
    required this.dart,
    required this.parameters,
    required this.groups,
    required this.digest,
  });

  final String yaml;
  final String dart;
  final int parameters;
  final int groups;
  final String digest;
}

_Generated _generate(Directory root) {
  final sourceFile = File('${root.path}/$_sourceRelative');
  final overridesFile = File('${root.path}/$_overridesRelative');
  if (!sourceFile.existsSync()) {
    throw GeneratorError('missing vendored source: $_sourceRelative');
  }
  if (!overridesFile.existsSync()) {
    throw GeneratorError('missing override catalog: $_overridesRelative');
  }

  final source = sourceFile.readAsStringSync();
  final parsed = parseUpstreamArgs(source);
  if (parsed.failures.isNotEmpty) {
    final details = parsed.failures.map((failure) => '$failure').join('\n');
    throw GeneratorError('could not parse arg.cpp:\n$details');
  }

  final overrides = _Overrides.read(
    _decodeYaml(overridesFile.readAsStringSync()),
  );
  final sha256Hex = sha256.convert(sourceFile.readAsBytesSync()).toString();
  if (overrides.sha256 != sha256Hex) {
    throw GeneratorError(
      'arg.cpp sha256 mismatch: override catalog records '
      '${overrides.sha256}, file is $sha256Hex',
    );
  }

  final catalog = _buildCatalog(parsed.definitions, overrides);

  final body = <String, Object?>{
    'schemaVersion': 1,
    'source': catalog.source,
    'groups': [for (final group in catalog.groups) _groupMap(group)],
    'parameters': [for (final spec in catalog.parameters) _parameterMap(spec)],
  };
  final digest = catalogDigest(
    body,
    (bytes) => sha256.convert(bytes).toString(),
  );
  final document = <String, Object?>{
    'schemaVersion': 1,
    'source': catalog.source,
    'digest': digest,
    'groups': body['groups']!,
    'parameters': body['parameters']!,
  };
  final yaml = _yamlHeader() + YamlEncoder.encode(document);
  final dart = _emitDart(catalog, digest, sha256Hex);

  return _Generated(
    yaml: yaml,
    dart: dart,
    parameters: catalog.parameters.length,
    groups: catalog.groups.length,
    digest: digest,
  );
}

final class _Catalog {
  const _Catalog({
    required this.source,
    required this.groups,
    required this.parameters,
  });

  final Map<String, Object?> source;
  final List<ParameterGroupSpec> groups;
  final List<ParameterSpec> parameters;
}

_Catalog _buildCatalog(
  List<UpstreamArgDefinition> definitions,
  _Overrides overrides,
) {
  final groups = overrides.groups;
  final groupIds = {for (final group in groups) group.id};

  final byFlags = <String, List<UpstreamArgDefinition>>{};
  for (final definition in definitions) {
    final key = definition.flags.join('\u0000');
    byFlags.putIfAbsent(key, () => []).add(definition);
  }

  final selected = <UpstreamArgDefinition>[];
  final unclassified = <String>[];
  for (final entry in byFlags.entries) {
    var visible = entry.value.where((d) => d.isVisibleToServer).toList();
    if (visible.length > 1) {
      // -np/--parallel is declared twice inside `if (ex == SERVER) ... else`:
      // the server branch names SERVER explicitly, the other inherits COMMON.
      // The explicit server definition is the one llama-server actually sees.
      final serverSpecific = visible
          .where((d) => d.examples.contains('SERVER'))
          .toList();
      if (serverSpecific.length == 1) {
        visible = serverSpecific;
      } else {
        throw GeneratorError(
          'duplicate server-visible definition for '
          '${entry.key.replaceAll('\u0000', ' ')} '
          'on lines ${visible.map((d) => d.line).join(', ')}',
        );
      }
    }
    if (visible.isEmpty) {
      final id = _idOf(entry.value.first);
      if (!overrides.unsupportedIds.contains(id) &&
          !overrides.removedIds.contains(id)) {
        unclassified.add('$id (line ${entry.value.first.line})');
        continue;
      }
      selected.add(entry.value.first);
      continue;
    }
    // A second definition with the same flags is a per-tool variant (for
    // example -np/--parallel for the parallel example). The server-visible
    // definition wins; the variant is not part of this surface.
    selected.add(visible.single);
  }
  if (unclassified.isNotEmpty) {
    throw GeneratorError(
      'definitions not visible to llama-server must be classified as '
      'unsupported or removed: ${unclassified.join(', ')}',
    );
  }
  selected.sort((a, b) => a.line.compareTo(b.line));

  final specs = <ParameterSpec>[];
  final ids = <String>{};
  final flags = <String, String>{};
  var syntheticCount = 0;
  final synthetic = overrides.synthetic;

  ParameterSpec buildSynthetic(_SyntheticParameter entry) {
    final spec = ParameterSpec(
      id: entry.id,
      displayName: entry.displayName,
      summary: entry.summary,
      description: entry.description,
      flags: entry.flags,
      negatedFlag: null,
      type: entry.type,
      arity: entry.arity,
      defaultValue: null,
      min: null,
      max: null,
      step: null,
      allowed: const [],
      itemType: null,
      repeatable: entry.repeatable,
      group: entry.group,
      surfaces: const [ParamSurface.server],
      exposure: ParamExposure.managed,
      owner: entry.owner,
      managedBy: entry.managedBy,
      envVar: null,
      advanced: false,
      deprecated: false,
      replacement: null,
      requiresExistingPath: false,
      warning: entry.warning,
      reason: entry.reason,
    );
    syntheticCount++;
    return spec;
  }

  for (final definition in selected) {
    final id = _idOf(definition);
    if (!ids.add(id)) {
      throw GeneratorError(
        'duplicate parameter id $id '
        '(line ${definition.line})',
      );
    }
    final curated = overrides.curated[id];
    final managed = overrides.managed[id];
    final removed = overrides.removed[id];
    final unsupportedReason = overrides.unsupported[id];

    final exposure = switch ((removed, managed, unsupportedReason)) {
      (final _RemovedEntry _, _, _) => ParamExposure.removed,
      (_, final _ManagedEntry _, _) => ParamExposure.managed,
      (_, _, final String _) => ParamExposure.unsupported,
      _ => ParamExposure.configurable,
    };

    final group = switch (exposure) {
      ParamExposure.removed || ParamExposure.unsupported => 'unsupported',
      _ => overrides.groupOf(id),
    };
    if (!groupIds.contains(group)) {
      throw GeneratorError('parameter $id references unknown group "$group"');
    }

    final type = curated?.type ?? _inferType(definition, curated);
    final allowed = curated?.allowed ?? _inferAllowed(definition, type);
    final effectiveType =
        curated?.type ??
        (allowed.isNotEmpty &&
                _isEnumHint(definition) &&
                type != ParamValueType.bool
            ? ParamValueType.enumeration
            : type);

    final help = _cleanHelp(definition.help);
    final summary = curated?.summary ?? _summaryOf(help, id);
    final description = curated?.description ?? help;
    final displayName = curated?.displayName ?? _humanize(id);
    final defaultValue =
        curated?.defaultValue ??
        (curated?.hasDefaultValue ?? false
            ? null
            : _inferDefault(definition.help));

    final spec = ParameterSpec(
      id: id,
      displayName: displayName,
      summary: summary,
      description: description,
      flags: definition.flags,
      negatedFlag: definition.negatedFlags.isEmpty
          ? null
          : definition.negatedFlags.first,
      type: effectiveType,
      arity: definition.arity,
      defaultValue: defaultValue,
      min: curated?.min,
      max: curated?.max,
      step: curated?.step,
      allowed: allowed,
      itemType: overrides.itemTypes[id],
      repeatable: overrides.repeatableIds.contains(id),
      group: group,
      surfaces: switch (exposure) {
        ParamExposure.removed || ParamExposure.unsupported => const [],
        _ =>
          overrides.embeddedIds.contains(id)
              ? const [ParamSurface.server, ParamSurface.embedded]
              : const [ParamSurface.server],
      },
      exposure: exposure,
      owner: curated?.owner ?? managed?.owner,
      managedBy: managed?.managedBy,
      envVar: definition.envVar,
      advanced: overrides.isAdvanced(id),
      deprecated:
          (curated?.deprecated ?? false) || _looksDeprecated(definition.help),
      replacement: removed?.replacement,
      requiresExistingPath:
          curated?.requiresExistingPath ??
          overrides.requiresExistingPathIds.contains(id),
      warning: curated?.warning,
      reason: switch (exposure) {
        ParamExposure.removed => removed?.reason,
        ParamExposure.unsupported => unsupportedReason,
        ParamExposure.managed => managed?.reason,
        ParamExposure.configurable => curated?.reason,
      },
    );
    specs.add(spec);
    for (final flag in spec.flags) {
      final existing = flags[flag];
      if (existing != null && existing != spec.id) {
        throw GeneratorError(
          'flag $flag is declared by both $existing and ${spec.id}',
        );
      }
      flags[flag] = spec.id;
    }
  }

  for (final entry in synthetic) {
    if (!ids.add(entry.id)) {
      throw GeneratorError('synthetic id ${entry.id} duplicates a catalog id');
    }
    final spec = buildSynthetic(entry);
    if (!groupIds.contains(spec.group)) {
      throw GeneratorError(
        'synthetic parameter ${spec.id} references unknown group '
        '"${spec.group}"',
      );
    }
    specs.add(spec);
    for (final flag in spec.flags) {
      final existing = flags[flag];
      if (existing != null) {
        throw GeneratorError(
          'synthetic flag $flag is already declared by $existing',
        );
      }
      flags[flag] = spec.id;
    }
  }

  // Every override id must name a real parameter. Group entries are checked
  // in _Overrides.read; exposure and curation entries are checked here.
  for (final id in overrides.referencedIds) {
    if (!ids.contains(id)) {
      throw GeneratorError('override references unknown parameter id "$id"');
    }
  }
  for (final id in overrides.groupMap.keys) {
    if (!ids.contains(id)) {
      throw GeneratorError('groupMap references unknown parameter id "$id"');
    }
  }
  if (syntheticCount != overrides.synthetic.length) {
    throw GeneratorError('synthetic parameter list is inconsistent');
  }

  return _Catalog(
    source: {
      'project': overrides.project,
      'tag': overrides.tag,
      'commit': overrides.commit,
      'file': overrides.file,
      'sha256': overrides.sha256,
      'surface': overrides.surface,
    },
    groups: groups,
    parameters: specs,
  );
}

String _idOf(UpstreamArgDefinition definition) {
  for (final flag in definition.flags) {
    if (flag.startsWith('--') && flag.length > 2) {
      return flag.substring(2);
    }
  }
  final short = definition.flags.first;
  return short.replaceFirst(RegExp(r'^-+'), '');
}

ParamValueType _inferType(UpstreamArgDefinition definition, _Curated? curated) {
  if (definition.handler == 'bool' ||
      definition.handler == 'void' ||
      definition.negatedFlags.isNotEmpty) {
    return ParamValueType.bool;
  }
  if (_isPathHint(definition.valueHints)) {
    return ParamValueType.path;
  }
  if (definition.handler == 'int') {
    return ParamValueType.int;
  }
  if (definition.handler == 'str_str') {
    return ParamValueType.string;
  }
  if (definition.handler == 'string') {
    if (_hasIntDefault(definition.help) && !_hasFloatDefault(definition.help)) {
      return ParamValueType.int;
    }
    if (_hasFloatDefault(definition.help)) {
      return ParamValueType.double;
    }
    return ParamValueType.string;
  }
  throw GeneratorError(
    'cannot infer a value type for ${_idOf(definition)} '
    '(handler ${definition.handler})',
  );
}

bool _isPathHint(List<String> hints) {
  for (final hint in hints) {
    final upper = hint.toUpperCase();
    if (upper.contains('FNAME') ||
        upper.contains('FILE') ||
        upper.contains('PATH') ||
        upper.contains('DIR')) {
      return true;
    }
  }
  return false;
}

bool _hasFloatDefault(String help) => RegExp(r'%[-0-9.]*[fge]').hasMatch(help);

bool _hasIntDefault(String help) => RegExp(r'%[-0-9.]*[diouxz]').hasMatch(help);

bool _isEnumHint(UpstreamArgDefinition definition) {
  if (definition.valueHints.isEmpty) {
    return false;
  }
  final hint = definition.valueHints.first.trim();
  final values = _enumTokens(hint);
  return values != null && values.length >= 2;
}

/// Returns the allow-list encoded in a hint such as `[on|off|auto]` or
/// `{none,mean,cls,last,rank}`, or `null`.
List<String>? _enumTokens(String hint) {
  String? body;
  String? separator;
  if (hint.startsWith('[') && hint.endsWith(']')) {
    body = hint.substring(1, hint.length - 1);
    separator = '|';
  } else if (hint.startsWith('{') && hint.endsWith('}')) {
    body = hint.substring(1, hint.length - 1);
    separator = ',';
  }
  if (body == null || separator == null) {
    return null;
  }
  final tokens = body.split(separator).map((token) => token.trim()).toList();
  if (tokens.any(
    (token) => !RegExp(r'^[A-Za-z][A-Za-z0-9_.+-]*$').hasMatch(token),
  )) {
    return null;
  }
  return tokens;
}

List<String> _inferAllowed(
  UpstreamArgDefinition definition,
  ParamValueType type,
) {
  if (type == ParamValueType.bool || type == ParamValueType.path) {
    return const [];
  }
  if (definition.valueHints.isEmpty) {
    return const [];
  }
  return _enumTokens(definition.valueHints.first) ?? const [];
}

Object? _inferDefault(String help) {
  final match = RegExp(r'\(default: ([^)]*)\)').firstMatch(help);
  if (match == null) {
    return null;
  }
  var token = match.group(1)!.trim();
  if (token.isEmpty || token.contains('%')) {
    return null;
  }
  token = token.split(',').first.trim();
  final quoted =
      (token.startsWith("'") && token.endsWith("'")) ||
      (token.startsWith('"') && token.endsWith('"'));
  if (quoted && token.length >= 2) {
    token = token.substring(1, token.length - 1);
  }
  if (token == 'true') {
    return true;
  }
  if (token == 'false') {
    return false;
  }
  final integer = int.tryParse(token);
  if (integer != null) {
    return integer;
  }
  final decimal = double.tryParse(token);
  if (decimal != null) {
    return decimal;
  }
  if (quoted) {
    return token;
  }
  // A bare word is usually prose ("unused", "empty", "disabled"), which
  // describes the absence of a value. Only the switch-like words upstream
  // accepts unquoted are kept.
  if (token == 'on' || token == 'off' || token == 'auto') {
    return token;
  }
  return null;
}

bool _looksDeprecated(String help) =>
    RegExp('deprecat', caseSensitive: false).hasMatch(help);

String _cleanHelp(String help) {
  var text = help;
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (match) => '(${match.group(1)})',
  );
  text = text.replaceAll(
    RegExp(r'\(default: [^)]*%[^)]*\)'),
    '(default: automatic)',
  );
  text = text.replaceAll(RegExp(r'%[-0-9.]*[a-zA-Z]'), 'a value');
  text = text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
  return text.trim();
}

String _summaryOf(String help, String id) {
  if (help.isEmpty) {
    return _humanize(id);
  }
  final flat = help.replaceAll('\n', ' ');
  // Split only where the next word starts a new sentence, so abbreviations
  // such as "i.e." and "e.g." do not truncate the summary.
  var summary = flat;
  for (final match in RegExp(r'\.(?:\s|$)').allMatches(flat)) {
    final rest = flat.substring(match.end).trimLeft();
    if (rest.isEmpty || RegExp(r'^[A-Z0-9(]').hasMatch(rest)) {
      summary = flat.substring(0, match.end).trimRight();
      break;
    }
  }
  if (summary.length > 160) {
    final cut = summary.lastIndexOf(' ', 157);
    summary = '${summary.substring(0, cut == -1 ? 157 : cut).trimRight()}...';
  }
  return summary.isEmpty
      ? summary
      : summary[0].toUpperCase() + summary.substring(1);
}

const _acronyms = <String, String>{
  'api': 'API',
  'cpu': 'CPU',
  'cors': 'CORS',
  'ctx': 'context',
  'dry': 'DRY',
  'ent': 'entropy',
  'exp': 'exponent',
  'fps': 'FPS',
  'gpu': 'GPU',
  'hf': 'Hugging Face',
  'http': 'HTTP',
  'json': 'JSON',
  'kv': 'KV',
  'lora': 'LoRA',
  'lr': 'LR',
  'mcp': 'MCP',
  'mib': 'MiB',
  'moe': 'MoE',
  'mtmd': 'MTMD',
  'ngl': 'NGL',
  'numa': 'NUMA',
  'ppl': 'PPL',
  'rpc': 'RPC',
  'rope': 'RoPE',
  'sse': 'SSE',
  'ssl': 'SSL',
  'swa': 'SWA',
  'tts': 'TTS',
  'ui': 'UI',
  'url': 'URL',
  'xtc': 'XTC',
  'yarn': 'YaRN',
};

String _humanize(String id) {
  final words = id.split('-');
  final out = <String>[];
  for (var index = 0; index < words.length; index++) {
    final word = words[index];
    final acronym = _acronyms[word];
    if (acronym != null) {
      out.add(acronym);
    } else if (index == 0) {
      out.add(word[0].toUpperCase() + word.substring(1));
    } else {
      out.add(word);
    }
  }
  return out.join(' ');
}

String _yamlHeader() => '''
# Generated by packages/llama_pulse_core/tool/args/generate_catalog.dart.
# Do not edit by hand: change llama_args.v0.8.0.overrides.yaml and regenerate.
''';

Map<String, Object?> _groupMap(ParameterGroupSpec group) => {
  'id': group.id,
  'name': group.name,
  'order': group.order,
  'defaultOpen': group.defaultOpen,
};

Map<String, Object?> _parameterMap(ParameterSpec spec) => {
  'id': spec.id,
  'displayName': spec.displayName,
  'summary': spec.summary,
  'description': spec.description,
  'flags': spec.flags,
  'negatedFlag': spec.negatedFlag,
  'type': spec.type.wireName,
  'arity': spec.arity,
  'defaultValue': spec.defaultValue,
  'min': spec.min,
  'max': spec.max,
  'step': spec.step,
  'allowed': spec.allowed,
  'itemType': spec.itemType?.wireName,
  'repeatable': spec.repeatable,
  'group': spec.group,
  'surfaces': [for (final surface in spec.surfaces) surface.wireName],
  'exposure': spec.exposure.wireName,
  'owner': spec.owner,
  'managedBy': spec.managedBy,
  'envVar': spec.envVar,
  'advanced': spec.advanced,
  'deprecated': spec.deprecated,
  'replacement': spec.replacement,
  'requiresExistingPath': spec.requiresExistingPath,
  'warning': spec.warning,
  'reason': spec.reason,
};

String _emitDart(_Catalog catalog, String digest, String sha256) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('//')
    ..writeln('// Generated by tool/args/generate_catalog.dart from')
    ..writeln('// $_sourceRelative.')
    ..writeln('// Regenerate with: dart run tool/args/generate_catalog.dart')
    ..writeln()
    ..writeln("part of 'parameter_catalog.dart';")
    ..writeln()
    ..writeln('const ParameterCatalog _catalogV080 = ParameterCatalog._(')
    ..writeln("  upstreamTag: '${_escape(_tag)}',")
    ..writeln(
      "  upstreamCommit: '${_escape(catalog.source['commit']! as String)}',",
    )
    ..writeln("  upstreamFileSha256: '${_escape(sha256)}',")
    ..writeln("  digest: '${_escape(digest)}',")
    ..writeln('  groups: [');
  for (final group in catalog.groups) {
    out
      ..writeln('    ParameterGroupSpec(')
      ..writeln("      id: '${_escape(group.id)}',")
      ..writeln("      name: '${_escape(group.name)}',")
      ..writeln('      order: ${group.order},')
      ..writeln('      defaultOpen: ${group.defaultOpen},')
      ..writeln('    ),');
  }
  out
    ..writeln('  ],')
    ..writeln('  parameters: [');
  for (final spec in catalog.parameters) {
    out
      ..writeln('    ParameterSpec(')
      ..writeln("      id: '${_escape(spec.id)}',")
      ..writeln("      displayName: '${_escape(spec.displayName)}',")
      ..writeln("      summary: '${_escape(spec.summary)}',")
      ..writeln("      description: '${_escape(spec.description)}',")
      ..writeln('      flags: [');
    for (final flag in spec.flags) {
      out.writeln("        '${_escape(flag)}',");
    }
    out
      ..writeln('      ],')
      ..writeln(
        '      negatedFlag: '
        '${spec.negatedFlag == null ? 'null' : "'${_escape(spec.negatedFlag!)}'"},',
      )
      ..writeln('      type: ParamValueType.${spec.type.name},')
      ..writeln('      arity: ${spec.arity},')
      ..writeln('      defaultValue: ${_dartValue(spec.defaultValue)},')
      ..writeln('      min: ${spec.min},')
      ..writeln('      max: ${spec.max},')
      ..writeln('      step: ${spec.step},')
      ..writeln('      allowed: [');
    for (final value in spec.allowed) {
      out.writeln("        '${_escape(value)}',");
    }
    out
      ..writeln('      ],')
      ..writeln(
        '      itemType: '
        '${spec.itemType == null ? 'null' : 'ParamValueType.${spec.itemType!.name}'},',
      )
      ..writeln('      repeatable: ${spec.repeatable},')
      ..writeln("      group: '${_escape(spec.group)}',")
      ..writeln('      surfaces: [');
    for (final surface in spec.surfaces) {
      out.writeln('        ParamSurface.${surface.name},');
    }
    out
      ..writeln('      ],')
      ..writeln('      exposure: ParamExposure.${spec.exposure.name},')
      ..writeln(
        '      owner: '
        '${spec.owner == null ? 'null' : "'${_escape(spec.owner!)}'"},',
      )
      ..writeln(
        '      managedBy: '
        '${spec.managedBy == null ? 'null' : "'${_escape(spec.managedBy!)}'"},',
      )
      ..writeln(
        '      envVar: '
        '${spec.envVar == null ? 'null' : "'${_escape(spec.envVar!)}'"},',
      )
      ..writeln('      advanced: ${spec.advanced},')
      ..writeln('      deprecated: ${spec.deprecated},')
      ..writeln(
        '      replacement: '
        '${spec.replacement == null ? 'null' : "'${_escape(spec.replacement!)}'"},',
      )
      ..writeln('      requiresExistingPath: ${spec.requiresExistingPath},')
      ..writeln(
        '      warning: '
        '${spec.warning == null ? 'null' : "'${_escape(spec.warning!)}'"},',
      )
      ..writeln(
        '      reason: '
        '${spec.reason == null ? 'null' : "'${_escape(spec.reason!)}'"},',
      )
      ..writeln('    ),');
  }
  out
    ..writeln('  ],')
    ..writeln(');')
    ..writeln();
  return out.toString();
}

String _dartValue(Object? value) => switch (value) {
  null => 'null',
  final bool flag => '$flag',
  final int number => '$number',
  final double number => number.toString(),
  final String text => "'${_escape(text)}'",
  _ => throw GeneratorError('unsupported default value: ${value.runtimeType}'),
};

String _escape(String value) {
  final out = StringBuffer();
  for (final unit in value.codeUnits) {
    switch (unit) {
      case 0x5c:
        out.write(r'\\');
      case 0x27:
        out.write(r"\'");
      case 0x24:
        out.write(r'\$');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      default:
        if (unit < 0x20) {
          out.write(r'\u{');
          out.write(unit.toRadixString(16));
          out.write('}');
        } else {
          out.writeCharCode(unit);
        }
    }
  }
  return out.toString();
}

String _formatted(String source) {
  final directory = Directory.systemTemp.createTempSync('llama_pulse_catalog_');
  try {
    final file = File('${directory.path}/parameter_catalog.generated.dart')
      ..writeAsStringSync(source);
    final result = Process.runSync(Platform.resolvedExecutable, [
      'format',
      file.path,
    ]);
    if (result.exitCode != 0) {
      throw GeneratorError(
        'dart format failed on the generated catalog: ${result.stderr}',
      );
    }
    return file.readAsStringSync();
  } finally {
    directory.deleteSync(recursive: true);
  }
}

Directory _repoRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    if (File('${directory.path}/$_sourceRelative').existsSync()) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw const GeneratorError(
        'could not find the repository root above the current directory',
      );
    }
    directory = parent;
  }
}

Object? _decodeYaml(String text) {
  try {
    return loadYaml(text);
  } on YamlException catch (error) {
    throw GeneratorError('invalid override YAML: ${error.message}');
  }
}

// ---------------------------------------------------------------------------
// Override catalog
// ---------------------------------------------------------------------------

final class _ManagedEntry {
  const _ManagedEntry({
    required this.owner,
    required this.managedBy,
    required this.reason,
  });

  final String? owner;
  final String managedBy;
  final String reason;
}

final class _RemovedEntry {
  const _RemovedEntry({required this.replacement, required this.reason});

  final String? replacement;
  final String reason;
}

final class _SyntheticParameter {
  const _SyntheticParameter({
    required this.id,
    required this.displayName,
    required this.summary,
    required this.description,
    required this.flags,
    required this.type,
    required this.arity,
    required this.repeatable,
    required this.group,
    required this.owner,
    required this.managedBy,
    required this.reason,
    required this.warning,
  });

  final String id;
  final String displayName;
  final String summary;
  final String description;
  final List<String> flags;
  final ParamValueType type;
  final int arity;
  final bool repeatable;
  final String group;
  final String? owner;
  final String managedBy;
  final String reason;
  final String? warning;
}

final class _Curated {
  const _Curated({
    this.displayName,
    this.summary,
    this.description,
    this.type,
    this.defaultValue,
    this.hasDefaultValue = false,
    this.min,
    this.max,
    this.step,
    this.allowed,
    this.owner,
    this.requiresExistingPath,
    this.advanced,
    this.deprecated,
    this.warning,
    this.reason,
  });

  final String? displayName;
  final String? summary;
  final String? description;
  final ParamValueType? type;
  final Object? defaultValue;
  final bool hasDefaultValue;
  final num? min;
  final num? max;
  final num? step;
  final List<String>? allowed;
  final String? owner;
  final bool? requiresExistingPath;
  final bool? advanced;
  final bool? deprecated;
  final String? warning;
  final String? reason;
}

final class _Overrides {
  const _Overrides({
    required this.project,
    required this.tag,
    required this.commit,
    required this.file,
    required this.sha256,
    required this.surface,
    required this.groups,
    required this.groupMap,
    required this.managed,
    required this.removed,
    required this.unsupported,
    required this.curated,
    required this.synthetic,
    required this.embeddedIds,
    required this.repeatableIds,
    required this.requiresExistingPathIds,
    required this.itemTypes,
    required this.advancedIds,
    required this.advancedPrefixes,
    required this.referencedIds,
  });

  final String project;
  final String tag;
  final String commit;
  final String file;
  final String sha256;
  final String surface;
  final List<ParameterGroupSpec> groups;
  final Map<String, String> groupMap;
  final Map<String, _ManagedEntry> managed;
  final Map<String, _RemovedEntry> removed;
  final Map<String, String> unsupported;
  final Map<String, _Curated> curated;
  final List<_SyntheticParameter> synthetic;
  final Set<String> embeddedIds;
  final Set<String> repeatableIds;
  final Set<String> requiresExistingPathIds;
  final Map<String, ParamValueType> itemTypes;
  final Set<String> advancedIds;
  final List<String> advancedPrefixes;
  final Set<String> referencedIds;

  Set<String> get unsupportedIds => unsupported.keys.toSet();

  Set<String> get removedIds => removed.keys.toSet();

  String groupOf(String id) {
    final group = groupMap[id];
    if (group == null) {
      throw GeneratorError(
        'parameter $id has no group; add it to groupMap in the overrides',
      );
    }
    return group;
  }

  bool isAdvanced(String id) =>
      advancedIds.contains(id) ||
      advancedPrefixes.any((prefix) => id.startsWith(prefix));

  static _Overrides read(Object? decoded) {
    final root = _asMap(decoded, 'overrides');
    final source = _asMap(root['source'], 'source');
    final groups = <ParameterGroupSpec>[];
    for (final raw in _asList(root['groups'], 'groups')) {
      final map = _asMap(raw, 'groups[]');
      groups.add(
        ParameterGroupSpec(
          id: _string(map['id'], 'groups[].id'),
          name: _string(map['name'], 'groups[].name'),
          order: _integer(map['order'], 'groups[].order'),
          defaultOpen: _boolean(map['defaultOpen'], 'groups[].defaultOpen'),
        ),
      );
    }
    groups.sort((a, b) => a.order.compareTo(b.order));

    final groupMap = <String, String>{};
    for (final entry in _asMap(root['groupMap'], 'groupMap').entries) {
      for (final raw in _asList(entry.value, 'groupMap.${entry.key}')) {
        final id = raw as String?;
        if (id == null) {
          throw const GeneratorError('groupMap entries must be strings');
        }
        final existing = groupMap[id];
        if (existing != null && existing != entry.key) {
          throw GeneratorError(
            'parameter $id is listed in both $existing and ${entry.key}',
          );
        }
        groupMap[id] = entry.key;
      }
    }

    final managed = <String, _ManagedEntry>{};
    for (final raw in _asList(root['managed'], 'managed')) {
      final map = _asMap(raw, 'managed[]');
      final id = _string(map['id'], 'managed[].id');
      managed[id] = _ManagedEntry(
        owner: _optionalString(map['owner']),
        managedBy: _string(map['managedBy'], 'managed[].managedBy'),
        reason: _string(map['reason'], 'managed[].reason'),
      );
    }

    final removed = <String, _RemovedEntry>{};
    for (final raw in _asList(root['removed'], 'removed')) {
      final map = _asMap(raw, 'removed[]');
      final id = _string(map['id'], 'removed[].id');
      removed[id] = _RemovedEntry(
        replacement: _optionalString(map['replacement']),
        reason: _string(map['reason'], 'removed[].reason'),
      );
    }

    final unsupported = <String, String>{};
    for (final raw in _asList(root['unsupported'], 'unsupported')) {
      final map = _asMap(raw, 'unsupported[]');
      final reason = _string(map['reason'], 'unsupported[].reason');
      for (final value in _asList(map['ids'], 'unsupported[].ids')) {
        final id = value as String?;
        if (id == null) {
          throw const GeneratorError('unsupported ids must be strings');
        }
        if (unsupported.containsKey(id)) {
          throw GeneratorError('parameter $id is unsupported twice');
        }
        unsupported[id] = reason;
      }
    }

    final curated = <String, _Curated>{};
    final curatedMap = root['curated'] == null
        ? <String, Object?>{}
        : _asMap(root['curated'], 'curated');
    for (final entry in curatedMap.entries) {
      final map = _asMap(entry.value, 'curated.${entry.key}');
      final allowed = map['allowed'] == null
          ? null
          : [
              for (final value in _asList(map['allowed'], 'curated.allowed'))
                _string(value, 'curated.allowed[]'),
            ];
      curated[entry.key] = _Curated(
        displayName: _optionalString(map['displayName']),
        summary: _optionalString(map['summary']),
        description: _optionalString(map['description']),
        type: _optionalString(map['type']) == null
            ? null
            : ParamValueType.fromWire(_string(map['type'], 'curated.type')),
        defaultValue: map['defaultValue'],
        hasDefaultValue: map.containsKey('defaultValue'),
        min: _optionalNum(map['min'], 'curated.min'),
        max: _optionalNum(map['max'], 'curated.max'),
        step: _optionalNum(map['step'], 'curated.step'),
        allowed: allowed,
        owner: _optionalString(map['owner']),
        requiresExistingPath: _optionalBool(map['requiresExistingPath']),
        advanced: _optionalBool(map['advanced']),
        deprecated: _optionalBool(map['deprecated']),
        warning: _optionalString(map['warning']),
        reason: _optionalString(map['reason']),
      );
    }

    final synthetic = <_SyntheticParameter>[];
    for (final raw in _asList(
      root['synthetic'] ?? const <Object?>[],
      'synthetic',
    )) {
      final map = _asMap(raw, 'synthetic[]');
      synthetic.add(
        _SyntheticParameter(
          id: _string(map['id'], 'synthetic[].id'),
          displayName: _string(map['displayName'], 'synthetic[].displayName'),
          summary: _string(map['summary'], 'synthetic[].summary'),
          description: _string(map['description'], 'synthetic[].description'),
          flags: [
            for (final value in _asList(map['flags'], 'synthetic[].flags'))
              _string(value, 'synthetic[].flags[]'),
          ],
          type: ParamValueType.fromWire(
            _string(map['type'], 'synthetic[].type'),
          ),
          arity: _integer(map['arity'], 'synthetic[].arity'),
          repeatable: _boolean(map['repeatable'], 'synthetic[].repeatable'),
          group: _string(map['group'], 'synthetic[].group'),
          owner: _optionalString(map['owner']),
          managedBy: _string(map['managedBy'], 'synthetic[].managedBy'),
          reason: _string(map['reason'], 'synthetic[].reason'),
          warning: _optionalString(map['warning']),
        ),
      );
    }

    final embeddedIds = _stringSet(root['embeddedIds'], 'embeddedIds');
    final repeatableIds = _stringSet(root['repeatableIds'], 'repeatableIds');
    final requiresExistingPathIds = _stringSet(
      root['requiresExistingPathIds'],
      'requiresExistingPathIds',
    );
    final itemTypes = <String, ParamValueType>{};
    if (root['itemTypes'] != null) {
      for (final entry in _asMap(root['itemTypes'], 'itemTypes').entries) {
        itemTypes[entry.key] = ParamValueType.fromWire(
          _string(entry.value, 'itemTypes.${entry.key}'),
        );
      }
    }
    final advancedIds = _stringSet(root['advancedIds'], 'advancedIds');
    final advancedPrefixes = [
      for (final value in _asList(
        root['advancedPrefixes'] ?? const <Object?>[],
        'advancedPrefixes',
      ))
        _string(value, 'advancedPrefixes[]'),
    ];

    final referenced = <String>{
      ...managed.keys,
      ...removed.keys,
      ...unsupported.keys,
      ...curated.keys,
      ...embeddedIds,
      ...repeatableIds,
      ...requiresExistingPathIds,
      ...itemTypes.keys,
      ...advancedIds,
    };

    final overrides = _Overrides(
      project: _string(source['project'], 'source.project'),
      tag: _string(source['tag'], 'source.tag'),
      commit: _string(source['commit'], 'source.commit'),
      file: _string(source['file'], 'source.file'),
      sha256: _string(source['sha256'], 'source.sha256'),
      surface: _string(source['surface'], 'source.surface'),
      groups: groups,
      groupMap: groupMap,
      managed: managed,
      removed: removed,
      unsupported: unsupported,
      curated: curated,
      synthetic: synthetic,
      embeddedIds: embeddedIds,
      repeatableIds: repeatableIds,
      requiresExistingPathIds: requiresExistingPathIds,
      itemTypes: itemTypes,
      advancedIds: advancedIds,
      advancedPrefixes: advancedPrefixes,
      referencedIds: referenced,
    );

    if (overrides.tag != _tag) {
      throw GeneratorError(
        'override catalog source.tag is ${overrides.tag}, expected $_tag',
      );
    }
    if (overrides.file != _sourceRelative) {
      throw GeneratorError(
        'override catalog source.file is ${overrides.file}, expected '
        '$_sourceRelative',
      );
    }
    final clashes = <String>{};
    for (final pair in <(String, Set<String>, Set<String>)>[
      ('managed/removed', managed.keys.toSet(), removed.keys.toSet()),
      ('managed/unsupported', managed.keys.toSet(), unsupported.keys.toSet()),
      ('removed/unsupported', removed.keys.toSet(), unsupported.keys.toSet()),
    ]) {
      clashes.addAll(pair.$2.toSet()..retainAll(pair.$3));
    }
    if (clashes.isNotEmpty) {
      throw GeneratorError(
        'parameters classified twice: ${clashes.join(', ')}',
      );
    }
    return overrides;
  }
}

Map<String, Object?> _asMap(Object? value, String what) {
  if (value is! Map<Object?, Object?>) {
    throw GeneratorError('$what must be a mapping');
  }
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    map[entry.key.toString()] = entry.value;
  }
  return map;
}

List<Object?> _asList(Object? value, String what) {
  if (value is! List<Object?>) {
    throw GeneratorError('$what must be a list');
  }
  return value;
}

String _string(Object? value, String what) {
  if (value is! String) {
    throw GeneratorError('$what must be a string');
  }
  return value;
}

String? _optionalString(Object? value) => value is String ? value : null;

int _integer(Object? value, String what) {
  if (value is! int) {
    throw GeneratorError('$what must be an integer');
  }
  return value;
}

bool _boolean(Object? value, String what) {
  if (value is! bool) {
    throw GeneratorError('$what must be a boolean');
  }
  return value;
}

bool? _optionalBool(Object? value) => value is bool ? value : null;

num? _optionalNum(Object? value, String what) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value;
  }
  throw GeneratorError('$what must be a number');
}

Set<String> _stringSet(Object? value, String what) {
  if (value == null) {
    return const {};
  }
  return {for (final item in _asList(value, what)) _string(item, '$what[]')};
}
