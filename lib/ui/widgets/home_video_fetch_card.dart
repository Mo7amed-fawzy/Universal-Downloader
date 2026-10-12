import 'package:flutter/material.dart';

import '../pages/home_video_entry.dart';

class HomeVideoFetchCard extends StatelessWidget {
  const HomeVideoFetchCard({
    super.key,
    required this.entry,
    required this.onRemove,
    required this.onRetry,
  });

  final HomeVideoEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.link,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${entry.link}',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: entry.fetching
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          entry.errorMessage == null
                              ? Icons.schedule
                              : Icons.error_outline,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                entry.errorMessage ??
                    (entry.fetching
                        ? 'Fetching video info…'
                        : 'Waiting to fetch…'),
                style: TextStyle(
                  color: entry.errorMessage == null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.error,
                ),
              ),
            ),
            if (entry.errorMessage != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
