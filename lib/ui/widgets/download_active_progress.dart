import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../downloads/download_task.dart';
import '../../downloads/download_task_state.dart';

class DownloadActiveProgress extends StatelessWidget {
  const DownloadActiveProgress({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.progress;
    final percent = task.displayPercent;
    final paused = task.state == DownloadTaskState.paused;
    final stopping = paused || task.state == DownloadTaskState.pausing;
    final processing =
        task.state == DownloadTaskState.merging ||
        task.state == DownloadTaskState.verifying;
    final stats = [
      if (progress.downloadedBytes != null)
        FormatUtils.bytes(progress.downloadedBytes),
      if (progress.totalBytes != null)
        'of ${FormatUtils.bytes(progress.totalBytes)}',
      if (percent != null) '${percent.toStringAsFixed(0)}%',
      if (!stopping && progress.speedBytesPerSecond != null)
        FormatUtils.bytesPerSecond(progress.speedBytesPerSecond),
      if (!stopping && progress.eta != null)
        'ETA ${FormatUtils.duration(progress.eta)}',
    ].join(' ');
    final details = processing
        ? task.state == DownloadTaskState.merging
              ? 'Merging video and audio...'
              : 'Checking downloaded file...'
        : paused
        ? stats.isEmpty
              ? 'Resume to continue.'
              : '$stats · Resume to continue.'
        : stopping
        ? stats
        : stats.isEmpty
        ? 'Starting...'
        : stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.state.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: processing ? null : (percent ?? 0) / 100,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: details,
          child: Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
