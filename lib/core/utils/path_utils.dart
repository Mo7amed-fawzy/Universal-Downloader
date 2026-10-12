import 'dart:io';

import 'filename_sanitizer.dart';

/// Filesystem helpers: application data directories and unique output names.
class PathUtils {
  const PathUtils();

  /// Root application data directory, e.g.
  /// `~/.local/share/universal_downloader`.
  Directory appDataDirectory() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final xdg = Platform.environment['XDG_DATA_HOME'];
    final base = (xdg != null && xdg.isNotEmpty)
        ? xdg
        : '$home/.local/share';
    return Directory('$base/universal_downloader');
  }

  /// Directory for temporary download artifacts.
  Directory tempDirectory() {
    return Directory('${appDataDirectory().path}/temp');
  }

  /// Directory for debug logs.
  Directory logDirectory() {
    return Directory('${appDataDirectory().path}/logs');
  }

  /// A unique working directory for one download task, e.g.
  /// `temp/download_task_<id>/`.
  Directory taskTempDirectory(String taskId) {
    return Directory('${tempDirectory().path}/download_task_$taskId');
  }

  /// Builds a unique output path inside [directory] for [baseName].
  ///
  /// When the file already exists, appends ` (1)`, ` (2)`, ... unless
  /// [overwrite] is true.
  String uniqueOutputPath({
    required String directory,
    required String baseName,
    required String extension,
    bool overwrite = false,
  }) {
    final sanitizer = const FilenameSanitizer();
    final clean = sanitizer.sanitize(baseName);
    final ext = extension.startsWith('.') ? extension : '.$extension';

    var candidate = '$directory/$clean$ext';
    if (overwrite) return candidate;

    var counter = 1;
    while (File(candidate).existsSync()) {
      candidate = '$directory/$clean ($counter)$ext';
      counter++;
    }
    return candidate;
  }
}
