import 'package:flutter/material.dart';

import 'download_history_confirmation_dialog.dart';

class DownloadRemoveButton extends StatelessWidget {
  const DownloadRemoveButton({super.key, required this.onRemove});

  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Remove',
      icon: const Icon(Icons.delete_outline),
      onPressed: () async {
        final confirmed = await DownloadHistoryConfirmationDialog.confirm(
          context,
        );
        if (!context.mounted || !confirmed) return;
        await onRemove();
      },
    );
  }
}
