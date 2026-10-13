import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../downloads/download_task.dart';
import '../../downloads/download_task_state.dart';
import 'download_cancel_button.dart';
import 'download_location_button.dart';
import 'download_remove_button.dart';
import 'download_resume_button.dart';
import 'error_dialog.dart';

class DownloadTaskActions extends StatelessWidget {
  const DownloadTaskActions({
    super.key,
    required this.task,
    required this.fileMissing,
    required this.openDownload,
  });

  final DownloadTask task;
  final bool fileMissing;
  final Future<void> Function(String) openDownload;

  @override
  Widget build(BuildContext context) {
    final state = task.state;
    if (state.isActive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Pause',
            icon: const Icon(Icons.pause_rounded),
            onPressed: state == DownloadTaskState.pausing
                ? null
                : () => context.read<AppController>().manager.pause(task.id),
          ),
          DownloadCancelButton(task: task),
        ],
      );
    }

    final buttons = <Widget>[];
    switch (state) {
      case DownloadTaskState.paused:
      case DownloadTaskState.interrupted:
        buttons.add(
          DownloadResumeButton(
            onResume: () =>
                context.read<AppController>().manager.retry(task.id),
          ),
        );
        buttons.add(DownloadCancelButton(task: task));
      case DownloadTaskState.completed:
        if (!fileMissing) {
          buttons.add(
            DownloadLocationButton(
              outputPath: task.outputPath,
              openDownload: openDownload,
            ),
          );
        }
        buttons.add(
          DownloadRemoveButton(
            onRemove: () =>
                context.read<AppController>().manager.remove(task.id),
          ),
        );
      case DownloadTaskState.failed:
        buttons.add(
          IconButton(
            tooltip: 'View details',
            icon: const Icon(Icons.article_outlined),
            onPressed: () => showErrorDialog(
              context,
              message: task.error?.message ?? 'Failed',
              details: task.technicalDetails,
            ),
          ),
        );
        buttons.add(
          IconButton(
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AppController>().manager.retry(task.id),
          ),
        );
        buttons.add(
          DownloadRemoveButton(
            onRemove: () =>
                context.read<AppController>().manager.remove(task.id),
          ),
        );
      case DownloadTaskState.cancelled:
        buttons.add(
          DownloadRemoveButton(
            onRemove: () =>
                context.read<AppController>().manager.remove(task.id),
          ),
        );
      default:
        break;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}
