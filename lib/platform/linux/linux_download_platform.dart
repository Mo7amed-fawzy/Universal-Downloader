import 'dart:io';

import '../../core/services/file_location_service.dart';
import '../../core/tools/tool_paths.dart';
import '../../core/utils/path_utils.dart';
import '../desktop/desktop_download_platform.dart';
import '../operating_system.dart';

class LinuxDownloadPlatform extends DesktopDownloadPlatform {
  LinuxDownloadPlatform({
    super.runner,
    super.paths = const PathUtils(),
    ToolPaths? toolPaths,
  }) : super(
         toolPaths:
             toolPaths ??
             ToolPaths(
               updatesDirectory: Directory(
                 '${paths.appDataDirectory().path}/tools',
               ),
             ),
       );

  @override
  OperatingSystem get operatingSystem => OperatingSystem.linux;

  @override
  String defaultDownloadDirectory() {
    final home = Platform.environment['HOME'] ?? '';
    final videos = '$home/Videos';
    return Directory(videos).existsSync() ? videos : '$home/Downloads';
  }

  @override
  Future<void> openDownload(String location) =>
      FileLocationService(runner: runner).open(location);
}
