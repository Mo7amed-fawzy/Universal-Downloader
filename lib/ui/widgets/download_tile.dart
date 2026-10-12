import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../core/services/download_file_service.dart';
import '../../downloads/download_task.dart';
import '../../downloads/download_task_state.dart';
import '../components/status_chip.dart';
import 'download_active_progress.dart';
import 'download_completed_status.dart';
import 'download_location_button.dart';
import 'download_remove_button.dart';
import 'error_dialog.dart';

/// A single entry in the download queue.
class DownloadTile extends StatefulWidget {
  const DownloadTile({
    super.key,
    required this.task,
    this.fileService = const DownloadFileService(),
  });

  final DownloadTask task;
  final DownloadFileService fileService;

  @override
  State<DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends State<DownloadTile>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _fileMissing = false;
  String? _observedLocation;
  bool _wasCompleted = false;
  int _checkVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.task.addListener(_onTaskChanged);
    _onTaskChanged();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != AppLifecycleState.paused &&
          lifecycle != AppLifecycleState.hidden) {
        unawaited(_refreshAvailability());
      }
    });
  }

  @override
  void didUpdateWidget(covariant DownloadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task ||
        oldWidget.fileService != widget.fileService) {
      oldWidget.task.removeListener(_onTaskChanged);
      widget.task.addListener(_onTaskChanged);
      _wasCompleted = false;
      _observedLocation = null;
      _checkVersion++;
      _fileMissing = false;
      _onTaskChanged();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAvailability());
    }
  }

  void _onTaskChanged() {
    final completed = widget.task.state == DownloadTaskState.completed;
    final location = widget.task.outputPath;
    if (completed == _wasCompleted && location == _observedLocation) return;
    _wasCompleted = completed;
    _observedLocation = location;
    _checkVersion++;
    setState(() => _fileMissing = false);
    unawaited(_refreshAvailability());
  }

  Future<void> _refreshAvailability() async {
    if (widget.task.state != DownloadTaskState.completed) return;
    final version = ++_checkVersion;
    final exists = await widget.fileService.exists(widget.task.outputPath);
    if (!mounted || version != _checkVersion) return;
    setState(() => _fileMissing = exists == false);
  }

  Future<void> _openDownload(String location) async {
    final task = widget.task;
    final exists = await widget.fileService.exists(location);
    if (!mounted || widget.task != task || task.outputPath != location) return;
    setState(() => _fileMissing = exists == false);
    if (_fileMissing) return;
    await context.read<AppController>().openDownload(location);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.task.removeListener(_onTaskChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: task,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.sizeOf(context).width >= 600) ...[
                _Thumbnail(task: task),
                const SizedBox(width: 16),
              ],
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
                    _StateArea(task: task, fileMissing: _fileMissing),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Actions(
                task: task,
                fileMissing: _fileMissing,
                openDownload: _openDownload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateArea extends StatelessWidget {
  const _StateArea({required this.task, required this.fileMissing});

  final DownloadTask task;
  final bool fileMissing;

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
      case DownloadTaskState.downloadingCover:
      case DownloadTaskState.downloadingSubtitles:
      case DownloadTaskState.merging:
      case DownloadTaskState.verifying:
        return DownloadActiveProgress(task: task);
      case DownloadTaskState.completed:
        return DownloadCompletedStatus(task: task, fileMissing: fileMissing);
      case DownloadTaskState.failed:
        return _failedRow(context);
      case DownloadTaskState.cancelled:
        return _infoRow(context, 'Cancelled');
    }
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
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
  const _Actions({
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
      return IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close),
        onPressed: () => context.read<AppController>().manager.cancel(task.id),
      );
    }

    final buttons = <Widget>[];
    switch (state) {
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
