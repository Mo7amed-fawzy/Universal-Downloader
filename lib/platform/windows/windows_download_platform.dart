import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/process/command_runner.dart';
import '../../core/process/process_runner.dart';
import '../../core/tools/tool_paths.dart';
import '../../core/tools/tool_platform.dart';
import '../desktop/desktop_download_platform.dart';
import '../operating_system.dart';
import 'windows_paths.dart';

class WindowsDownloadPlatform extends DesktopDownloadPlatform {
  WindowsDownloadPlatform._({
    required WindowsPaths paths,
    required this.downloadsDirectory,
    required this.channel,
    required super.toolPaths,
    required super.runner,
  }) : super(paths: paths);

  static const defaultChannel = MethodChannel('universal_downloader/windows');

  final String downloadsDirectory;
  final MethodChannel channel;

  static Future<WindowsDownloadPlatform> create({
    MethodChannel channel = defaultChannel,
    Directory? bundledDirectory,
    CommandRunner runner = const ProcessRunner(),
  }) async {
    final directories = await channel.invokeMapMethod<String, String>(
      'directories',
    );
    final localAppData = directories?['localAppData'];
    final downloads = directories?['downloads'];
    if (localAppData == null ||
        localAppData.isEmpty ||
        downloads == null ||
        downloads.isEmpty) {
      throw const FileSystemException(
        'Windows application directories are unavailable.',
      );
    }
    final paths = WindowsPaths(localAppData);
    return WindowsDownloadPlatform._(
      paths: paths,
      downloadsDirectory: downloads,
      channel: channel,
      runner: runner,
      toolPaths: ToolPaths(
        target: ToolPlatform.windowsX64,
        allowSystemFallback: false,
        bundledDirectory: bundledDirectory,
        updatesDirectory: Directory('${paths.appDataDirectory().path}/tools'),
      ),
    );
  }

  @override
  OperatingSystem get operatingSystem => OperatingSystem.windows;

  @override
  String defaultDownloadDirectory() => downloadsDirectory;

  @override
  Future<void> openDownload(String location) => channel.invokeMethod<void>(
    'revealFile',
    {'path': File(location).absolute.path},
  );
}
