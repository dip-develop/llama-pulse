import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/file_picker.dart';
import '../../common/parameters/parameter_filter.dart';
import '../../common/parameters/parameter_panel.dart';
import '../bloc/server_bloc.dart';
import '../bloc/server_dashboard_state.dart';
import '../bloc/server_event.dart';

/// The catalog panel of the server dashboard: one card under the essentials
/// form.
///
/// Only this card subscribes to the bloc, and it selects the configuration
/// alone, so a metrics or log sample never reaches the panel. Each edit is a
/// [ServerParamChanged] event; the bloc owns the values and the dirty flag.
class ServerParametersCard extends StatelessWidget {
  /// Creates the card.
  const ServerParametersCard({super.key, required this.filePicker});

  /// File dialog seam used by the Browse buttons of path parameters.
  final FilePicker filePicker;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('server-params-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocSelector<ServerBloc, ServerDashboardState, ServerConfig>(
          selector: (ServerDashboardState state) => state.config,
          builder: (BuildContext context, ServerConfig config) {
            final ServerBloc bloc = context.read<ServerBloc>();
            return ParameterPanel(
              params: config.params,
              filePicker: filePicker,
              editable: editableServerParameters(),
              lockedGroups: serverLockedParameterGroups(),
              valueForLocked: (ParameterSpec spec) =>
                  ParameterValues.valueFor(config, spec.id),
              onChanged: (String id, String? value) =>
                  bloc.add(ServerParamChanged(id, value)),
              onReset: (Set<String> ids) => bloc.add(ServerParamsReset(ids)),
            );
          },
        ),
      ),
    );
  }
}
