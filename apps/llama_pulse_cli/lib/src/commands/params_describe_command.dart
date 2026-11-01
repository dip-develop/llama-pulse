import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../command_runner.dart';
import '../exit_codes.dart';
import '../output.dart';
import '../server/server_output.dart';

/// Prints the full catalog entry for one parameter.
final class ParamsDescribeCommand extends LlamaPulseCommand {
  /// Creates the command.
  ParamsDescribeCommand(super.services) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print the parameter as a single-line JSON object.',
    );
  }

  @override
  String get name => 'describe';

  @override
  String get description => 'Print everything the catalog knows about one id.';

  @override
  Future<int> run() async {
    final rest = parsedArgs.rest;
    if (rest.length != 1) {
      services.err.writeln(
        'error: expected exactly one parameter id '
        '(run `llamapulse params catalog`)',
      );
      return ExitCodes.usage;
    }

    final id = rest.single;
    final spec = ParameterCatalog.v080.byId(id);
    if (spec == null) {
      services.err.writeln(
        "error: unknown parameter '$id' (run `llamapulse params catalog`)",
      );
      return ExitCodes.usage;
    }

    if (parsedArgs.flag('json')) {
      writeJsonLine(services.out, {
        'schemaVersion': serverOutputSchemaVersion,
        ...encodeParameter(spec),
      });
      return ExitCodes.ok;
    }

    services.out
      ..writeln('id: ${spec.id}')
      ..writeln('flags: ${spec.flags.join(' ')}');
    final negated = spec.negatedFlag;
    if (negated != null) {
      services.out.writeln('negatedFlag: $negated');
    }
    services.out
      ..writeln('summary: ${spec.summary}')
      ..writeln('description: ${spec.description}')
      ..writeln('type: ${spec.type.wireName}');
    final defaultValue = ParameterValueCodec.formatDefault(spec);
    services.out.writeln(
      'default: ${defaultValue.isEmpty ? '-' : defaultValue}',
    );
    final range = _range(spec);
    if (range != null) {
      services.out.writeln('range: $range');
    }
    if (spec.allowed.isNotEmpty) {
      services.out.writeln('allowed: ${spec.allowed.join(', ')}');
    }
    if (spec.allowed.isEmpty && spec.itemType != null) {
      services.out.writeln('itemType: ${spec.itemType!.wireName}');
    }
    if (spec.repeatable) {
      services.out.writeln('repeatable: yes');
    }
    final envVar = spec.envVar;
    if (envVar != null) {
      services.out.writeln('env: $envVar');
    }
    final surfaces = spec.surfaces.map((surface) => surface.wireName);
    services.out
      ..writeln('surfaces: ${surfaces.isEmpty ? '-' : surfaces.join(', ')}')
      ..writeln('exposure: ${spec.exposure.wireName}');
    final owner = spec.owner;
    if (owner != null) {
      services.out.writeln('owner: $owner');
    }
    final managedBy = spec.managedBy;
    if (managedBy != null) {
      services.out.writeln('managedBy: $managedBy');
    }
    final reason = spec.reason;
    if (reason != null) {
      services.out.writeln('reason: $reason');
    }
    final replacement = spec.replacement;
    if (replacement != null) {
      services.out.writeln('replacement: $replacement');
    }
    if (spec.requiresExistingPath) {
      services.out.writeln('requiresExistingPath: yes');
    }
    final warning = spec.warning;
    if (warning != null) {
      services.out.writeln('warning: $warning');
    }
    return ExitCodes.ok;
  }

  static String? _range(ParameterSpec spec) {
    final min = spec.min;
    final max = spec.max;
    if (min == null && max == null) {
      return null;
    }
    return '${min ?? ''}..${max ?? ''}';
  }
}
