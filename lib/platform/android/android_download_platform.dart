import 'dart:io';

import '../../core/process/cancel_token.dart';
import '../../core/services/dependency_checker.dart';
import '../../core/tools/media_tools.dart';
import '../../providers/downloader_provider.dart';
import '../../settings/app_settings.dart';
import '../download_platform.dart';
import '../operating_system.dart';
import 'android_bridge.dart';
import 'android_command_runner.dart';
import 'android_paths.dart';

class AndroidDownloadPlatform implements DownloadPlatform {
  AndroidDownloadPlatform._(
    this.bridge,
    this.paths,
    this.quickJsPath,
    this.ffmpegPath,
  ) : runner = AndroidCommandRunner(bridge);

  static Future<AndroidDownloadPlatform> create({AndroidBridge? bridge}) async {
    final native = bridge ?? AndroidBridge();
    final config = await native.initialize();
    if (config case {
      'dataDirectory': String root,
      'quickJs': String quickJs,
      'ffmpeg': String ffmpeg,
    }) {
      return AndroidDownloadPlatform._(
        native,
        AndroidPaths(root),
        quickJs,
        ffmpeg,
      );
    }
    throw StateError('Android runtime paths are incomplete.');
  }

  final AndroidBridge bridge;
  final String quickJsPath;
  final String ffmpegPath;
  @override
  final AndroidPaths paths;
  @override
  final AndroidCommandRunner runner;
  @override
  OperatingSystem get operatingSystem => OperatingSystem.android;

  @override
  MediaTools resolveTools(AppSettings settings) => MediaTools(
    ytDlp: 'yt-dlp',
    ffmpeg: 'ffmpeg',
    ffprobe: 'ffprobe',
    ytDlpArguments: [
      '--ignore-config',
      '--no-cache-dir',
      '--no-remote-components',
      '--no-js-runtimes',
      '--js-runtimes',
      'quickjs:$quickJsPath',
      '--ffmpeg-location',
      ffmpegPath,
    ],
  );

  @override
  Future<List<DependencyStatus>> checkTools(AppSettings settings) =>
      Future.wait([
        for (final tool in ['yt-dlp', 'python', 'quickjs', 'ffmpeg', 'ffprobe'])
          _checkTool(tool),
      ]);

  Future<DependencyStatus> _checkTool(String tool) async {
    try {
      final result = await runner.run(
        executable: tool,
        arguments: switch (tool) {
          'ffmpeg' || 'ffprobe' => ['-version'],
          'quickjs' => ['-e', "console.log('QuickJS ready')"],
          _ => ['--version'],
        },
      );
      return DependencyStatus(
        name: tool,
        installed: result.success,
        version: result.stdout.trim().split('\n').first,
        path: 'Included in APK',
        installInstructions: result.success ? null : result.stderr,
      );
    } catch (error) {
      return DependencyStatus(
        name: tool,
        installed: false,
        installInstructions: 'Reinstall the complete APK. $error',
      );
    }
  }

  @override
  Future<String> updateTools({required void Function(String) onStatus}) async =>
      'Android tools are included in the APK. Install a newer app version to update them.';

  @override
  Future<void> useIncludedTools() async {}

  @override
  String defaultDownloadDirectory() => '${paths.root}/output';

  @override
  String resolveOutputDirectory(AppSettings settings) =>
      defaultDownloadDirectory();

  @override
  Future<String> publishDownload(
    DownloadTaskResult result, {
    required CancelToken cancelToken,
  }) async {
    final files = [result.outputFile, ...result.sidecarFiles];
    final uri = await bridge.execute<String>('publish', {
      'paths': files.map((file) => file.path).toList(),
    }, cancelToken: cancelToken);
    if (uri == null || !uri.startsWith('content://')) {
      throw StateError('Android did not return a saved download URI.');
    }
    for (final file in files) {
      try {
        await file.delete();
      } on FileSystemException catch (_) {}
    }
    return uri;
  }

  @override
  Future<void> openDownload(String location) => bridge.open(location);
}
