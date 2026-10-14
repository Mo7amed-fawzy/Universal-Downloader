import 'package:flutter/material.dart';

class HomeRemoveConfirmationDialog extends StatelessWidget {
  const HomeRemoveConfirmationDialog({
    super.key,
    required this.title,
    this.isPlaylist = false,
    this.downloadedCount,
  });

  final String title;
  final bool isPlaylist;
  final int? downloadedCount;

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    bool isPlaylist = false,
    int? downloadedCount,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => HomeRemoveConfirmationDialog(
          title: title,
          isPlaylist: isPlaylist,
          downloadedCount: downloadedCount,
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        downloadedCount != null
            ? 'Remove downloaded videos?'
            : isPlaylist
            ? 'Remove playlist?'
            : 'Remove video?',
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 12),
          Text(
            downloadedCount != null
                ? 'Remove $downloadedCount previously downloaded ${downloadedCount == 1 ? 'video' : 'videos'} from this playlist? Their settings will be lost. Downloaded files and history will stay on your device.'
                : isPlaylist
                ? 'Remove this playlist and all its remaining videos from the list? '
                      'Their settings will be lost.'
                : 'Remove this video from the list? Its settings will be lost.',
          ),
        ],
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove'),
        ),
      ],
    );
  }
}
