import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/command_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/core/services/dependency_checker.dart';
import 'package:universal_downloader/core/tools/tool_bundle.dart';
import 'package:universal_downloader/core/tools/tool_bundle_installer.dart';
import 'package:universal_downloader/core/tools/tool_paths.dart';
import 'package:universal_downloader/core/tools/tool_platform.dart';
import 'package:universal_downloader/platform/download_platform_factory.dart';
import 'package:universal_downloader/platform/operating_system.dart';
import 'package:universal_downloader/platform/windows/windows_download_platform.dart';
import 'package:universal_downloader/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = WindowsDownloadPlatform.defaultChannel;
  late Directory root;
  late List<MethodCall> calls;

  setUp(() {
    root = Directory.systemTemp.createTempSync('windows tools مسار ');
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'directories') {
        return {
          'localAppData': '${root.path}/Local Data',
          'downloads': '${root.path}/Redirected Downloads',
        };
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test(
    'factory uses Windows native known folders and Explorer bridge',
    () async {
      final platform = await const DownloadPlatformFactory().create(
        operatingSystem: OperatingSystem.windows,
      );
      expect(platform, isA<WindowsDownloadPlatform>());
      expect(
        platform.paths.appDataDirectory().path,
        '${root.path}/Local Data/UniversalDownloader',
      );
      expect(
        platform.defaultDownloadDirectory(),
        '${root.path}/Redirected Downloads',
      );
      expect(
        platform.resolveOutputDirectory(
          const AppSettings(defaultDownloadDirectory: 'D:/Videos'),
        ),
        'D:/Videos',
      );
      final location = '${root.path}/العربية, video.mp4';
      await platform.openDownload(location);
      expect(calls.last.method, 'revealFile');
      expect(calls.last.arguments, {'path': File(location).absolute.path});
    },
  );

  test('missing native directories fail startup explicitly', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'localAppData': ''},
    );
    await expectLater(
      WindowsDownloadPlatform.create(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'Windows resolves bundled EXEs and passes paths with spaces as single arguments',
    () async {
      final runner = VersionRunner();
      final included = Directory('${root.path}/App Folder/tools');
      writeWindowsBundle(included, revision: 1);
      final platform = await WindowsDownloadPlatform.create(
        bundledDirectory: included,
        runner: runner,
      );
      final tools = platform.resolveTools(const AppSettings());
      expect(tools.ytDlp, '${included.path}/yt-dlp.exe');
      expect(tools.ytDlpArguments, contains('deno:${included.path}/deno.exe'));
      expect(
        tools.ytDlpArguments,
        containsAllInOrder([
          '--ffmpeg-location',
          '${included.path}/ffmpeg.exe',
        ]),
      );
      expect(
        (await platform.checkTools(
          const AppSettings(),
        )).every((s) => s.installed),
        isTrue,
      );
      expect(runner.executables, everyElement(startsWith(included.path)));
      expect(
        platform
            .resolveTools(
              const AppSettings(ffmpegPath: r'C:\Custom Tools\ffmpeg.exe'),
            )
            .ffmpeg,
        r'C:\Custom Tools\ffmpeg.exe',
      );
    },
  );

  test(
    'missing Windows bundle never silently selects a system executable',
    () async {
      final included = Directory('${root.path}/missing/tools');
      final platform = await WindowsDownloadPlatform.create(
        bundledDirectory: included,
      );
      expect(
        platform.resolveTools(const AppSettings()).ytDlp,
        '${included.path}/yt-dlp.exe',
      );
    },
  );

  test('Windows overrides with backslashes bypass PATH lookup', () async {
    final runner = VersionRunner();
    final statuses = await DependencyChecker(
      runner: runner,
      ytDlpPathOverride: r'C:\App Folder\yt-dlp.exe',
    ).checkAll();
    expect(statuses.first.installed, isTrue);
    expect(statuses.first.path, r'C:\App Folder\yt-dlp.exe');
  });

  test('Windows manifest cannot be used as a Linux runtime', () {
    writeWindowsBundle(root, revision: 1);
    expect(() => ToolBundle.read(root), throwsFormatException);
    expect(
      ToolBundle.read(
        root,
        target: ToolPlatform.windowsX64,
      ).executable('ffmpeg'),
      '${root.path}/ffmpeg.exe',
    );
  });

  test(
    'Windows update validates EXEs without chmod and restores included tools',
    () async {
      final paths = ToolPaths(
        target: ToolPlatform.windowsX64,
        bundledDirectory: Directory('${root.path}/included'),
        updatesDirectory: Directory('${root.path}/updates'),
      );
      writeWindowsBundle(paths.bundledDirectory, revision: 1);
      final runner = VersionRunner();
      for (final revision in [2, 3]) {
        final zip = windowsUpdate(root, revision: revision);
        await ToolBundleInstaller(paths: paths, runner: runner).install(
          zip,
          sha256.convert(zip.readAsBytesSync()).toString(),
          revision,
        );
        expect(paths.selected!.revision, revision);
      }
      expect(runner.executables, hasLength(8));
      expect(runner.executables, everyElement(endsWith('.exe')));
      await paths.useIncluded();
      expect(paths.selected!.revision, 1);
    },
  );

  for (final unsafe in [
    'C:/escape.exe',
    'file:stream',
    'CON.txt',
    'AUX',
    'tools./file',
    'file ',
    '../escape',
    'file\\name',
  ]) {
    test('rejects Windows unsafe archive name $unsafe', () {
      expect(ToolBundle.validPath(unsafe), isFalse);
    });
  }

  for (final failure in [
    'case collision',
    'wrong platform',
    'file hash',
    'executable',
  ]) {
    test('$failure update preserves the installed Windows bundle', () async {
      final paths = ToolPaths(
        target: ToolPlatform.windowsX64,
        bundledDirectory: Directory('${root.path}/included'),
        updatesDirectory: Directory('${root.path}/updates'),
      );
      writeWindowsBundle(paths.bundledDirectory, revision: 1);
      final runner = VersionRunner();
      final good = windowsUpdate(root, revision: 2);
      final installer = ToolBundleInstaller(paths: paths, runner: runner);
      await installer.install(
        good,
        sha256.convert(good.readAsBytesSync()).toString(),
        2,
      );
      final pointer = paths.activeFile.readAsStringSync();
      final bad = windowsUpdate(root, revision: 3, failure: failure);
      runner.fail = failure == 'executable';
      await expectLater(
        installer.install(
          bad,
          sha256.convert(bad.readAsBytesSync()).toString(),
          3,
        ),
        throwsA(anything),
      );
      expect(paths.activeFile.readAsStringSync(), pointer);
      expect(paths.selected!.revision, 2);
      expect(
        paths.updatesDirectory.listSync().where(
          (f) => f.path.contains('.install-'),
        ),
        isEmpty,
      );
    });
  }
}

void writeWindowsBundle(
  Directory directory, {
  required int revision,
  String? failure,
}) {
  directory.createSync(recursive: true);
  final files = <String, String>{};
  for (final name in [
    ...ToolBundle.executables.map((n) => '$n.exe'),
    'licenses/THIRD_PARTY_NOTICES.md',
    'vcruntime140.dll',
  ]) {
    final file = File('${directory.path}/$name');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('test-binary');
    files[name] = sha256.convert(file.readAsBytesSync()).toString();
  }
  if (failure == 'file hash') files['deno.exe'] = '0' * 64;
  File('${directory.path}/manifest.json').writeAsStringSync(
    jsonEncode({
      'schema': 1,
      'platform': failure == 'wrong platform' ? 'linux-x64' : 'windows-x64',
      'revision': revision,
      'files': files,
    }),
  );
}

File windowsUpdate(Directory root, {required int revision, String? failure}) {
  final source = Directory('${root.path}/source-$revision');
  writeWindowsBundle(source, revision: revision, failure: failure);
  final archive = Archive();
  for (final file in source.listSync(recursive: true).whereType<File>()) {
    final name = file.path
        .substring(source.path.length + 1)
        .replaceAll('\\', '/');
    archive.addFile(ArchiveFile.bytes(name, file.readAsBytesSync()));
  }
  if (failure == 'case collision') {
    archive.addFile(ArchiveFile.bytes('DENO.EXE', [1]));
  }
  return File('${root.path}/update-$revision.zip')
    ..writeAsBytesSync(ZipEncoder().encode(archive));
}

class VersionRunner implements CommandRunner {
  final executables = <String>[];
  bool fail = false;

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String, bool)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    executables.add(executable);
    return ProcessRunnerResult(
      exitCode: fail ? 1 : 0,
      stdout: '2026.08.19 ffmpeg version 8.1 ffprobe version 8.1 deno 2.9.7',
      stderr: '',
    );
  }
}
