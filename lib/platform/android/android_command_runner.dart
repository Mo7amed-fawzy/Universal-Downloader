import '../../core/process/cancel_token.dart';
import '../../core/process/command_runner.dart';
import '../../core/process/process_runner_result.dart';
import 'android_bridge.dart';

class AndroidCommandRunner implements CommandRunner {
  const AndroidCommandRunner(this.bridge);
  final AndroidBridge bridge;

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    final result = await bridge.execute<Map<Object?, Object?>>(
      'run',
      {
        'tool': executable,
        'arguments': arguments,
        'environment': environment,
        'workingDirectory': workingDirectory,
      },
      cancelToken: cancelToken,
      onLine: onLine,
    );
    cancelToken?.throwIfCancelled();
    if (result case {
      'exitCode': int code,
      'stdout': String stdout,
      'stderr': String stderr,
    }) {
      return ProcessRunnerResult(
        exitCode: code,
        stdout: stdout,
        stderr: stderr,
      );
    }
    throw StateError('Invalid Android command result.');
  }
}
