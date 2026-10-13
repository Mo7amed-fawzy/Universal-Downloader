import 'package:flutter/material.dart';

import '../settings/settings_service.dart';
import '../ui/widgets/startup_status_app.dart';
import 'app.dart';
import 'app_controller.dart';

class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.initialize});

  final Future<AppController> Function() initialize;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  AppController? _controller;
  ThemeMode? _themeMode;
  Object? _error;
  bool _animationFinished = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initialize();
  }

  Future<void> _loadTheme() async {
    ThemeMode mode;
    try {
      mode = await SettingsService().loadThemeMode();
    } catch (_) {
      mode = ThemeMode.system;
    }
    if (mounted) setState(() => _themeMode = mode);
  }

  Future<void> _initialize() async {
    try {
      final controller = await widget.initialize();
      if (!mounted) {
        await controller.closeStorage();
        controller.manager.dispose();
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _animationFinished = false;
      _attempt++;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration:
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 350),
    child: _controller != null && _animationFinished
        ? UniversalDownloaderApp(controller: _controller!)
        : StartupStatusApp(
            themeMode: _themeMode ?? ThemeMode.system,
            startAnimation: _themeMode != null,
            animationFinished: _animationFinished,
            attempt: _attempt,
            error: _error,
            onRetry: _retry,
            onAnimationCompleted: () {
              setState(() => _animationFinished = true);
            },
          ),
  );
}
