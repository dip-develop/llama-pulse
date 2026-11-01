import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../app/platform/file_picker.dart';
import '../../common/parameters/parameter_filter.dart';
import '../../common/parameters/parameter_panel.dart';
import '../bloc/inference_bloc.dart';
import '../bloc/inference_event.dart';
import '../bloc/inference_state.dart';

/// Catalog ids the essentials form edits through a typed [ModelParams] field.
///
/// Six of them are catalog-managed with a typed owner. `chat-template` is
/// configurable in the catalog but still has `ModelParams.chatTemplate`, and
/// the form above edits that field, so the panel must not duplicate it.
const Set<String> chatOwnedParameterIds = {
  'ctx-size',
  'threads',
  'gpu-layers',
  'temp',
  'top-k',
  'top-p',
  'chat-template',
};

/// Group id of the locked container for values the essentials form owns.
const String chatManagedGroupId = 'chat-managed';

/// Group id of the locked container for flags without an embedded equivalent.
const String chatServerOnlyGroupId = 'chat-server-only';

/// Exact explanation shown for every server-only row.
const String chatServerOnlyReason =
    'embedded engine cannot honor this parameter yet';

const ParameterGroupSpec _managedGroup = ParameterGroupSpec(
  id: chatManagedGroupId,
  name: 'Set in the essentials form',
  order: 900,
  defaultOpen: false,
);

const ParameterGroupSpec _serverOnlyGroup = ParameterGroupSpec(
  id: chatServerOnlyGroupId,
  name: 'Not available in the embedded engine',
  order: 999,
  defaultOpen: false,
);

/// Rows the chat panel edits directly: embedded, configurable and not owned by
/// a typed field of the essentials form.
List<ParameterSpec> chatEditableParameters() => [
  for (final ParameterSpec spec in ParameterCatalog.v080.forSurface(
    ParamSurface.embedded,
  ))
    if (spec.exposure == ParamExposure.configurable &&
        spec.owner == null &&
        !chatOwnedParameterIds.contains(spec.id))
      spec,
];

/// Embedded rows the essentials form owns, in catalog order.
List<ParameterSpec> chatOwnedParameters() => [
  for (final ParameterSpec spec in ParameterCatalog.v080.forSurface(
    ParamSurface.embedded,
  ))
    if (chatOwnedParameterIds.contains(spec.id)) spec,
];

/// Every flag `llama-server` accepts that the embedded engine cannot honour.
///
/// Unsupported and removed catalog entries carry no surface at all, so they are
/// not "server-only" and stay out of this container.
List<ParameterSpec> chatServerOnlyParameters() => [
  for (final ParameterSpec spec in ParameterCatalog.v080.forSurface(
    ParamSurface.server,
  ))
    if (!spec.appliesTo(ParamSurface.embedded)) spec,
];

/// The locked containers of the chat panel.
///
/// The owned ids are shown locked with their effective typed value instead of
/// being hidden. Omitting them would leave the panel unable to answer "what is
/// set" for the values the session actually uses, and the count would silently
/// disagree with the rows. They stay read-only because the essentials form owns
/// the only editable control for each one.
List<LockedParameterGroup> chatLockedParameterGroups() => [
  LockedParameterGroup(
    spec: _managedGroup,
    parameters: chatOwnedParameters(),
    reason:
        'Set by the essentials form above; edit it there and save once for '
        'both.',
  ),
  LockedParameterGroup(
    spec: _serverOnlyGroup,
    parameters: chatServerOnlyParameters(),
    reason: chatServerOnlyReason,
    showValue: false,
  ),
];

/// The catalog panel of the embedded chat: one card under the essentials form.
///
/// Only this card subscribes to the bloc for the panel, and it selects the
/// parameters alone, so a metrics sample or a streamed token never reaches the
/// panel. Each edit is an [InferenceParamChanged] event; the bloc owns the
/// values and the existing Save action persists them.
class ChatParametersCard extends StatelessWidget {
  /// Creates the card.
  const ChatParametersCard({super.key, required this.filePicker});

  /// File dialog seam used by the Browse buttons of path parameters.
  final FilePicker filePicker;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('chat-params-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocSelector<InferenceBloc, InferenceState, ModelParams>(
          selector: (InferenceState state) => state.params,
          builder: (BuildContext context, ModelParams params) {
            final InferenceBloc bloc = context.read<InferenceBloc>();
            return ParameterPanel(
              params: params.params,
              filePicker: filePicker,
              editable: chatEditableParameters(),
              lockedGroups: chatLockedParameterGroups(),
              valueForLocked: (ParameterSpec spec) =>
                  ParameterValues.valueForModel(params, spec.id),
              title: 'Chat parameters',
              subtitle:
                  'Every other llama-cli flag for this session. The essentials '
                  'stay in the form above and are saved with them.',
              keyPrefix: 'chat-params',
              rowKeyPrefix: 'chat-param',
              onChanged: (String id, String? value) =>
                  bloc.add(InferenceParamChanged(id, value)),
              onReset: (Set<String> ids) => bloc.add(InferenceParamsReset(ids)),
            );
          },
        ),
      ),
    );
  }
}
