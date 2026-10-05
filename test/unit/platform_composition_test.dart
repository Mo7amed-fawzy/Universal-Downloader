import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_downloader/app/app_controller.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/command_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/core/services/dependency_checker.dart';
import 'package:universal_downloader/core/tools/media_tools.dart';
import 'package:universal_downloader/core/utils/path_utils.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/platform/download_platform.dart';
import 'package:universal_downloader/platform/download_platform_factory.dart';
import 'package:universal_downloader/platform/linux/linux_download_platform.dart';
import 'package:universal_downloader/platform/operating_system.dart';
import 'package:universal_downloader/providers/default_provider_factories.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';
import 'package:universal_downloader/providers/provider_dependencies.dart';
import 'package:universal_downloader/providers/provider_factory.dart';
import 'package:universal_downloader/providers/provider_registry.dart';
import 'package:universal_downloader/providers/tool_configurable_provider.dart';
import 'package:universal_downloader/settings/app_settings.dart';

import '../support/controlled_download_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'detects Android separately from Linux and rejects unimplemented OS',
    () async {
      const factory = DownloadPlatformFactory();
      for (final entry in {
        'linux': OperatingSystem.linux,
        'android': OperatingSystem.android,
        'windows': OperatingSystem.windows,
        'macos': OperatingSystem.macos,
        'ios': OperatingSystem.ios,
        'unknown': OperatingSystem.unsupported,
      }.entries) {
        expect(OperatingSystem.fromPlatformName(entry.key), entry.value);
      }
      expect(
        OperatingSystem.detect(),
        OperatingSystem.fromPlatformName(Platform.operatingSystem),
      );
      expect(
        await factory.create(operatingSystem: OperatingSystem.linux),
        isA<LinuxDownloadPlatform>(),
      );
      for (final os in OperatingSystem.values.where(
        (os) => os != OperatingSystem.linux && os != OperatingSystem.android,
      )) {
        expect(factory.create(operatingSystem: os), throwsUnsupportedError);
      }
    },
  );

  test('Linux retains executable overrides and bundled runtime arguments', () {
    final platform = LinuxDownloadPlatform();
    final tools = platform.resolveTools(
      const AppSettings(
        ytDlpPath: '/custom/yt-dlp',
        ffmpegPath: '/custom/ffmpeg',
        ffprobePath: '/custom/ffprobe',
        extraYtDlpArgs: '--socket-timeout 15',
      ),
    );
    expect(tools.ytDlp, '/custom/yt-dlp');
    expect(tools.ffmpeg, '/custom/ffmpeg');
    expect(tools.ffprobe, '/custom/ffprobe');
    expect(tools.ytDlpArguments, contains('--no-remote-components'));
    expect(tools.ytDlpArguments, contains(startsWith('deno:')));
    expect(
      tools.ytDlpArguments,
      containsAllInOrder([
        '--ffmpeg-location',
        '/custom/ffmpeg',
        '--socket-timeout',
        '15',
      ]),
    );
    expect(
      platform.resolveOutputDirectory(
        const AppSettings(
          lastDownloadDirectory: '/last',
          defaultDownloadDirectory: '/default',
          rememberLastDirectory: true,
        ),
      ),
      '/last',
    );
    expect(
      platform.resolveOutputDirectory(
        const AppSettings(
          lastDownloadDirectory: '/last',
          defaultDownloadDirectory: '/default',
          rememberLastDirectory: false,
        ),
      ),
      '/default',
    );
  });

  group('platform and provider composition', () {
    late Directory root;
    late TestDownloadPlatform platform;
    late AppController controller;
    late TestProviderFactory extraFactory;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      root = Directory.systemTemp.createTempSync('platform_composition_');
      platform = TestDownloadPlatform(QueueTestPaths(root));
      extraFactory = TestProviderFactory();
      controller = await AppController.create(
        platform: platform,
        providerFactories: [...defaultProviderFactories, extraFactory],
      );
    });

    tearDown(() {
      controller.manager.dispose();
      controller.dispose();
      root.deleteSync(recursive: true);
    });

    test('adding a provider injects the selected platform dependencies', () {
      expect(extraFactory.dependencies.runner, same(platform.runner));
      expect(controller.pathUtils, same(platform.paths));
      expect(
        controller.registry.byId('additional'),
        same(extraFactory.provider),
      );
      expect(
        controller.registry.resolve(Uri.parse('https://new.example/watch')),
        same(extraFactory.provider),
      );
      expect(controller.resolveOutputDirectory(), root.path);
      expect(platform.checkCount, 1);
    });

    test(
      'YouTube uses the injected runner and keeps quality and languages',
      () async {
        final youtube = controller.registry.byId('youtube')!;
        final media = await youtube.fetchInfo(
          Uri.parse('https://youtu.be/test'),
        );
        expect(media.videoFormats.single.height, 720);
        expect(media.audioLanguages, containsAll(['ar', 'en']));
        expect(platform.runner.calls, hasLength(2));
        for (final call in platform.runner.calls) {
          expect(call.executable, 'native/yt-dlp-1');
          expect(call.arguments, contains('quickjs:native/qjs'));
          expect(
            call.arguments.where((arg) => arg.startsWith('deno:')),
            isEmpty,
          );
        }
      },
    );

    test(
      'direct downloads verify through the injected command runner',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          request.response.add([1, 2, 3, 4]);
          await request.response.close();
        });
        addTearDown(() async {
          await server.close(force: true);
          await subscription.cancel();
        });
        final direct = controller.registry.byId('direct')!;
        final url = Uri.parse('http://127.0.0.1:${server.port}/video.mp4');
        final media = await direct.fetchInfo(url);
        final result = await direct.download(
          media,
          DownloadOptions(
            taskId: 'direct-test',
            outputDirectory: root.path,
            title: 'Direct',
            videoFormatId: 'direct',
          ),
          onPhase: (_) {},
          onProgress: (_) {},
          cancelToken: CancelToken(),
        );
        expect(await result.outputFile.readAsBytes(), [1, 2, 3, 4]);
        expect(platform.runner.calls.single.executable, 'native/ffprobe');
        expect(
          platform.runner.calls.single.arguments,
          contains('-show_streams'),
        );
      }, LocalHttpOverrides()),
    );

    test('settings and tool updates reconfigure existing providers', () async {
      final youtube = controller.registry.byId('youtube')!;
      await controller.updateSettings(
        controller.settings.copyWith(ytDlpPath: 'custom/yt-dlp'),
      );
      expect(extraFactory.provider.tools!.ytDlp, 'custom/yt-dlp');
      await youtube.fetchInfo(Uri.parse('https://youtu.be/test'));
      expect(platform.runner.calls.first.executable, 'custom/yt-dlp');
      await controller.updateTools(restoreIncluded: true);
      expect(controller.settings.ytDlpPath, isEmpty);
      expect(platform.restoreCount, 1);
      await controller.updateTools();
      expect(controller.registry.byId('youtube'), same(youtube));
      expect(extraFactory.provider.tools!.ytDlp, 'native/yt-dlp-2');
      expect(controller.toolUpdateMessage, 'Updated test tools');
      platform.runner.calls.clear();
      await youtube.fetchInfo(Uri.parse('https://youtu.be/test'));
      expect(platform.runner.calls.first.executable, 'native/yt-dlp-2');
    });

    test(
      'queue completes only after publishing and keeps a content URI',
      () async {
        addTestDownload(controller, extraFactory.provider, root);
        extraFactory.provider.calls.single.complete(
          DownloadTaskResult(
            outputFile: File('${root.path}/finished.mp4'),
            merged: true,
          ),
        );
        await pumpEventQueue();
        expect(
          controller.manager.tasks.single.state,
          isNot(DownloadTaskState.completed),
        );
        expect(controller.manager.activeCount, 1);
        expect(
          platform.publicationToken,
          same(controller.manager.tasks.single.cancelToken),
        );
        platform.publication.complete('content://downloads/42');
        await pumpEventQueue();
        final task = controller.manager.tasks.single;
        expect(task.state, DownloadTaskState.completed);
        expect(task.outputPath, 'content://downloads/42');
        expect(controller.manager.activeCount, 0);
        await controller.openDownload(task.outputPath!);
        expect(platform.openedLocation, 'content://downloads/42');
      },
    );

    for (final cancelled in [false, true]) {
      test(
        'publication failure/cancellation is not reported as success ($cancelled)',
        () async {
          addTestDownload(controller, extraFactory.provider, root);
          extraFactory.provider.calls.single.complete(
            DownloadTaskResult(
              outputFile: File('${root.path}/finished.mp4'),
              merged: true,
            ),
          );
          await pumpEventQueue();
          if (cancelled) controller.manager.cancel('test');
          platform.publication.completeError(
            cancelled
                ? DownloadCancelledException()
                : FilesystemException('Cannot publish'),
          );
          await pumpEventQueue();
          expect(
            controller.manager.tasks.single.state,
            cancelled ? DownloadTaskState.cancelled : DownloadTaskState.failed,
          );
          expect(controller.manager.tasks.single.outputPath, isNull);
          expect(controller.manager.activeCount, 0);
        },
      );
    }

    test(
      'registry rejects duplicate IDs and cannot be modified accidentally',
      () {
        final provider = extraFactory.provider;
        expect(
          () => ProviderRegistry([provider, provider]),
          throwsArgumentError,
        );
        final input = <DownloaderProvider>[provider];
        final registry = ProviderRegistry(input);
        input.clear();
        expect(registry.byId('additional'), same(provider));
        expect(() => registry.providers.clear(), throwsUnsupportedError);
      },
    );
  });
}

void addTestDownload(
  AppController controller,
  DownloaderProvider provider,
  Directory root,
) {
  controller.manager.add(
    provider: provider,
    media: MediaInfo(
      id: 'test',
      title: 'Test',
      providerId: provider.id,
      providerName: provider.displayName,
      pageUrl: Uri.parse('https://new.example/watch'),
    ),
    options: DownloadOptions(
      taskId: 'test',
      outputDirectory: root.path,
      title: 'Test',
      videoFormatId: 'video',
    ),
    videoLabel: '720p',
    audioLabel: 'Arabic',
  );
}

class TestProvider extends ControlledDownloadProvider
    implements ToolConfigurableProvider {
  @override
  String get id => 'additional';
  MediaTools? tools;
  @override
  bool canHandle(Uri url) => url.host == 'new.example';
  @override
  void configureTools(MediaTools tools) => this.tools = tools;
}

class TestProviderFactory implements ProviderFactory {
  final provider = TestProvider();
  late ProviderDependencies dependencies;
  @override
  DownloaderProvider create(ProviderDependencies dependencies) {
    this.dependencies = dependencies;
    return provider..configureTools(dependencies.tools);
  }
}

class TestDownloadPlatform implements DownloadPlatform {
  TestDownloadPlatform(this.paths);
  @override
  OperatingSystem get operatingSystem => OperatingSystem.android;
  @override
  final MetadataRunner runner = MetadataRunner();
  @override
  final PathUtils paths;
  int checkCount = 0;
  int restoreCount = 0;
  int revision = 1;
  String? openedLocation;
  CancelToken? publicationToken;
  final publication = Completer<String>();

  @override
  MediaTools resolveTools(AppSettings settings) => MediaTools(
    ytDlp: settings.ytDlpPath.isEmpty
        ? 'native/yt-dlp-$revision'
        : settings.ytDlpPath,
    ffmpeg: 'native/ffmpeg',
    ffprobe: 'native/ffprobe',
    ytDlpArguments: ['--js-runtimes', 'quickjs:native/qjs'],
  );
  @override
  Future<List<DependencyStatus>> checkTools(AppSettings settings) async {
    checkCount++;
    return const [DependencyStatus(name: 'test', installed: true)];
  }

  @override
  String defaultDownloadDirectory() => paths.appDataDirectory().path;
  @override
  String resolveOutputDirectory(AppSettings settings) =>
      defaultDownloadDirectory();
  @override
  Future<void> openDownload(String location) async => openedLocation = location;
  @override
  Future<String> publishDownload(
    DownloadTaskResult result, {
    required CancelToken cancelToken,
  }) {
    publicationToken = cancelToken;
    return publication.future;
  }

  @override
  Future<String> updateTools({required void Function(String) onStatus}) async {
    onStatus('Updating test tools');
    revision++;
    return 'Updated test tools';
  }

  @override
  Future<void> useIncludedTools() async {
    restoreCount++;
  }
}

class MetadataRunner implements CommandRunner {
  final calls = <({String executable, List<String> arguments})>[];
  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String, bool)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    calls.add((executable: executable, arguments: arguments));
    if (arguments.contains('-show_streams')) {
      return ProcessRunnerResult(
        exitCode: 0,
        stderr: '',
        stdout: jsonEncode({
          'streams': [
            {'codec_type': 'video'},
            {'codec_type': 'audio'},
          ],
          'format': {'size': 4},
        }),
      );
    }

    return ProcessRunnerResult(
      exitCode: 0,
      stdout: arguments.contains('--dump-single-json')
          ? jsonEncode({
              'id': 'test',
              'title': 'Test',
              'formats': [
                {
                  'format_id': 'video',
                  'vcodec': 'h264',
                  'acodec': 'none',
                  'height': 720,
                },
                for (final language in ['ar', 'en'])
                  {
                    'format_id': 'audio-$language',
                    'vcodec': 'none',
                    'acodec': 'aac',
                    'language': language,
                  },
              ],
            })
          : '',
      stderr: '',
    );
  }
}

class LocalHttpOverrides extends HttpOverrides {}
