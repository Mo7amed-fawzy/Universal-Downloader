import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/downloader_exceptions.dart';
import '../core/models/download_options.dart';
import '../core/models/media_info.dart';
import '../core/services/log_service.dart';
import '../providers/downloader_provider.dart';
import '../providers/provider_registry.dart';
import 'download_queue.dart';
import 'download_repository.dart';
import 'download_task.dart';
import 'download_task_state.dart';

/// Orchestrates the download queue: accepts tasks, runs them through their
/// provider pipelines with a concurrency limit, and notifies the UI.
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required this.registry,
    required this.repository,
    required this.log,
    DownloadQueue? queue,
  }) : queue = queue ?? DownloadQueue();

  final ProviderRegistry registry;
  final DownloadRepository repository;
  final LogService log;
  final DownloadQueue queue;

  /// Task ids currently executing.
  final Set<String> _runningIds = {};

  List<DownloadTask> get tasks => queue.tasks;

  int get activeCount => _runningIds.length;

  /// Queues a new download.
  void add({
    required DownloaderProvider provider,
    required MediaInfo media,
    required DownloadOptions options,
    required String videoLabel,
    required String audioLabel,
  }) {
    final task = DownloadTask(
      id: options.taskId,
      media: media,
      options: options,
      providerId: provider.id,
      providerName: provider.displayName,
      videoLabel: videoLabel,
      audioLabel: audioLabel,
    );
    queue.add(task);
    log.info(
      'Queued task ${task.id}: ${media.title} ($videoLabel / $audioLabel)',
    );
    _pump();
  }

  /// Requests cancellation of a task (terminates yt-dlp / ffmpeg).
  void cancel(String taskId) {
    final task = queue.byId(taskId);
    if (task == null) return;
    if (task.state.isActive) {
      log.info('Cancelling task $taskId');
      task.cancelToken.cancel();
    }
  }

  /// Retries a failed task, reusing any preserved temporary files.
  Future<void> retry(String taskId) async {
    final task = queue.byId(taskId);
    if (task == null || task.state != DownloadTaskState.failed) return;

    final provider = registry.byId(task.providerId);
    if (provider == null) {
      task.markFailed(ProviderNotSupportedException(
        'The provider for this task is no longer available.',
      ));
      notifyListeners();
      return;
    }

    log.info('Retrying task $taskId');
    task.resetForRetry();
    _pump();
  }

  /// Removes a task from the queue.
  void remove(String taskId) {
    queue.remove(taskId);
    _runningIds.remove(taskId);
    notifyListeners();
  }

  /// Starts queued tasks while execution slots are free.
  void _pump() {
    notifyListeners();
    final pending = queue.pending.where((task) => !_runningIds.contains(task.id));
    if (pending.isEmpty) return;

    final slots = queue.maxConcurrent - _runningIds.length;
    if (slots <= 0) return;

    for (final task in pending.take(slots)) {
      final provider = registry.byId(task.providerId);
      if (provider == null) {
        task.markFailed(ProviderNotSupportedException(
          'The provider for this task is no longer available.',
        ));
        continue;
      }
      _runningIds.add(task.id);
      unawaited(_execute(task, provider));
    }
    notifyListeners();
  }

  Future<void> _execute(DownloadTask task, DownloaderProvider provider) async {
    task.markStarted();
    notifyListeners();
    try {
      final result = await provider.download(
        task.media,
        task.options,
        onPhase: task.setPhase,
        onProgress: task.setProgress,
        cancelToken: task.cancelToken,
      );
      task.markCompleted(result.outputFile.path);
    } on DownloadCancelledException {
      task.markCancelled();
      repository.cleanupTaskDirectory(task.id);
    } on DownloaderException catch (e) {
      task.markFailed(e);
      log.error('Task ${task.id} failed: ${e.message}');
    } catch (e, st) {
      task.markFailed(
        UnexpectedException('An unexpected error occurred.'),
        technicalDetails: '$e\n$st',
      );
      log.error('Task ${task.id} crashed: $e');
    }
    _runningIds.remove(task.id);
    _pump();
  }
}
