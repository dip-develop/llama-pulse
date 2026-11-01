import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import '../runtime/runtime_backend.dart';
import 'runtime_install_ref.dart';

part 'runtime_index.g.dart';

/// The contents of `runtime/index.yaml`: every installed runtime and which one
/// is selected by default.
abstract class RuntimeIndex
    implements Built<RuntimeIndex, RuntimeIndexBuilder> {
  /// Version of the `index.yaml` schema.
  static const int schemaVersion = 1;

  /// The tag of the selected runtime, or an empty string when none is selected.
  String get selectedTag;

  /// The selected backend, or null when no runtime is selected.
  RuntimeBackend? get selectedBackend;

  /// Every committed runtime, one entry per tag and backend.
  BuiltList<RuntimeInstallRef> get installed;

  /// Whether a runtime is selected.
  bool get hasSelection => selectedBackend != null;

  /// Every install in the order a loader must try them.
  ///
  /// The selected install comes first, then the remaining installs newest
  /// first, so a fresh install outranks an older one when nothing is selected.
  List<RuntimeInstallRef> get resolutionOrder {
    final selectedInstall = selected;
    final rest = <RuntimeInstallRef>[
      for (final install in installed)
        if (selectedInstall == null ||
            install.tag != selectedInstall.tag ||
            install.backend != selectedInstall.backend)
          install,
    ]..sort((a, b) => b.installedAtEpochMs.compareTo(a.installedAtEpochMs));
    return <RuntimeInstallRef>[?selectedInstall, ...rest];
  }

  /// Returns the selected install record, or null when nothing is selected or
  /// the selection is stale.
  RuntimeInstallRef? get selected {
    final backend = selectedBackend;
    if (backend == null) {
      return null;
    }
    for (final install in installed) {
      if (install.tag == selectedTag && install.backend == backend) {
        return install;
      }
    }
    return null;
  }

  factory RuntimeIndex([void Function(RuntimeIndexBuilder)? updates]) =
      _$RuntimeIndex;

  /// Returns the empty index used when no usable `index.yaml` exists.
  factory RuntimeIndex.empty() => RuntimeIndex(
    (b) => b
      ..selectedTag = ''
      ..selectedBackend = null
      ..installed = BuiltList<RuntimeInstallRef>().toBuilder(),
  );

  RuntimeIndex._();

  static Serializer<RuntimeIndex> get serializer => _$runtimeIndexSerializer;
}
