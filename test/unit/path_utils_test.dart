import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/utils/path_utils.dart';

void main() {
  late Directory tempDir;
  const paths = PathUtils();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('path_utils_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('appends the extension when missing a leading dot', () {
    final path = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'My Video',
      extension: 'mp4',
    );
    expect(path, '${tempDir.path}/My Video.mp4');
  });

  test('accepts an extension with a leading dot', () {
    final path = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'My Video',
      extension: '.mkv',
    );
    expect(path, '${tempDir.path}/My Video.mkv');
  });

  test('sanitizes the base name', () {
    final path = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'a/b/c: bad',
      extension: 'mp4',
    );
    expect(path, '${tempDir.path}/a_b_c_ bad.mp4');
  });

  test('creates numbered suffixes when the file exists', () {
    final first = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'Clip',
      extension: 'mp4',
    );
    File(first).writeAsStringSync('x');

    final second = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'Clip',
      extension: 'mp4',
    );
    expect(second, '${tempDir.path}/Clip (1).mp4');
    File(second).writeAsStringSync('x');

    final third = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'Clip',
      extension: 'mp4',
    );
    expect(third, '${tempDir.path}/Clip (2).mp4');
  });

  test('overwrite returns the same path without a suffix', () {
    final first = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'Clip',
      extension: 'mp4',
    );
    File(first).writeAsStringSync('x');

    final again = paths.uniqueOutputPath(
      directory: tempDir.path,
      baseName: 'Clip',
      extension: 'mp4',
      overwrite: true,
    );
    expect(again, first);
  });

  test('task temp directories are namespaced by task id', () {
    final dir = paths.taskTempDirectory('abc123');
    expect(dir.path, contains('download_task_abc123'));
  });
}
