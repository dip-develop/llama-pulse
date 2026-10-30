import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/inference/bloc/inference_bloc.dart';
import '../presentation/inference/bloc/inference_event.dart';
import '../presentation/inference/inference_screen.dart';
import 'di/injection.dart';
import 'platform/model_path_picker.dart';
import 'theme/app_theme.dart';

/// Root widget: window shell, themes and the current top-level screen.
class LlamaPulseApp extends StatelessWidget {
  const LlamaPulseApp({
    super.key,
    this.picker = const FileSelectorModelPathPicker(),
    this.demoEngine = false,
  });

  /// File dialog used by the model path field.
  final ModelPathPicker picker;

  /// Whether the synthetic stub engine backs this run; shows a demo banner.
  final bool demoEngine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LlamaPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: BlocProvider<InferenceBloc>(
        create: (_) => getIt<InferenceBloc>()..add(const InferenceStarted()),
        child: InferenceScreen(picker: picker, demoEngine: demoEngine),
      ),
    );
  }
}
