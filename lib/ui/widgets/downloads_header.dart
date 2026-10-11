import 'package:flutter/material.dart';

class DownloadsHeader extends StatelessWidget {
  const DownloadsHeader({
    super.key,
    required this.activeCount,
    required this.canClear,
    required this.onClear,
    this.historyError,
  });

  final int activeCount;
  final bool canClear;
  final VoidCallback onClear;
  final String? historyError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Downloads', style: Theme.of(context).textTheme.headlineSmall),
            Text('$activeCount active'),
            if (canClear)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Clear finished'),
              ),
          ],
        ),
        if (historyError != null)
          Text(
            historyError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
