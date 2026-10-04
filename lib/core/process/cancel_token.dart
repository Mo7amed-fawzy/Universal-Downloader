import 'dart:async';

import '../errors/downloader_exceptions.dart';

/// Cooperative cancellation primitive shared across async download steps.
class CancelToken {
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  Future<void> get whenCancelled => _completer.future;

  /// Marks the operation as cancelled. Safe to call multiple times.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _completer.complete();
  }

  /// Throws [DownloadCancelledException] when the token is cancelled.
  void throwIfCancelled() {
    if (_cancelled) {
      throw DownloadCancelledException();
    }
  }

  /// Runs [action] but throws [DownloadCancelledException] as soon as the
  /// token is cancelled.
  Future<T> race<T>(Future<T> action) async {
    if (_cancelled) throw DownloadCancelledException();
    final result = await Future.any<T>([
      action,
      whenCancelled.then<T>((_) => throw DownloadCancelledException()),
    ]);
    return result;
  }
}
