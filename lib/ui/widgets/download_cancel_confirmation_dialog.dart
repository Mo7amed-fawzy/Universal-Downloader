import 'package:flutter/material.dart';

class DownloadCancelConfirmationDialog extends StatelessWidget {
  const DownloadCancelConfirmationDialog({super.key});

  static Future<bool> confirm(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => const DownloadCancelConfirmationDialog(),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Cancel download?'),
      scrollable: true,
      content: const Text(
        'Are you sure you want to cancel this download? '
        'Downloaded progress will be discarded. '
        'Use Pause to keep it and resume later.',
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep download'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cancel download'),
        ),
      ],
    );
  }
}
