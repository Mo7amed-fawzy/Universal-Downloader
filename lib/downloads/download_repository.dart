import 'dart:io';
import 'dart:convert';

import '../core/errors/downloader_exceptions.dart';
import '../core/utils/path_utils.dart';
import '../providers/downloader_provider.dart';

/// Manages temporary working directories and final output naming.
class DownloadRepository {
  DownloadRepository({PathUtils? paths}) : _paths = paths ?? const PathUtils();

  final PathUtils _paths;

  Future<void> saveVerifiedResult(
    String taskId,
    DownloadTaskResult result,
  ) async {
    final directory = createTaskDirectory(taskId);
    final pending = File('${directory.path}/result.new');
    await pending.writeAsString(
      jsonEncode({
        'version': 1,
        'output': result.outputFile.path,
        'merged': result.merged,
        'files': [
          for (final file in [result.outputFile, ...result.sidecarFiles])
            {'path': file.path, 'length': await file.length()},
        ],
      }),
      flush: true,
    );
    await pending.rename('${directory.path}/result.json');
  }

  Future<DownloadTaskResult?> loadVerifiedResult(String taskId) async {
    final receipt = File(
      '${_paths.taskTempDirectory(taskId).path}/result.json',
    );
    if (!receipt.existsSync()) return null;
    try {
      final json = jsonDecode(await receipt.readAsString());
      if (json is! Map<String, Object?> ||
          json['version'] != 1 ||
          json['files'] is! List<Object?> ||
          json['merged'] is! bool) {
        return null;
      }
      final files = <File>[];
      for (final entry in json['files'] as List<Object?>) {
        if (entry is! Map<String, Object?> || entry['path'] is! String) {
          return null;
        }
        final file = File(entry['path'] as String);
        if (!file.existsSync() || await file.length() != entry['length']) {
          return null;
        }
        files.add(file);
      }
      if (files.isEmpty || files.first.path != json['output']) return null;
      return DownloadTaskResult(
        outputFile: files.first,
        merged: json['merged'] as bool,
        sidecarFiles: files.skip(1).toList(),
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

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
