import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors/downloader_exceptions.dart';
import 'cancel_token.dart';
import 'process_runner_result.dart';

/// Safe process execution using argument arrays (never shell interpolation).
///
/// Captures stdout/stderr, reports lines to an optional callback and supports
/// cooperative cancellation that terminates the child process cleanly.
class ProcessRunner {
  const ProcessRunner();

  /// Runs [executable] with [arguments].
  ///
  /// When [onLine] is provided it is called for every line read from stdout
  /// and stderr. If [cancelToken] is cancelled while the process is running,
  /// the process is terminated and [DownloadCancelledException] is thrown.
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    cancelToken?.throwIfCancelled();

    final process = await Process.start(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );

    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        stdoutLines.add(line);
        onLine?.call(line, true);
      },
      onDone: () {
        if (!stdoutDone.isCompleted) stdoutDone.complete();
      },
      onError: (Object e) {
        if (!stdoutDone.isCompleted) stdoutDone.complete();
      },
    );

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        stderrLines.add(line);
        onLine?.call(line, false);
      },
      onDone: () {
        if (!stderrDone.isCompleted) stderrDone.complete();
      },
      onError: (Object e) {
        if (!stderrDone.isCompleted) stderrDone.complete();
      },
    );

    StreamSubscription<void>? cancelSub;
    if (cancelToken != null) {
      cancelSub = cancelToken.whenCancelled
          .then((_) => _terminate(process))
          .asStream()
          .listen((_) {});
    }

    try {
      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone.future, stderrDone.future]);

      cancelToken?.throwIfCancelled();

      return ProcessRunnerResult(
        exitCode: exitCode,
        stdout: stdoutLines.join('\n'),
        stderr: stderrLines.join('\n'),
      );
    } on DownloaderException {
      rethrow;
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) {
        throw DownloadCancelledException(details: e.toString());
      }
      rethrow;
    } finally {
      await cancelSub?.cancel();
    }
  }

  /// Terminates a child process: SIGTERM first, then SIGKILL after a grace
  /// period so that children (e.g. spawned ffmpeg) are released.
  static Future<void> _terminate(Process process) async {
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {
      // process already gone
    }
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {
        // already gone
      }
    }
  }
}
