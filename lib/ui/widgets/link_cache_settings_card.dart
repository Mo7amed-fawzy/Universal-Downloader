import 'package:flutter/material.dart';

class LinkCacheSettingsCard extends StatelessWidget {
  const LinkCacheSettingsCard({
    super.key,
    required this.clearing,
    required this.onClear,
    this.message,
  });

  final bool clearing;
  final VoidCallback onClear;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Storage', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: const Text('Link cache'),
              subtitle: const Text(
                'Reuse fetched links for 5 minutes. Clearing this keeps your downloaded files and history.',
              ),
              trailing: clearing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Clear link cache',
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: onClear,
                    ),
            ),
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
          ],
        ),
      ),
    );
  }
}
