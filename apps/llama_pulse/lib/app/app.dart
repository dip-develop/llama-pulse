import 'package:flutter/material.dart';

import '../presentation/inference/inference_screen.dart';
import 'theme/app_theme.dart';

/// Root widget: window shell, themes and the current top-level screen.
class LlamaPulseApp extends StatelessWidget {
  const LlamaPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LlamaPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const InferenceScreen(),
    );
  }
}
