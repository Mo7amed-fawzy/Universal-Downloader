import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'app_brand.dart';
import 'catchit_launch_animation.dart';

class StartupStatusApp extends StatelessWidget {
  const StartupStatusApp({
    super.key,
    required this.themeMode,
    required this.startAnimation,
    required this.animationFinished,
    required this.attempt,
    required this.onAnimationCompleted,
    this.error,
    this.onRetry,
  });

  final ThemeMode themeMode;
  final bool startAnimation;
  final bool animationFinished;
  final int attempt;
  final VoidCallback onAnimationCompleted;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CatchIt',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: themeMode,
    home: Scaffold(
      body: SafeArea(
        child: error != null
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppBrand(),
                        const SizedBox(height: 24),
                        const Text(
                          'Could not prepare download tools. Check the installation and try again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(error.toString()),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (startAnimation)
                    CatchItLaunchAnimation(
                      key: ValueKey(attempt),
                      onCompleted: onAnimationCompleted,
                    ),
                  if (animationFinished)
                    const Positioned(
                      left: 24,
                      right: 24,
                      bottom: 32,
                      child: Text(
                        'Preparing included download tools…',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
      ),
    ),
  );
}
