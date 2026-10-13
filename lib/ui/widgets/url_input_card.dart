import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/downloader_provider.dart';
import 'downloaded_video_warning.dart';

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
    this.enabled = true,
    this.multiDownloadMode = false,
    this.statusMessage,
    this.previousDownloadCount = 0,
    this.onViewDownloads,
    this.onAddPlaylist,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool fetching;
  final VoidCallback onFetch;
  final DownloaderProvider? provider;
  final String? errorMessage;
  final bool enabled;
  final bool multiDownloadMode;
  final String? statusMessage;
  final int previousDownloadCount;
  final VoidCallback? onViewDownloads;
  final VoidCallback? onAddPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              multiDownloadMode ? 'Add videos' : 'Paste a URL to download',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final field = TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled && !fetching,
                  minLines: 1,
                  maxLines: multiDownloadMode ? 3 : 1,
                  keyboardType: multiDownloadMode
                      ? TextInputType.multiline
                      : TextInputType.url,
                  onSubmitted: multiDownloadMode
                      ? null
                      : (_) {
                          if (enabled && !fetching) onFetch();
                        },
                  decoration: InputDecoration(
                    labelText: multiDownloadMode ? 'Video links' : null,
                    hintText: multiDownloadMode
                        ? 'Paste one link per line'
                        : 'https://www.youtube.com/watch?v=...',
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, child) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear URL',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                controller.clear();
                                focusNode.requestFocus();
                              },
                            ),
                          child!,
                        ],
                      ),
                      child: IconButton(
                        tooltip: 'Paste from clipboard',
                        icon: const Icon(Icons.content_paste),
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ),
                );
                final button = FilledButton.icon(
                  onPressed: fetching || !enabled ? null : onFetch,
                  icon: fetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(multiDownloadMode ? Icons.add : Icons.search),
                  label: Text(
                    fetching
                        ? 'Fetching...'
                        : multiDownloadMode
                        ? 'Add videos'
                        : 'Fetch Info',
                  ),
                );
                return constraints.maxWidth < 500
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [field, const SizedBox(height: 12), button],
                      )
                    : Row(
                        children: [
                          Expanded(child: field),
                          const SizedBox(width: 12),
                          button,
                        ],
                      );
              },
            ),
            const SizedBox(height: 12),
            if (multiDownloadMode && onAddPlaylist != null) ...[
              OutlinedButton.icon(
                onPressed: enabled ? onAddPlaylist : null,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add playlist'),
              ),
              const SizedBox(height: 12),
            ],
            if (statusMessage != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(statusMessage!, style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: 8),
            ],
            if (provider != null && errorMessage == null)
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Provider: ${provider!.displayName}',
                      style: theme.textTheme.bodyMedium,
                    ),
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            if (previousDownloadCount > 0) ...[
              const SizedBox(height: 4),
              DownloadedVideoWarning(
                videoCount: previousDownloadCount,
                onViewDownloads: onViewDownloads,
              ),
            ],
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
