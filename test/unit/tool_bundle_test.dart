import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/services/dependency_checker.dart';
import 'package:universal_downloader/core/tools/tool_bundle.dart';
import 'package:universal_downloader/core/tools/tool_bundle_installer.dart';
import 'package:universal_downloader/core/tools/tool_paths.dart';

void main() {
  late Directory root;
  late ToolPaths paths;

  setUp(() {
    root = Directory.systemTemp.createTempSync('tool_bundle_');
    paths = ToolPaths(
      bundledDirectory: Directory('${root.path}/included'),
      updatesDirectory: Directory('${root.path}/updates'),
    );
    writeBundle(paths.bundledDirectory, revision: 1);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
    'uses included tools regardless of PATH and preserves explicit overrides',
    () {
      expect(paths.resolve('yt-dlp'), '${root.path}/included/yt-dlp');
      expect(
        paths.resolve('ffmpeg', override: '/custom/ffmpeg'),
        '/custom/ffmpeg',
      );
    },
  );

  test(
    'installs a verified bundle and can restore the included tools',
    () async {
      final zip = makeUpdate(root, revision: 2);
      await ToolBundleInstaller(paths: paths).install(zip, await hash(zip), 2);
      expect(paths.selected!.revision, 2);
      expect(paths.resolve('deno'), contains('/bundle-2-'));
      final result = await Process.run(paths.resolve('deno'), ['--version']);
      expect(result.exitCode, 0);
      await paths.useIncluded();
      expect(paths.selected!.revision, 1);
    },
  );

  test(
    'a newer app bundle takes precedence over an older installed update',
    () async {
      final zip = makeUpdate(root, revision: 2);
      await ToolBundleInstaller(paths: paths).install(zip, await hash(zip), 2);
      writeBundle(paths.bundledDirectory, revision: 3);
      expect(paths.selected!.revision, 3);
      expect(paths.resolve('ffprobe'), '${root.path}/included/ffprobe');
    },
  );

  for (final failure in [
    'checksum',
    'traversal',
    'file hash',
    'executable',
    'revision',
  ]) {
    test('$failure keeps the active bundle and removes staging', () async {
      final good = makeUpdate(root, revision: 2);
      await ToolBundleInstaller(
        paths: paths,
      ).install(good, await hash(good), 2);
      final previous = paths.activeFile.readAsStringSync();
      final bad = makeUpdate(root, revision: 3, failure: failure);
      await expectLater(
        ToolBundleInstaller(paths: paths).install(
          bad,
          failure == 'checksum' ? '0' * 64 : await hash(bad),
          failure == 'revision' ? 4 : 3,
        ),
        throwsA(anything),
      );
      expect(paths.activeFile.readAsStringSync(), previous);
      expect(paths.selected!.revision, 2);
      expect(
        paths.updatesDirectory.listSync().where(
          (e) => e.path.contains('.install-'),
        ),
        isEmpty,
      );
      expect(File('${root.path}/escaped').existsSync(), isFalse);
    });
  }

  test('invalid active pointer falls back to included tools', () {
    paths.updatesDirectory.createSync();
    paths.activeFile.writeAsStringSync('../other');
    expect(paths.selected!.revision, 1);
  });

  test(
    'missing custom executable is reported unavailable without PATH fallback',
    () async {
      final checker = DependencyChecker(
        ytDlpPathOverride: '${root.path}/missing',
        ffmpegPathOverride: '${root.path}/missing',
        ffprobePathOverride: '${root.path}/missing',
        denoPathOverride: '${root.path}/missing',
      );
      expect(
        (await checker.checkAll()).every((status) => !status.installed),
        isTrue,
      );
    },
  );

  test('custom command names do not fall back to default tool names', () async {
    final checker = DependencyChecker(
      ytDlpPathOverride: 'nonexistent-universal-downloader-test-executable',
    );
    final status = (await checker.checkAll()).first;
    expect(status.installed, isFalse);
    expect(status.path, isNull);
  });
}

void writeBundle(
  Directory directory, {
  required int revision,
  String? failure,
}) {
  directory.createSync(recursive: true);
  final files = <String, String>{};
  for (final name in [
    ...ToolBundle.executables,
    'licenses/THIRD_PARTY_NOTICES.md',
  ]) {
    final file = File('${directory.path}/$name');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      failure == 'executable' && name == 'deno'
          ? '#!/bin/sh\nexit 1\n'
          : '#!/bin/sh\necho test-version\n',
    );
    files[name] = sha256.convert(file.readAsBytesSync()).toString();
  }
  if (failure == 'file hash') files['deno'] = '0' * 64;
  File('${directory.path}/manifest.json').writeAsStringSync(
    jsonEncode({
      'schema': 1,
      'platform': 'linux-x64',
      'revision': revision,
      'files': files,
    }),
  );
}

File makeUpdate(Directory root, {required int revision, String? failure}) {
  final directory = Directory('${root.path}/source-$revision');
  writeBundle(directory, revision: revision, failure: failure);
  final archive = Archive();
  for (final file in directory.listSync(recursive: true).whereType<File>()) {
    archive.add(
      ArchiveFile.bytes(
        file.path.substring(directory.path.length + 1),
        file.readAsBytesSync(),
      ),
    );
  }
  if (failure == 'traversal') archive.add(ArchiveFile.bytes('../escaped', [1]));
  return File('${root.path}/update-$revision.zip')
    ..writeAsBytesSync(ZipEncoder().encode(archive));
}

Future<String> hash(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
