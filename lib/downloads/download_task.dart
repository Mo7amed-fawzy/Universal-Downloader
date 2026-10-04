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
  DownloaderException? _error;
  String? _technicalDetails;
  String? _outputPath;
  CancelToken _cancelToken = CancelToken();
  DateTime? _startedAt;
  DateTime? _completedAt;

  DownloadTaskState get state => _state;
  DownloadProgress get progress => _progress;
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
    _state = state;
    notifyListeners();
  }

  void setProgress(DownloadProgress progress) {
    _progress = progress;
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
    _technicalDetails =
        technicalDetails ?? error.details ?? (error.message);
    _state = DownloadTaskState.failed;
    _completedAt = DateTime.now();
    notifyListeners();
  }

  void markCancelled() {
    _state = DownloadTaskState.cancelled;
    _completedAt = DateTime.now();
    notifyListeners();
  }

  /// Resets a failed task so it can be retried with a fresh cancel token.
  void resetForRetry() {
    _state = DownloadTaskState.queued;
    _progress = const DownloadProgress();
    _error = null;
    _technicalDetails = null;
    _completedAt = null;
    _cancelToken = CancelToken();
    notifyListeners();
  }
}
