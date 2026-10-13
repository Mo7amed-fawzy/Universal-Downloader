import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../downloads/download_task.dart';
import 'download_cancel_confirmation_dialog.dart';

class DownloadCancelButton extends StatelessWidget {
  const DownloadCancelButton({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Cancel',
    icon: const Icon(Icons.close),
    onPressed: () async {
      final manager = context.read<AppController>().manager;
      final confirmed = await DownloadCancelConfirmationDialog.confirm(context);
      if (context.mounted && confirmed) manager.cancel(task.id);
    },
  );
}
