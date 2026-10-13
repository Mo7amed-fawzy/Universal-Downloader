import 'package:flutter/material.dart';

class DownloadsEmptyState extends StatelessWidget {
  const DownloadsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Image.asset(
                'assets/branding/catchit-icon.png',
                width: 88,
                height: 88,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No downloads yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a URL on the Home page to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
