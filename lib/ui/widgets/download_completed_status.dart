import 'package:flutter/material.dart';

import '../../downloads/download_task.dart';
import '../components/status_chip.dart';
import '../download_date_formatter.dart';

class DownloadCompletedStatus extends StatelessWidget {
  const DownloadCompletedStatus({
    super.key,
    required this.task,
    this.fileMissing = false,
  });

  final DownloadTask task;
  final bool fileMissing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedAt = task.completedAt?.toLocal();
    final output = task.outputPath;
    final localizations = MaterialLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, size: 18, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Completed',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (fileMissing) ...[
          const SizedBox(height: 6),
          Tooltip(
            message: 'The file was moved or deleted from its saved location.',
            child: StatusChip(
              label: 'File not found',
              icon: Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (completedAt != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message:
                      'Downloaded on ${localizations.formatFullDate(completedAt)}'
                      ' • ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(completedAt), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
                  child: Text(
                    DownloadDateFormatter.format(
                      completedAt,
                      now: DateTime.now(),
                      localizations: localizations,
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
}
