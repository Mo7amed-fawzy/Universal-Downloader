import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/audio_output_format.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/direct/direct_media_provider.dart';

import '../support/controlled_download_provider.dart';

void main() {
  test('direct video produces an audio-only file', () async {
    final ffmpegResult = await Process.run('which', ['ffmpeg']);
    final ffprobeResult = await Process.run('which', ['ffprobe']);
    if (ffmpegResult.exitCode != 0 || ffprobeResult.exitCode != 0) return;
    final ffmpeg = (ffmpegResult.stdout as String).trim();
    final ffprobe = (ffprobeResult.stdout as String).trim();
    final root = Directory.systemTemp.createTempSync('direct_audio_only_');
    addTearDown(() => root.deleteSync(recursive: true));
    final source = File('${root.path}/source.mp4');
    final created = await Process.run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=black:size=160x120:duration=1',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-shortest',
      source.path,
    ]);
    expect(created.exitCode, 0, reason: '${created.stderr}');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    unawaited(() async {
      await for (final request in server) {
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.add(await source.readAsBytes());
        await request.response.close();
      }
    }());
    final url = Uri.parse('http://127.0.0.1:${server.port}/video.mp4');
    final paths = QueueTestPaths(root);
    final provider = DirectMediaProvider(
      ffmpegPath: ffmpeg,
      ffprobePath: ffprobe,
      repository: DownloadRepository(paths: paths),
      log: LogService(paths: paths),
    );
    final media = MediaInfo(
      id: 'direct',
      title: 'Direct',
      providerId: 'direct',
      providerName: 'Direct URL',
      pageUrl: url,
      videoFormats: const [
        VideoFormat(formatId: 'direct', container: 'mp4', hasAudio: true),
      ],
    );
    final phases = <DownloadTaskState>[];
    final result = await provider.download(
      media,
      DownloadOptions(
        taskId: 'direct-audio-only',
        outputDirectory: root.path,
        title: media.title,
        videoFormatId: 'direct',
        audioOutputFormat: AudioOutputFormat.flac,
      ),
      onPhase: phases.add,
      onProgress: (_) {},
      cancelToken: CancelToken(),
    );
    expect(phases, contains(DownloadTaskState.downloadingAudio));
    expect(result.outputFile.path, endsWith('.flac'));
    expect(result.outputFile.lengthSync(), greaterThan(0));
  });
}
