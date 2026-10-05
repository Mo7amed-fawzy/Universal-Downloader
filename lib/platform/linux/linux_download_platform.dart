import 'dart:io';

import '../../core/process/cancel_token.dart';
import '../../core/process/command_runner.dart';
import '../../core/process/process_runner.dart';
import '../../core/services/dependency_checker.dart';
import '../../core/services/file_location_service.dart';
import '../../core/tools/media_tools.dart';
import '../../core/tools/tool_paths.dart';
import '../../core/tools/tool_update_service.dart';
import '../../core/utils/path_utils.dart';
import '../../providers/downloader_provider.dart';
import '../../settings/app_settings.dart';
import '../download_platform.dart';
import '../operating_system.dart';

class LinuxDownloadPlatform implements DownloadPlatform {
  LinuxDownloadPlatform({
    this.runner = const ProcessRunner(),
    this.paths = const PathUtils(),
    ToolPaths? toolPaths,
  }) : toolPaths =
           toolPaths ??
           ToolPaths(
             updatesDirectory: Directory(
               '${paths.appDataDirectory().path}/tools',
             ),
           );

  @override
  OperatingSystem get operatingSystem => OperatingSystem.linux;
  @override
  final CommandRunner runner;
  @override
  final PathUtils paths;
  final ToolPaths toolPaths;

  @override
  MediaTools resolveTools(AppSettings settings) {
    final ffmpeg = toolPaths.resolve('ffmpeg', override: settings.ffmpegPath);
    return MediaTools(
      ytDlp: toolPaths.resolve('yt-dlp', override: settings.ytDlpPath),
      ffmpeg: ffmpeg,
      ffprobe: toolPaths.resolve('ffprobe', override: settings.ffprobePath),
      ytDlpArguments: [
        '--ignore-config',
        '--no-remote-components',
        '--no-js-runtimes',
        '--js-runtimes',
        'deno:${toolPaths.resolve('deno')}',
        '--ffmpeg-location',
        ffmpeg,
        if (settings.extraYtDlpArgs.trim().isNotEmpty)
          ...settings.extraYtDlpArgs.trim().split(RegExp(r'\s+')),
      ],
    );
  }

  @override
  Future<List<DependencyStatus>> checkTools(AppSettings settings) {
    final tools = resolveTools(settings);
    return DependencyChecker(
      runner: runner,
      ytDlpPathOverride: tools.ytDlp,
      ffmpegPathOverride: tools.ffmpeg,
      ffprobePathOverride: tools.ffprobe,
      denoPathOverride: toolPaths.resolve('deno'),
    ).checkAll();
  }

  @override
  Future<String> updateTools({required void Function(String) onStatus}) =>
      ToolUpdateService(toolPaths).update(onStatus: onStatus);

  @override
  Future<void> useIncludedTools() => toolPaths.useIncluded();

  @override
  String defaultDownloadDirectory() {
    final home = Platform.environment['HOME'] ?? '';
    final videos = '$home/Videos';
    return Directory(videos).existsSync() ? videos : '$home/Downloads';
  }

  @override
  String resolveOutputDirectory(AppSettings settings) {
    if (settings.rememberLastDirectory &&
        settings.lastDownloadDirectory.isNotEmpty) {
      return settings.lastDownloadDirectory;
    }
    if (settings.defaultDownloadDirectory.isNotEmpty) {
      return settings.defaultDownloadDirectory;
    }
    return defaultDownloadDirectory();
  }

  @override
  Future<String> publishDownload(
    DownloadTaskResult result, {
    required CancelToken cancelToken,
  }) async => result.outputFile.path;

  @override
  Future<void> openDownload(String location) =>
      FileLocationService(runner: runner).open(location);
}
