import 'package:flutter/material.dart';

class HomeRemoveConfirmationDialog extends StatelessWidget {
  const HomeRemoveConfirmationDialog({
    super.key,
    required this.title,
    this.isPlaylist = false,
  });

  final String title;
  final bool isPlaylist;

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    bool isPlaylist = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) =>
            HomeRemoveConfirmationDialog(title: title, isPlaylist: isPlaylist),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(isPlaylist ? 'Remove playlist?' : 'Remove video?'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 12),
          Text(
            isPlaylist
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
