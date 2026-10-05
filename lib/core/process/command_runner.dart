import 'cancel_token.dart';
import 'process_runner_result.dart';

abstract interface class CommandRunner {
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  });
}
