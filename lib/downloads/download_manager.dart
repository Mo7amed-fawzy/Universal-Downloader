import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/downloader_exceptions.dart';
import '../core/models/download_options.dart';
import '../core/models/media_info.dart';
import '../core/process/cancel_token.dart';
import '../core/services/log_service.dart';
import '../providers/downloader_provider.dart';
import '../providers/provider_registry.dart';
import '../providers/youtube/youtube_cache_key.dart';
import 'download_queue.dart';
import 'download_history.dart';
import 'download_recovery_store.dart';
import 'download_retry_policy.dart';
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
    this.publishDownload,
    this.history,
    this.recovery,
    this.retryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
    ],
  }) : queue = queue ?? DownloadQueue();

  final ProviderRegistry registry;
  final DownloadRepository repository;
  final LogService log;
  final DownloadQueue queue;
  final DownloadHistory? history;
  final DownloadRecoveryStore? recovery;
  final List<Duration> retryDelays;
  final Set<String> _savingIds = {};
  final Set<String> _pauseRequestedIds = {};
  final Map<String, Timer> _retryTimers = {};
  final Set<Future<void>> _executions = {};
  bool _closing = false;
  String? historyError;
  Future<void> _historyWrites = Future.value();
  final Future<String> Function(DownloadTaskResult, CancelToken)?
  publishDownload;

  /// Task ids currently executing.
  final Set<String> _runningIds = {};

  List<DownloadTask> get tasks => queue.tasks;

  int get activeCount => _runningIds.length;

  int completedVideoCount(Iterable<Uri> urls) =>
      completedVideosForUrls(urls).length;

  List<DownloadTask> completedVideosForUrls(Iterable<Uri> urls) {
    final completed = <(String, String), DownloadTask>{};
    for (final task in tasks) {
      if (task.state != DownloadTaskState.completed) continue;
      final key = _sourceKey(task.providerId, task.media.pageUrl);
      final previous = completed[key];
      if (previous == null ||
          (task.completedAt != null &&
              (previous.completedAt == null ||
                  task.completedAt!.isAfter(previous.completedAt!)))) {
        completed[key] = task;
      }
    }
    final matches = <(String, String), DownloadTask>{};
    for (final url in urls) {
      if ((url.scheme != 'http' && url.scheme != 'https') || url.host.isEmpty) {
        continue;
      }
      final provider = registry.resolve(url);
      if (provider == null) continue;
      final key = _sourceKey(provider.id, url);
      final task = completed[key];
      if (task != null) matches[key] = task;
    }
    return matches.values.toList();
  }

  (String, String) _sourceKey(String providerId, Uri url) => (
    providerId,
    providerId == 'youtube'
        ? youtubeCacheKey(url)
        : url.removeFragment().toString(),
  );

  Future<void> restoreHistory() async {
    final restored = await history?.load() ?? const <DownloadTask>[];
    for (final task in restored) {
      if (queue.byId(task.id) == null) queue.add(task);
    }
    for (final task in await recovery?.load() ?? const <DownloadTask>[]) {
      if (queue.byId(task.id) == null) queue.add(task);
    }
    notifyListeners();
  }

  Future<void> flushHistory() async {
    Future<void> pending;
    do {
      pending = _historyWrites;
      await pending;
    } while (pending != _historyWrites);
  }

  Future<bool> _writeHistory(Future<void> Function() write) {
    final operation = _historyWrites.then((_) async {
      try {
        await write();
        return true;
      } catch (error) {
        historyError =
            'Could not save downloads. Check available storage before retrying.';
        log.error('Could not update download history: $error');
        if (!_closing) notifyListeners();
        return false;
      }
    });
    _historyWrites = operation.then((_) {});
    return operation;
  }

  /// Queues a new download.
  void add({
    required DownloaderProvider provider,
    required MediaInfo media,
    required DownloadOptions options,
    required String videoLabel,
    required String audioLabel,
  }) {
    if (_closing) return;
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
    _prepare(task);
  }

  void _prepare(DownloadTask task) {
    final store = recovery;
    if (store == null) {
      _pump();
      return;
    }
    _savingIds.add(task.id);
    unawaited(
      _writeHistory(() => store.save(task)).then((saved) {
        _savingIds.remove(task.id);
        if (_closing) return;
        if (!saved && task.state == DownloadTaskState.queued) {
          task.markFailed(
            FilesystemException(
              'Could not save this download for recovery. Free some space and retry.',
            ),
          );
        }
        _pump();
      }),
    );
    notifyListeners();
  }

  void pause(String taskId) {
    final task = queue.byId(taskId);
    if (_closing ||
        task == null ||
        !task.state.isActive ||
        task.state == DownloadTaskState.pausing ||
        task.cancelToken.isCancelled) {
      return;
    }
    log.info('Pausing task $taskId');
    _retryTimers.remove(taskId)?.cancel();
    task.cancelToken.cancel();
    if (_runningIds.contains(taskId)) {
      _pauseRequestedIds.add(taskId);
      task.markPausing();
    } else {
      task.markPaused();
    }
    notifyListeners();
  }

  /// Requests cancellation of a task (terminates yt-dlp / ffmpeg).
  void cancel(String taskId) {
    final task = queue.byId(taskId);
    if (_closing || task == null) return;
    if (task.state.isActive ||
        task.state == DownloadTaskState.paused ||
        task.state == DownloadTaskState.interrupted) {
      log.info('Cancelling task $taskId');
      _pauseRequestedIds.remove(taskId);
      task.cancelToken.cancel();
      if (!_runningIds.contains(task.id)) {
        _retryTimers.remove(task.id)?.cancel();
        task.markCancelled();
        final store = recovery;
        if (store != null) {
          unawaited(_writeHistory(() => store.remove(task.id)));
        }
        repository.cleanupTaskDirectory(task.id);
        _pump();
      }
    }
  }

  /// Retries a failed task, reusing any preserved temporary files.
  Future<void> retry(String taskId) async {
    final task = queue.byId(taskId);
    if (_closing ||
        task == null ||
        _runningIds.contains(taskId) ||
        (task.state != DownloadTaskState.failed &&
            task.state != DownloadTaskState.paused &&
            task.state != DownloadTaskState.interrupted)) {
      return;
    }

    final provider = registry.byId(task.providerId);
    if (provider == null) {
      task.markFailed(
        ProviderNotSupportedException(
          'The provider for this task is no longer available.',
        ),
      );
      notifyListeners();
      return;
    }

    log.info('Retrying task $taskId');
    task.resetForRetry();
    task.retryAttempt = 0;
    _prepare(task);
  }

  /// Removes a task from the queue.
  Future<void> remove(String taskId) async {
    final task = queue.byId(taskId);
    if (task == null || task.state.isActive || _runningIds.contains(taskId)) {
      return;
    }
    final store = history;
    if (store != null && !await _writeHistory(() => store.remove(taskId))) {
      return;
    }
    final recoveryStore = recovery;
    if (recoveryStore != null &&
        !await _writeHistory(() => recoveryStore.remove(taskId))) {
      return;
    }
    _retryTimers.remove(taskId)?.cancel();
    repository.cleanupTaskDirectory(taskId);
    queue.remove(taskId);
    _runningIds.remove(taskId);
    notifyListeners();
  }

  /// Starts queued tasks while execution slots are free.
  void _pump() {
    if (_closing) return;
    notifyListeners();
    final pending = queue.pending.where(
      (task) => !_runningIds.contains(task.id) && !_savingIds.contains(task.id),
    );
    if (pending.isEmpty) return;

    final slots = queue.maxConcurrent - _runningIds.length;
    if (slots <= 0) return;

    for (final task in pending.take(slots)) {
      final provider = registry.byId(task.providerId);
      if (provider == null) {
        task.markFailed(
          ProviderNotSupportedException(
            'The provider for this task is no longer available.',
          ),
        );
        continue;
      }
      _runningIds.add(task.id);
      final execution = _execute(task, provider);
      _executions.add(execution);
      unawaited(execution.then((_) => _executions.remove(execution)));
    }
    notifyListeners();
  }

  Future<void> _execute(DownloadTask task, DownloaderProvider provider) async {
    final cancelToken = task.cancelToken;
    task.markStarted();
    notifyListeners();
    try {
      final result = await provider.download(
        task.media,
        task.options,
        onPhase: (phase) {
          if (!cancelToken.isCancelled) task.setPhase(phase);
        },
        onProgress: (progress) {
          if (!cancelToken.isCancelled) task.setProgress(progress);
        },
        cancelToken: cancelToken,
      );
      if (_closing) return;
      cancelToken.throwIfCancelled();
      final location =
          await publishDownload?.call(result, cancelToken) ??
          result.outputFile.path;
      if (_closing) return;
      cancelToken.throwIfCancelled();
      task.markCompleted(location);
      final store = history;
      if (store != null) {
        final saved = await _writeHistory(() => store.save(task));
        if (saved) repository.cleanupTaskDirectory(task.id);
      } else {
        if (recovery != null) {
          await _writeHistory(() => recovery!.remove(task.id));
        }
        repository.cleanupTaskDirectory(task.id);
      }
    } on DownloadCancelledException {
      if (_closing) return;
      await _finishCancellation(task);
    } on DownloaderException catch (e) {
      if (_closing) return;
      if (cancelToken.isCancelled) {
        await _finishCancellation(task);
        return;
      }
      _failOrRetry(task, e);
      log.error('Task ${task.id} failed: ${e.message}');
    } catch (e, st) {
      if (_closing) return;
      if (cancelToken.isCancelled) {
        await _finishCancellation(task);
        return;
      }
      _failOrRetry(
        task,
        DownloadRetryPolicy.isRetryable(e)
            ? NetworkException(
                'The network connection was interrupted.',
                details: '$e',
              )
            : UnexpectedException(
                'An unexpected error occurred.',
                details: '$e\n$st',
              ),
      );
      log.error('Task ${task.id} crashed: $e');
    } finally {
      _pauseRequestedIds.remove(task.id);
      _runningIds.remove(task.id);
      _pump();
    }
  }

  Future<void> _finishCancellation(DownloadTask task) async {
    if (_pauseRequestedIds.remove(task.id)) {
      task.markPaused();
      return;
    }
    task.markCancelled();
    if (recovery != null) {
      await _writeHistory(() => recovery!.remove(task.id));
    }
    repository.cleanupTaskDirectory(task.id);
  }

  void _failOrRetry(DownloadTask task, DownloaderException error) {
    if (DownloadRetryPolicy.isRetryable(error) &&
        task.retryAttempt < retryDelays.length) {
      final delay = retryDelays[task.retryAttempt];
      task.waitForRetry(delay);
      _retryTimers[task.id] = Timer(delay, () {
        _retryTimers.remove(task.id);
        if (_closing || task.cancelToken.isCancelled) return;
        task.resetForRetry();
        _pump();
      });
    } else {
      task.markFailed(error);
    }
  }

  Future<void> shutdown() async {
    _closing = true;
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    for (final task in tasks.where((task) => task.state.isActive)) {
      task.cancelToken.cancel();
    }
    await Future.wait(_executions.toList());
    await flushHistory();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
