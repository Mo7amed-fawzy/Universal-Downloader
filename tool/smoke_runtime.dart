import 'dart:io';

import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/core/services/dependency_checker.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';
import 'package:universal_downloader/core/tools/tool_paths.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) throw ArgumentError('Pass the app bundle directory');
  final root = await Directory.systemTemp.createTemp('runtime-smoke-');
  try {
    final paths = ToolPaths(
      bundledDirectory: Directory(
        '${Directory(arguments.first).absolute.path}/tools',
      ),
      updatesDirectory: Directory('${root.path}/updates'),
    );
    if (paths.selected == null) {
      throw StateError('Included tool bundle missing');
    }
    final ffmpeg = paths.resolve('ffmpeg');
    final ffprobe = paths.resolve('ffprobe');
    final checker = DependencyChecker(
      ytDlpPathOverride: paths.resolve('yt-dlp'),
      ffmpegPathOverride: ffmpeg,
      ffprobePathOverride: ffprobe,
      denoPathOverride: paths.resolve('deno'),
    );
    for (final status in await checker.checkAll()) {
      if (!status.installed) {
        throw StateError('${status.name} failed: ${status.path}');
      }
      stdout.writeln('${status.name}: ${status.version} (${status.path})');
    }
    const runner = ProcessRunner();
    final video = File('${root.path}/source.mp4');
    final cover = File('${root.path}/cover.jpg');
    final generated = await runner.run(
      executable: ffmpeg,
      arguments: [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=320x180:r=25',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=44100',
        '-t',
        '1',
        '-c:v',
        'mpeg4',
        '-c:a',
        'aac',
        video.path,
      ],
    );
    if (!generated.success) throw StateError(generated.stderr);
    final artwork = await runner.run(
      executable: ffmpeg,
      arguments: [
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        video.path,
        '-frames:v',
        '1',
        '-threads',
        '1',
        cover.path,
      ],
    );
    if (!artwork.success) throw StateError(artwork.stderr);
    final assembler = MediaAssembler(ffmpegPath: ffmpeg, ffprobePath: ffprobe);
    for (final extension in ['mp4', 'mkv']) {
      final output = await assembler.merge(
        video,
        null,
        '${root.path}/output.$extension',
        cover: cover,
        cancelToken: CancelToken(),
      );
      final report = await assembler.verify(
        output,
        expectedHeight: 180,
        expectCover: true,
      );
      if (!report.passed) throw StateError(report.failures.join('\n'));
    }
    final js = await runner.run(
      executable: paths.resolve('deno'),
      arguments: ['eval', 'console.log(1 + 1)'],
    );
    if (!js.success || js.stdout.trim() != '2') {
      throw StateError('Deno execution failed');
    }
    if (arguments.length > 1) {
      final provider = YoutubeProvider(
        ytDlpPath: paths.resolve('yt-dlp'),
        ffmpegPath: ffmpeg,
        ffprobePath: ffprobe,
        denoPath: paths.resolve('deno'),
      );
      final info = await provider.fetchInfo(Uri.parse(arguments[1]));
      if (info.videoFormats.isEmpty || info.audioFormats.isEmpty) {
        throw StateError('No formats extracted');
      }
      stdout.writeln(
        'Live metadata: ${info.title}; audio languages: ${info.audioLanguages.join(', ')}',
      );
    }
    stdout.writeln(
      'PASS: included tools, MP4/MKV cover merge, verification, and JavaScript runtime',
    );
  } finally {
    await root.delete(recursive: true);
  }
}
