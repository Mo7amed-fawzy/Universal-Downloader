import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../core/utils/format_utils.dart';
import '../../downloads/download_task.dart';
import '../../downloads/download_task_state.dart';
import '../components/status_chip.dart';
import 'error_dialog.dart';

/// A single entry in the download queue.
class DownloadTile extends StatelessWidget {
  const DownloadTile({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: task,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(task: task),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusChip(
                        label: task.providerName,
                        icon: Icons.language,
                        color: theme.colorScheme.primary,
                      ),
                      StatusChip(
                        label: task.videoLabel,
                        icon: Icons.high_quality_outlined,
                        color: theme.colorScheme.secondary,
                      ),
                      if (task.audioLabel.isNotEmpty)
                        StatusChip(
                          label: task.audioLabel,
                          icon: Icons.music_note_outlined,
                          color: theme.colorScheme.tertiary,
                        ),
                      if (task.options.subtitle != null)
                        StatusChip(
                          label: task.options.subtitle!.label,
                          icon: Icons.subtitles_outlined,
                          color: theme.colorScheme.secondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StateArea(task: task),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Actions(task: task),
          ],
        ),
      ),
    );
  }
}

class _StateArea extends StatelessWidget {
  const _StateArea({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final state = task.state;

    switch (state) {
      case DownloadTaskState.queued:
      case DownloadTaskState.fetchingInfo:
      case DownloadTaskState.selectingFormat:
      case DownloadTaskState.waitingForSubtitles:
        return _infoRow(context, '${state.label}...');
      case DownloadTaskState.downloadingVideo:
      case DownloadTaskState.downloadingAudio:
      case DownloadTaskState.downloadingSubtitles:
      case DownloadTaskState.merging:
      case DownloadTaskState.verifying:
        return _activeRow(context);
      case DownloadTaskState.completed:
        return _completedRow(context);
      case DownloadTaskState.failed:
        return _failedRow(context);
      case DownloadTaskState.cancelled:
        return _infoRow(context, 'Cancelled');
    }
  }

  Widget _activeRow(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.progress;
    final percent = progress.percent;

    final stats = [
      if (progress.downloadedBytes != null)
        FormatUtils.bytes(progress.downloadedBytes),
      if (progress.totalBytes != null) 'of ${FormatUtils.bytes(progress.totalBytes)}',
      if (percent != null) '${percent.toStringAsFixed(0)}%',
      if (progress.speedBytesPerSecond != null)
        FormatUtils.bytesPerSecond(progress.speedBytesPerSecond),
      if (progress.eta != null) 'ETA ${FormatUtils.duration(progress.eta)}',
    ].join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              task.state.label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            if (task.state == DownloadTaskState.merging ||
                task.state == DownloadTaskState.verifying)
              Text(
                'Merging video and audio...',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent == null ? null : percent / 100,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stats.isEmpty ? 'Starting...' : stats,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _completedRow(BuildContext context) {
    final theme = Theme.of(context);
    final output = task.outputPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Completed',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (output != null) ...[
          const SizedBox(height: 6),
          Text(
            output,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _failedRow(BuildContext context) {
    final theme = Theme.of(context);
    final error = task.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error?.message ?? 'Failed',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
        if (task.hasTechnicalDetails) ...[
          const SizedBox(height: 6),
          Text(
            'Temporary files were preserved for retry.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _infoRow(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(text, style: theme.textTheme.bodyMedium);
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final state = task.state;
    if (state.isActive) {
      return IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close),
        onPressed: () => context.read<AppController>().manager.cancel(task.id),
      );
    }

    final buttons = <Widget>[];
    switch (state) {
      case DownloadTaskState.completed:
        buttons.add(IconButton(
          tooltip: 'Open location',
          icon: const Icon(Icons.folder_open),
          onPressed: () => _openLocation(context),
        ));
        buttons.add(IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              context.read<AppController>().manager.remove(task.id),
        ));
      case DownloadTaskState.failed:
        buttons.add(IconButton(
          tooltip: 'View details',
          icon: const Icon(Icons.article_outlined),
          onPressed: () => showErrorDialog(
            context,
            message: task.error?.message ?? 'Failed',
            details: task.technicalDetails,
          ),
        ));
        buttons.add(IconButton(
          tooltip: 'Retry',
          icon: const Icon(Icons.refresh),
          onPressed: () =>
              context.read<AppController>().manager.retry(task.id),
        ));
        buttons.add(IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              context.read<AppController>().manager.remove(task.id),
        ));
      case DownloadTaskState.cancelled:
        buttons.add(IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              context.read<AppController>().manager.remove(task.id),
        ));
      default:
        break;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  Future<void> _openLocation(BuildContext context) async {
    final output = task.outputPath;
    if (output == null) return;
    final file = File(output);
    final dir = file.parent.path;
    try {
      unawaited(Process.run('xdg-open', [dir], runInShell: false));
    } catch (_) {
      // Ignore: file managers may be unavailable.
    }
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final uri = task.media.thumbnail;
    final scheme = Theme.of(context).colorScheme;
    if (uri == null) {
      return Container(
        width: 120,
        height: 68,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 120,
        height: 68,
        child: Image.network(
          uri.toString(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
