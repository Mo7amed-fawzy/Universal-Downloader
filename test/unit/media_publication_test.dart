import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';

void main() {
  late Directory root;
  late File output;

  setUp(() {
    root = Directory.systemTemp.createTempSync('media_publication_');
    output = File('${root.path}/Video.mp4');
  });

  tearDown(() => root.deleteSync(recursive: true));

  for (final existing in [false, true]) {
    test('publishes only completed output with existing=$existing', () async {
      if (existing) output.writeAsStringSync('original');
      final runner = PublicationRunner((pending, token) {
        expect(pending.path, isNot(output.path));
        expect(pending.parent.parent.path, root.path);
        expect(
          pending.parent.uri.pathSegments.where((s) => s.isNotEmpty).last,
          startsWith('.universal-downloader-'),
        );
        pending.writeAsStringSync('partial');
        expect(output.existsSync(), existing);
        if (existing) expect(output.readAsStringSync(), 'original');
        pending.writeAsStringSync('complete');
        return 0;
      });
      final assembler = MediaAssembler(
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
        runner: runner,
      );
      await assembler.merge(File('${root.path}/video.tmp'), null, output.path);
      expect(output.readAsStringSync(), 'complete');
      expect(root.listSync().whereType<Directory>(), isEmpty);
    });
  }

  for (final failure in ['error', 'cancelled', 'empty']) {
    test(
      '$failure preserves existing output and removes partial staging',
      () async {
        output.writeAsStringSync('original');
        final token = CancelToken();
        final runner = PublicationRunner((pending, token) {
          pending.writeAsStringSync(failure == 'empty' ? '' : 'partial');
          if (failure == 'cancelled') token!.cancel();
          return failure == 'error' ? 1 : 0;
        });
        final assembler = MediaAssembler(
          ffmpegPath: 'ffmpeg',
          ffprobePath: 'ffprobe',
          runner: runner,
        );
        await expectLater(
          assembler.merge(
            File('${root.path}/video.tmp'),
            null,
            output.path,
            cancelToken: token,
          ),
          throwsA(
            failure == 'cancelled'
                ? isA<DownloadCancelledException>()
                : isA<MergeException>(),
          ),
        );
        expect(output.readAsStringSync(), 'original');
        expect(root.listSync().whereType<Directory>(), isEmpty);
      },
    );
  }
}

class PublicationRunner extends ProcessRunner {
  const PublicationRunner(this.writeOutput);

  final int Function(File pending, CancelToken? token) writeOutput;

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    return ProcessRunnerResult(
      exitCode: writeOutput(File(arguments.last), cancelToken),
      stdout: '',
      stderr: '',
    );
  }
}
