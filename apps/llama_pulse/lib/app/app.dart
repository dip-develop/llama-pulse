import 'package:flutter/material.dart';

import '../presentation/home/home_shell.dart';
import 'platform/clipboard_service.dart';
import 'platform/model_path_picker.dart';
import 'platform/server_binary_picker.dart';
import 'theme/app_theme.dart';

/// Root widget: application themes and the window shell.
///
/// The shell owns the single [Scaffold] and creates the blocs, so switching
/// between the server dashboard and the embedded chat never drops their state.
class LlamaPulseApp extends StatelessWidget {
  const LlamaPulseApp({
    super.key,
    this.picker = const FileSelectorModelPathPicker(),
    this.binaryPicker = const FileSelectorServerBinaryPicker(),
    this.clipboard = const SystemClipboardService(),
    this.demoServer = false,
    this.demoEngine = false,
  });

  /// File dialog used by the model path fields.
  final ModelPathPicker picker;

  /// File dialog used by the server binary field.
  final ServerBinaryPicker binaryPicker;

  /// Clipboard seam used by the endpoint copy button.
  final ClipboardService clipboard;

  /// Whether the synthetic stub controller backs this run.
  final bool demoServer;

  /// Whether the synthetic stub engine backs this run.
  final bool demoEngine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LlamaPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeShell(
        picker: picker,
        binaryPicker: binaryPicker,
        clipboard: clipboard,
        demoServer: demoServer,
        demoEngine: demoEngine,
      ),
    );
  }
}
