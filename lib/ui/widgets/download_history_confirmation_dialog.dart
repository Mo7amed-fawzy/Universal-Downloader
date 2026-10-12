import 'package:flutter/material.dart';

class DownloadHistoryConfirmationDialog extends StatelessWidget {
  const DownloadHistoryConfirmationDialog({super.key, this.clearAll = false});

  final bool clearAll;

  static Future<bool> confirm(
    BuildContext context, {
    bool clearAll = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) =>
              DownloadHistoryConfirmationDialog(clearAll: clearAll),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        clearAll ? 'Clear download history?' : 'Remove from history?',
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clearAll
                ? 'Are you sure you want to clear all finished download history from the app?'
                : 'Are you sure you want to remove this video’s download history from the app?',
          ),
          const SizedBox(height: 12),
          const Text('Downloaded files will stay on your device.'),
        ],
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(clearAll ? 'Clear history' : 'Remove'),
        ),
      ],
    );
  }
}
