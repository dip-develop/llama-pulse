import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../server/server_output.dart';

/// Lists the generated llama.cpp parameter catalog.
final class ParamsCatalogCommand extends LlamaPulseCommand {
  /// Creates the command.
  ParamsCatalogCommand(super.services) {
    argParser
      ..addOption(
        'surface',
        allowed: ['all', 'server', 'embedded'],
        defaultsTo: 'all',
        help: 'Only list parameters that apply to this surface.',
      )
      ..addMultiOption(
        'group',
        splitCommas: false,
        help: 'Only list this parameter group; repeatable.',
      )
      ..addFlag(
        'include-unsupported',
        negatable: false,
        help: 'Also list unsupported and removed parameters.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print the catalog as a single-line JSON object.',
      );
  }

  @override
  String get name => 'catalog';

  @override
  String get description =>
      'List the ${ParameterCatalog.v080.upstreamTag} llama.cpp parameters.';

  @override
  bool get takesArguments => false;

  @override
  Future<int> run() async {
    final catalog = ParameterCatalog.v080;
    final surface = parsedArgs.option('surface') ?? 'all';
    final requestedGroups = parsedArgs.multiOption('group');
    final knownGroups = {for (final group in catalog.groups) group.id};
    final unknownGroups = [
      for (final group in requestedGroups)
        if (!knownGroups.contains(group)) group,
    ];
    if (unknownGroups.isNotEmpty) {
      for (final group in unknownGroups) {
        services.err.writeln(
          "error: unknown parameter group '$group' "
          '(run `llamapulse params catalog`)',
        );
      }
      return ExitCodes.usage;
    }

    final includeUnsupported = parsedArgs.flag('include-unsupported');
    bool exposed(ParameterSpec spec) =>
        includeUnsupported ||
        (spec.exposure != ParamExposure.unsupported &&
            spec.exposure != ParamExposure.removed);

    final onSurface = surface == 'all'
        ? catalog.parameters
        : catalog.forSurface(ParamSurface.fromWire(surface));
    final groupFilter = requestedGroups.toSet();
    final parameters = [
      for (final spec in onSurface)
        if (exposed(spec) &&
            (groupFilter.isEmpty || groupFilter.contains(spec.group)))
          spec,
    ];
    final groups = [
      for (final group in catalog.groups)
        if (parameters.any((spec) => spec.group == group.id)) group,
    ];

    if (parsedArgs.flag('json')) {
      writeJsonLine(
        services.out,
        encodeCatalog(
          catalog: catalog,
          surface: surface,
          parameters: parameters,
          groups: groups,
        ),
      );
      return ExitCodes.ok;
    }

    for (var index = 0; index < groups.length; index++) {
      final group = groups[index];
      services.out.writeln('${group.name} (${group.id})');
      for (final spec in parameters) {
        if (spec.group != group.id) {
          continue;
        }
        services.out.writeln(
          '  ${spec.id}  ${spec.flags.join(' ')}  ${spec.type.wireName}  '
          'default=${_defaultText(spec)}  ${spec.exposure.wireName}',
        );
      }
      if (index < groups.length - 1) {
        services.out.writeln();
      }
    }
    return ExitCodes.ok;
  }

  static String _defaultText(ParameterSpec spec) {
    final value = ParameterValueCodec.formatDefault(spec);
    return value.isEmpty ? '-' : value;
  }
}
