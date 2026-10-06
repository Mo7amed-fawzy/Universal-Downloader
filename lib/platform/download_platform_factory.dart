import 'download_platform.dart';
import 'android/android_download_platform.dart';
import 'linux/linux_download_platform.dart';
import 'operating_system.dart';
import 'windows/windows_download_platform.dart';

class DownloadPlatformFactory {
  const DownloadPlatformFactory();

  Future<DownloadPlatform> create({OperatingSystem? operatingSystem}) async {
    final selected = operatingSystem ?? OperatingSystem.detect();
    return switch (selected) {
      OperatingSystem.linux => LinuxDownloadPlatform(),
      OperatingSystem.windows => WindowsDownloadPlatform.create(),
      OperatingSystem.android => AndroidDownloadPlatform.create(),
      _ => throw UnsupportedError(
        'Downloads are not implemented for this operating system.',
      ),
    };
  }
}
