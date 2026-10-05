import 'package:flutter/material.dart';

class StartupStatusApp extends StatelessWidget {
  const StartupStatusApp({super.key, this.error, this.onRetry});
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Preparing included download tools…'),
                ] else ...[
                  const Text(
                    'Could not prepare download tools. Reinstall the complete APK if this continues.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(error.toString()),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
