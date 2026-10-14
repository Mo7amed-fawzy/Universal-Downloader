import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/audio_format.dart';
import 'package:universal_downloader/core/models/audio_output_format.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/command_runner.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_progress.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';

import '../support/controlled_download_provider.dart';

void main() {
  test('audio-only YouTube task downloads the chosen audio track', () async {
    final ffmpegResult = await Process.run('which', ['ffmpeg']);
    final ffprobeResult = await Process.run('which', ['ffprobe']);
    if (ffmpegResult.exitCode != 0 || ffprobeResult.exitCode != 0) return;
    final ffmpeg = (ffmpegResult.stdout as String).trim();
    final ffprobe = (ffprobeResult.stdout as String).trim();
    final root = Directory.systemTemp.createTempSync('youtube_audio_only_');
    addTearDown(() => root.deleteSync(recursive: true));
    final source = File('${root.path}/source.m4a');
    final created = await Process.run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-c:a',
      'aac',
      source.path,
    ]);
    expect(created.exitCode, 0, reason: '${created.stderr}');
    final runner = AudioTrackRunner(source);
    final paths = QueueTestPaths(root);
    final provider = YoutubeProvider(
      ytDlpPath: 'yt-dlp',
      ffmpegPath: ffmpeg,
      ffprobePath: ffprobe,
      runner: runner,
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
    );
    final media = MediaInfo(
      id: 'track',
      title: 'Track',
      providerId: 'youtube',
      providerName: 'YouTube',
      pageUrl: Uri.parse('https://youtube.com/watch?v=track'),
      videoFormats: const [VideoFormat(formatId: 'v1080', height: 1080)],
      audioFormats: const [
        AudioFormat(formatId: 'en128', language: 'en', bitrate: 128),
      ],
    );
    final phases = <DownloadTaskState>[];
    final result = await provider.download(
      media,
      DownloadOptions(
        taskId: 'audio-only',
        outputDirectory: root.path,
        title: media.title,
        videoFormatId: 'v1080',
        audioFormatId: 'en128',
        audioLanguage: 'en',
        audioOutputFormat: AudioOutputFormat.mp3,
      ),
      onPhase: phases.add,
      onProgress: (DownloadProgress progress) {},
      cancelToken: CancelToken(),
    );
    expect(runner.selectedFormats, ['en128']);
    expect(phases, contains(DownloadTaskState.downloadingAudio));
    expect(phases, isNot(contains(DownloadTaskState.downloadingVideo)));
    expect(result.outputFile.path, endsWith('.mp3'));
    expect(result.outputFile.lengthSync(), greaterThan(0));
  });
}

class AudioTrackRunner implements CommandRunner {
  AudioTrackRunner(this.source);

  final File source;
  final List<String> selectedFormats = [];
  final ProcessRunner processRunner = const ProcessRunner();

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    if (executable == 'yt-dlp') {
      selectedFormats.add(arguments[arguments.indexOf('-f') + 1]);
      await source.copy(arguments[arguments.indexOf('-o') + 1]);
      return const ProcessRunnerResult(exitCode: 0, stdout: '', stderr: '');
    }
    return processRunner.run(
      executable: executable,
      arguments: arguments,
      environment: environment,
      onLine: onLine,
      cancelToken: cancelToken,
      workingDirectory: workingDirectory,
    );
  }
}
