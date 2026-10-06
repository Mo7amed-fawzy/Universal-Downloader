import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:universal_downloader/core/errors/downloader_exceptions.dart';

import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/core/services/dependency_checker.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';
import 'package:universal_downloader/core/tools/tool_paths.dart';
import 'package:universal_downloader/core/tools/tool_platform.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) throw ArgumentError('Pass the app bundle directory');
  final root = await Directory.systemTemp.createTemp('runtime smoke العربية ');
  try {
    final paths = ToolPaths(
      target: Platform.isWindows
          ? ToolPlatform.windowsX64
          : ToolPlatform.linuxX64,
      allowSystemFallback: false,
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
    if (Platform.isWindows) {
      await verifyWindowsCancellation(paths.resolve('deno'), root);
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

Future<void> verifyWindowsCancellation(String deno, Directory root) async {
  final marker = File('${root.path}/child-alive.txt');
  final child =
      'setInterval(() => Deno.writeTextFileSync(${jsonEncode(marker.path)}, "alive\\n", {append: true}), 50); console.log("CHILD_READY");';
  final parent =
      'const child = new Deno.Command(Deno.execPath(), {args: ["eval", ${jsonEncode(child)}], stdout: "inherit", stderr: "inherit"}).spawn(); await child.status;';
  final token = CancelToken();
  var ready = false;
  final deadline = Timer(const Duration(seconds: 15), token.cancel);
  try {
    await const ProcessRunner()
        .run(
          executable: deno,
          arguments: ['eval', parent],
          cancelToken: token,
          onLine: (line, _) {
            if (line == 'CHILD_READY') {
              ready = true;
              token.cancel();
            }
          },
        )
        .timeout(const Duration(seconds: 25));
    throw StateError('Cancellation returned success');
  } on DownloadCancelledException {
    if (!ready) throw StateError('Child process did not start');
  } finally {
    deadline.cancel();
  }
  final length = marker.existsSync() ? marker.lengthSync() : 0;
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if ((marker.existsSync() ? marker.lengthSync() : 0) != length) {
    throw StateError('Cancellation left a child process running');
  }
  stdout.writeln('PASS: Windows process-tree cancellation');
}
