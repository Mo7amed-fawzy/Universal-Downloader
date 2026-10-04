import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

/// Warns when external dependencies (yt-dlp / ffmpeg / ffprobe) are missing.
class DependencyBanner extends StatelessWidget {
  const DependencyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final missing = controller.dependencies
        .where((d) => !d.installed)
        .toList();

    if (missing.isEmpty) return const SizedBox.shrink();

    final names = missing.map((d) => d.name).join(', ');

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Required tools missing: $names. Downloads will not work. '
                'Open Settings to see install instructions.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/settings');
              },
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
