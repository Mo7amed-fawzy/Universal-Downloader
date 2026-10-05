import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';
import 'package:universal_downloader/platform/android/android_download_platform.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/providers/format_selector.dart';
import 'package:universal_downloader/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Android runtime smoke test'))),
    ),
  );
  final report = <String, Object?>{};
  AndroidDownloadPlatform? platform;
  try {
    platform = await AndroidDownloadPlatform.create();
    final statuses = await platform.checkTools(const AppSettings());
    report['tools'] = {
      for (final status in statuses)
        status.name: {
          'ok': status.installed,
          'version': status.version,
          'error': status.installInstructions,
        },
    };
    if (statuses.any((status) => !status.installed)) {
      throw StateError('Tool check failed');
    }
    final directory = Directory(platform.defaultDownloadDirectory())
      ..createSync(recursive: true);
    Future<void> command(String tool, List<String> arguments) async {
      final result = await platform!.runner.run(
        executable: tool,
        arguments: arguments,
      );
      if (!result.success) throw StateError('$tool: ${result.stderr}');
    }

    final input = File('${directory.path}/input.mp4');
    await command('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=128x72:rate=10',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440',
      '-t',
      '2',
      '-c:v',
      'mpeg4',
      '-c:a',
      'aac',
      '-metadata:s:a:0',
      'language=ara',
      input.path,
    ]);
    final cover = File('${directory.path}/cover.jpg');
    await command('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=64x64',
      '-frames:v',
      '1',
      '-update',
      '1',
      cover.path,
    ]);
    final assembler = MediaAssembler(
      ffmpegPath: 'ffmpeg',
      ffprobePath: 'ffprobe',
      runner: platform.runner,
    );
    for (final extension in ['mp4', 'mkv']) {
      final output = await assembler.merge(
        input,
        null,
        '${directory.path}/smoke.$extension',
        cover: cover,
        cancelToken: CancelToken(),
      );
      final verification = await assembler.verify(
        output,
        expectedAudioLanguage: 'ara',
        expectedHeight: 72,
        expectCover: true,
      );
      if (!verification.passed) {
        throw StateError(verification.failures.join('; '));
      }
      final subtitle = File('${directory.path}/smoke.ar.vtt')
        ..writeAsStringSync('WEBVTT\n\n00:00.000 --> 00:01.000\nمرحبا\n');
      report[extension] = await platform.publishDownload(
        DownloadTaskResult(
          outputFile: output,
          merged: true,
          sidecarFiles: [subtitle],
        ),
        cancelToken: CancelToken(),
      );
    }
    final token = CancelToken();
    final pending = platform.runner.run(
      executable: 'python',
      arguments: [
        '-c',
        'import time; print("ready",flush=True); time.sleep(60)',
      ],
      cancelToken: token,
      onLine: (line, _) {
        if (line == 'ready') token.cancel();
      },
    );
    try {
      await pending.timeout(const Duration(seconds: 10));
      throw StateError('Cancellation did not stop the process');
    } on DownloadCancelledException {
      report['cancellation'] = true;
    }
    if (const bool.fromEnvironment('ANDROID_LIVE_TEST')) {
      final controller = await AppController.create(platform: platform);
      final provider = controller.registry.byId('youtube')!;
      final metadata = await provider.fetchInfo(
        Uri.parse('https://www.youtube.com/watch?v=TfoJ55nx1S4'),
      );
      report['liveLanguages'] = metadata.audioLanguages;
      final media = await provider.fetchInfo(
        Uri.parse('https://www.youtube.com/watch?v=jNQXAC9IVRw'),
      );
      const selector = FormatSelector();
      final video = selector.selectBestVideo(
        media.videoFormats,
        quality: VideoQuality.q360,
      )!;
      final audio = selector.selectBestAudio(
        media.audioFormats,
        preferredLanguage: 'en',
        allowOtherLanguages: true,
      );
      final result = await provider.download(
        media,
        DownloadOptions(
          taskId: 'android-live-smoke',
          outputDirectory: directory.path,
          title: 'Android live smoke',
          videoFormatId: video.formatId,
          audioFormatId: audio?.formatId,
          audioLanguage: audio?.language,
        ),
        onPhase: (_) {},
        onProgress: (_) {},
        cancelToken: CancelToken(),
      );
      report['liveDownload'] = await platform.publishDownload(
        result,
        cancelToken: CancelToken(),
      );
    }
    report['passed'] = true;
  } catch (error, stack) {
    report['passed'] = false;
    report['error'] = '$error\n$stack';
  }
  final json = jsonEncode(report);
  debugPrint('ANDROID_SMOKE_RESULT $json');
  if (platform != null) {
    File('${platform.paths.root}/smoke-result.json').writeAsStringSync(json);
  }
}
