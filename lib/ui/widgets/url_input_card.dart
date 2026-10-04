import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/downloader_provider.dart';

/// URL input row with fetch action and live provider detection status.
class UrlInputCard extends StatelessWidget {
  const UrlInputCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fetching,
    required this.onFetch,
    required this.provider,
    required this.errorMessage,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool fetching;
  final VoidCallback onFetch;
  final DownloaderProvider? provider;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paste a URL to download', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onSubmitted: (_) => onFetch(),
                    decoration: InputDecoration(
                      hintText: 'https://www.youtube.com/watch?v=...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        tooltip: 'Paste from clipboard',
                        icon: const Icon(Icons.content_paste),
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: fetching ? null : onFetch,
                  icon: fetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(fetching ? 'Fetching...' : 'Fetch Info'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (provider != null && errorMessage == null)
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Provider: ${provider!.displayName}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              )
            else if (errorMessage != null)
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    controller.text = text.trim();
    controller.selection = TextSelection.collapsed(offset: text.trim().length);
  }
}
