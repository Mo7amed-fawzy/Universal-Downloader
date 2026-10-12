import 'dart:io';

import '../core/errors/downloader_exceptions.dart';
import '../core/utils/path_utils.dart';

/// Manages temporary working directories and final output naming.
class DownloadRepository {
  DownloadRepository({PathUtils? paths}) : _paths = paths ?? const PathUtils();

  final PathUtils _paths;

  /// Creates (or reuses) the working directory for [taskId].
  Directory createTaskDirectory(String taskId) {
    final dir = _paths.taskTempDirectory(taskId);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Removes the working directory for [taskId] recursively.
  void cleanupTaskDirectory(String taskId) {
    try {
      final dir = _paths.taskTempDirectory(taskId);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {
      // Cleanup is best-effort.
    }
  }

  /// Returns the final output path, creating a unique name when the file
  /// already exists (unless [overwrite]).
  String buildUniqueOutputPath({
    required String outputDirectory,
    required String baseName,
    required String extension,
    bool overwrite = false,
  }) {
    return _paths.uniqueOutputPath(
      directory: outputDirectory,
      baseName: baseName,
      extension: extension,
      overwrite: overwrite,
    );
  }

  /// Ensures [directory] exists, throwing a friendly error otherwise.
  void ensureDirectory(String directory) {
    final dir = Directory(directory);
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (e) {
      throw FilesystemException(
        'Could not create output directory: $directory',
        details: e.toString(),
      );
    }
    if (!dir.existsSync()) {
      throw FilesystemException('Output directory does not exist: $directory');
    }
  }
}
