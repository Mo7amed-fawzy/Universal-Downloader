import 'package:flutter/foundation.dart';

import '../core/errors/downloader_exceptions.dart';
import '../core/models/download_options.dart';
import '../core/models/media_info.dart';
import '../core/process/cancel_token.dart';
import 'download_progress.dart';
import 'download_task_state.dart';

/// A single download in the queue. Mutable state is guarded by
/// [ChangeNotifier] so the UI can rebuild on progress.
class DownloadTask extends ChangeNotifier {
  DownloadTask({
    required this.id,
    required this.media,
    required this.options,
    required this.providerId,
    required this.providerName,
    required this.videoLabel,
    required this.audioLabel,
  });

  DownloadTask.completed({
    required this.id,
    required this.media,
    required this.options,
    required this.providerId,
    required this.providerName,
    required this.videoLabel,
    required this.audioLabel,
    required this._outputPath,
    required this._startedAt,
    required this._completedAt,
  }) : _state = DownloadTaskState.completed;

  final String id;
  final MediaInfo media;
  final DownloadOptions options;
  final String providerId;
  final String providerName;

  /// Human label of the selected video stream, e.g. `1080p 60fps`.
  final String videoLabel;

  /// Human label of the selected audio stream, e.g. `Arabic · 155 kbps`.
  final String audioLabel;

  DownloadTaskState _state = DownloadTaskState.queued;
  DownloadProgress _progress = const DownloadProgress();
  double? _displayPercent;
  DownloaderException? _error;
  String? _technicalDetails;
  String? _outputPath;
  CancelToken _cancelToken = CancelToken();
  DateTime? _startedAt;
  DateTime? _completedAt;
  int retryAttempt = 0;
  DateTime? retryAt;

  DownloadTaskState get state => _state;
  DownloadProgress get progress => _progress;
  double? get displayPercent => _displayPercent;
  DownloaderException? get error => _error;
  String? get technicalDetails => _technicalDetails;
  String? get outputPath => _outputPath;
  CancelToken get cancelToken => _cancelToken;
  DateTime? get startedAt => _startedAt;
  DateTime? get completedAt => _completedAt;

  /// Convenience: whether the error should show a "view details" affordance.
  bool get hasTechnicalDetails =>
      _technicalDetails != null && _technicalDetails!.trim().isNotEmpty;

  void setPhase(DownloadTaskState state) {
    if (_state == state) return;
    _state = state;
    _progress = const DownloadProgress();
    _displayPercent = null;
    notifyListeners();
  }

  void setProgress(DownloadProgress progress) {
    final percent = progress.percent;
    if (percent != null && percent.isFinite) {
      final bounded = percent.clamp(0.0, 100.0);
      if (_displayPercent == null || bounded > _displayPercent!) {
        _displayPercent = bounded;
      }
    }
    final statusOnly =
        progress.percent == null &&
        progress.downloadedBytes == null &&
        progress.totalBytes == null &&
        progress.speedBytesPerSecond == null &&
        progress.eta == null;
    _progress = statusOnly
        ? _progress.copyWith(statusLabel: progress.statusLabel)
        : progress;
    notifyListeners();
  }

  void markStarted() {
    _startedAt ??= DateTime.now();
    notifyListeners();
  }

  void markCompleted(String outputPath) {
    _outputPath = outputPath;
    _state = DownloadTaskState.completed;
    _completedAt = DateTime.now();
    notifyListeners();
  }

  void markFailed(DownloaderException error, {String? technicalDetails}) {
    _error = error;
    _technicalDetails = technicalDetails ?? error.details ?? (error.message);
    _state = DownloadTaskState.failed;
    _completedAt = DateTime.now();
    notifyListeners();
  }

  void markCancelled() {
    _state = DownloadTaskState.cancelled;
    _completedAt = DateTime.now();
    notifyListeners();
  }

  void markInterrupted() {
    _state = DownloadTaskState.interrupted;
    notifyListeners();
  }

  void markPausing() {
    _state = DownloadTaskState.pausing;
    retryAt = null;
    notifyListeners();
  }

  void markPaused() {
    _state = DownloadTaskState.paused;
    retryAt = null;
    notifyListeners();
  }

  void waitForRetry(Duration delay) {
    retryAttempt++;
    retryAt = DateTime.now().add(delay);
    setPhase(DownloadTaskState.waitingForRetry);
    setProgress(
      DownloadProgress(
        statusLabel:
            'Network interrupted. Retry $retryAttempt in ${delay.inSeconds}s.',
      ),
    );
  }

  /// Resets a failed task so it can be retried with a fresh cancel token.
  void resetForRetry() {
    _state = DownloadTaskState.queued;
    _progress = const DownloadProgress();
    _displayPercent = null;
    _error = null;
    _technicalDetails = null;
    _completedAt = null;
    retryAt = null;
    _cancelToken = CancelToken();
    notifyListeners();
  }
}
