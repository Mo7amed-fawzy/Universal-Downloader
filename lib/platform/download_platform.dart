import '../core/process/command_runner.dart';
import '../core/process/cancel_token.dart';
import '../core/services/dependency_checker.dart';
import '../core/tools/media_tools.dart';
import '../core/utils/path_utils.dart';
import '../providers/downloader_provider.dart';
import '../settings/app_settings.dart';
import 'operating_system.dart';

abstract interface class DownloadPlatform {
  OperatingSystem get operatingSystem;
  CommandRunner get runner;
  PathUtils get paths;

  MediaTools resolveTools(AppSettings settings);
  Future<List<DependencyStatus>> checkTools(AppSettings settings);
  Future<String> updateTools({required void Function(String) onStatus});
  Future<void> useIncludedTools();
  String defaultDownloadDirectory();
  String resolveOutputDirectory(AppSettings settings);
  Future<String> publishDownload(
    DownloadTaskResult result, {
    required CancelToken cancelToken,
  });
  Future<void> openDownload(String location);
}
