import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/platform/android/android_bridge.dart';
import 'package:universal_downloader/platform/android/android_download_platform.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/android-runtime');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late AndroidDownloadPlatform platform;
  late List<MethodCall> calls;
  Future<Object?> Function(MethodCall)? onOperation;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('android_platform_');
    calls = [];
    onOperation = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') {
        return {
          'dataDirectory': root.path,
          'quickJs': '/apk/libqjs.so',
          'ffmpeg': '/apk/libffmpeg.so',
        };
      }
      if (onOperation != null) return onOperation!(call);
      if (call.method == 'run') {
        return {'exitCode': 0, 'stdout': 'bundled version', 'stderr': ''};
      }
      if (call.method == 'publish') return 'content://media/downloads/1';
      return null;
    });
    platform = await AndroidDownloadPlatform.create(
      bridge: AndroidBridge(channel: channel),
    );
  });

  tearDown(() {
    channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test('uses APK tools and private paths regardless of desktop overrides', () {
    const settings = AppSettings(
      ytDlpPath: '/desktop/ytdlp',
      ffmpegPath: '/desktop/ffmpeg',
      defaultDownloadDirectory: '/sdcard/download',
      extraYtDlpArgs: '--exec unwanted',
    );
    final tools = platform.resolveTools(settings);
    expect(tools.ytDlp, 'yt-dlp');
    expect(tools.ffmpeg, 'ffmpeg');
    expect(tools.ffprobe, 'ffprobe');
    expect(tools.ytDlpArguments, contains('quickjs:/apk/libqjs.so'));
    expect(tools.ytDlpArguments, contains('--no-remote-components'));
    expect(tools.ytDlpArguments, isNot(contains('--exec')));
    expect(platform.resolveOutputDirectory(settings), '${root.path}/output');
    expect(platform.paths.tempDirectory().path, '${root.path}/temp');
  });

  test('checks all five bundled tools through native execution', () async {
    final statuses = await platform.checkTools(const AppSettings());
    expect(statuses.map((item) => item.name), [
      'yt-dlp',
      'python',
      'quickjs',
      'ffmpeg',
      'ffprobe',
    ]);
    expect(statuses.every((item) => item.installed), isTrue);
    expect(calls.where((call) => call.method == 'run'), hasLength(5));
    final message = await platform.updateTools(onStatus: (_) {});
    expect(message, contains('newer app version'));
    expect(calls.any((call) => call.method == 'update'), isFalse);
  });

  test('passes exact arguments and nonzero exit results', () async {
    onOperation = (call) async => {
      'exitCode': 2,
      'stdout': '',
      'stderr': 'invalid input',
    };
    final result = await platform.runner.run(
      executable: 'ffmpeg',
      arguments: ['-i', '/private/a b.mp4'],
    );
    expect(result.exitCode, 2);
    expect(result.stderr, 'invalid input');
    expect(calls.last.arguments['arguments'], ['-i', '/private/a b.mp4']);
  });

  test('does not start a previously cancelled operation', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      platform.runner.run(
        executable: 'python',
        arguments: [],
        cancelToken: token,
      ),
      throwsA(isA<DownloadCancelledException>()),
    );
    expect(calls, hasLength(1));
  });

  test('cancellation targets the running native operation', () async {
    final pending = Completer<Object?>();
    final started = Completer<void>();
    String? id;
    onOperation = (call) async {
      if (call.method == 'run') {
        id = call.arguments['id'] as String;
        started.complete();
        return pending.future;
      }
      if (call.method == 'cancel') {
        expect(call.arguments['id'], id);
        pending.completeError(PlatformException(code: 'cancelled'));
      }
      return null;
    };
    final token = CancelToken();
    final result = platform.runner.run(
      executable: 'python',
      arguments: ['-c', 'wait'],
      cancelToken: token,
    );
    final assertion = expectLater(
      result,
      throwsA(isA<DownloadCancelledException>()),
    );
    await started.future;
    token.cancel();
    await assertion;
  });

  test('publishes video and subtitles before deleting local copies', () async {
    final video = File('${root.path}/video.mp4')..writeAsStringSync('media');
    final subtitle = File('${root.path}/video.ar.vtt')
      ..writeAsStringSync('WEBVTT');
    onOperation = (call) async {
      expect(call.method, 'publish');
      expect(call.arguments['paths'], [video.path, subtitle.path]);
      expect(video.existsSync(), isTrue);
      expect(subtitle.existsSync(), isTrue);
      return 'content://media/downloads/42';
    };
    final location = await platform.publishDownload(
      DownloadTaskResult(
        outputFile: video,
        merged: true,
        sidecarFiles: [subtitle],
      ),
      cancelToken: CancelToken(),
    );
    expect(location, 'content://media/downloads/42');
    expect(video.existsSync(), isFalse);
    expect(subtitle.existsSync(), isFalse);
  });

  test('publication failure preserves local output for recovery', () async {
    final video = File('${root.path}/video.mp4')..writeAsStringSync('media');
    onOperation = (_) async =>
        throw PlatformException(code: 'runtime_error', message: 'Disk full');
    await expectLater(
      platform.publishDownload(
        DownloadTaskResult(outputFile: video, merged: true),
        cancelToken: CancelToken(),
      ),
      throwsA(isA<PlatformException>()),
    );
    expect(video.readAsStringSync(), 'media');
  });

  test('opens the returned content URI through Android', () async {
    await platform.openDownload('content://media/downloads/42');
    expect(calls.last.method, 'open');
    expect(calls.last.arguments['uri'], 'content://media/downloads/42');
  });
}
