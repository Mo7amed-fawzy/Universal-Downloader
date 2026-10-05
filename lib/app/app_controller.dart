import 'dart:io';

import 'package:flutter/material.dart';

import '../core/process/process_runner.dart';
import '../core/services/dependency_checker.dart';
import '../core/services/log_service.dart';
import '../core/utils/path_utils.dart';
import '../core/tools/tool_paths.dart';
import '../core/tools/tool_update_service.dart';
import '../downloads/download_manager.dart';
import '../downloads/download_repository.dart';
import '../providers/direct/direct_media_provider.dart';
import '../providers/provider_registry.dart';
import '../providers/youtube/youtube_provider.dart';
import '../settings/app_settings.dart';
import '../settings/settings_service.dart';

/// Composition root. Wires all services together and exposes them to the UI
/// through a single [ChangeNotifier].
class AppController extends ChangeNotifier {
  AppController._({
    required this.log,
    required this.settings,
    required this.settingsService,
    required this.registry,
    required this.manager,
    required this.dependencyChecker,
    required this.pathUtils,
    required this.toolPaths,
  });

  final LogService log;
  AppSettings settings;
  final SettingsService settingsService;
  final ProviderRegistry registry;
  final DownloadManager manager;
  final DependencyChecker dependencyChecker;
  final PathUtils pathUtils;
  final ToolPaths toolPaths;
  bool updatingTools = false;
  String? toolUpdateMessage;

  List<DependencyStatus> dependencies = const [];
  bool checkingDependencies = false;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// Builds the full application dependency graph.
  static Future<AppController> create() async {
    final log = LogService();
    final settingsService = SettingsService();
    final settings = await settingsService.load();
    log.debugEnabled = settings.debugLogging;

    final pathUtils = const PathUtils();
    final repository = DownloadRepository(paths: pathUtils);
    final runner = const ProcessRunner();

    final toolPaths = ToolPaths();
    final ytDlp = toolPaths.resolve('yt-dlp', override: settings.ytDlpPath);
    final ffmpeg = toolPaths.resolve('ffmpeg', override: settings.ffmpegPath);
    final ffprobe = toolPaths.resolve(
      'ffprobe',
      override: settings.ffprobePath,
    );

    final youtubeProvider = YoutubeProvider(
      ytDlpPath: ytDlp,
      ffmpegPath: ffmpeg,
      ffprobePath: ffprobe,
      denoPath: toolPaths.resolve('deno'),
      runner: runner,
      repository: repository,
      log: log,
    );
    final directProvider = DirectMediaProvider(
      ffprobePath: ffprobe,
      runner: runner,
      repository: repository,
      log: log,
    );

    final registry = ProviderRegistry([youtubeProvider, directProvider]);

    final checker = DependencyChecker(runner: runner);

    final manager = DownloadManager(
      registry: registry,
      repository: repository,
      log: log,
    );

    final controller = AppController._(
      log: log,
      settings: settings,
      settingsService: settingsService,
      registry: registry,
      manager: manager,
      dependencyChecker: checker,
      pathUtils: pathUtils,
      toolPaths: toolPaths,
    );

    controller._applySettings();
    await controller.refreshDependencies();
    return controller;
  }

  void _applySettings() {
    log.debugEnabled = settings.debugLogging;
    dependencyChecker.ytDlpPathOverride = toolPaths.resolve(
      'yt-dlp',
      override: settings.ytDlpPath,
    );
    dependencyChecker.ffmpegPathOverride = toolPaths.resolve(
      'ffmpeg',
      override: settings.ffmpegPath,
    );
    dependencyChecker.ffprobePathOverride = toolPaths.resolve(
      'ffprobe',
      override: settings.ffprobePath,
    );
    dependencyChecker.denoPathOverride = toolPaths.resolve('deno');
    final ytDlp = registry.byId('youtube');
    if (ytDlp is YoutubeProvider) {
      ytDlp.ytDlpPath = toolPaths.resolve(
        'yt-dlp',
        override: settings.ytDlpPath,
      );
      ytDlp.ffmpegPath = toolPaths.resolve(
        'ffmpeg',
        override: settings.ffmpegPath,
      );
      ytDlp.ffprobePath = toolPaths.resolve(
        'ffprobe',
        override: settings.ffprobePath,
      );
      ytDlp.denoPath = toolPaths.resolve('deno');
      ytDlp.setExtraYtDlpArgs(settings.extraYtDlpArgs);
    }
    final direct = registry.byId('direct');
    if (direct is DirectMediaProvider) {
      direct.ffprobePath = toolPaths.resolve(
        'ffprobe',
        override: settings.ffprobePath,
      );
    }
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await settingsService.save(next);
    _applySettings();
    notifyListeners();
    await refreshDependencies();
  }

  /// Updates only the "last used" download directory.
  Future<void> rememberDirectory(String path) async {
    settings = settings.copyWith(lastDownloadDirectory: path);
    await settingsService.save(settings);
    notifyListeners();
  }

  Future<void> refreshDependencies() async {
    checkingDependencies = true;
    notifyListeners();
    try {
      dependencies = await dependencyChecker.checkAll();
    } finally {
      checkingDependencies = false;
      notifyListeners();
    }
  }

  Future<void> updateTools({bool restoreIncluded = false}) async {
    if (updatingTools) return;
    if (manager.tasks.any((task) => task.state.isActive)) {
      toolUpdateMessage =
          'Finish or cancel queued downloads before changing tools.';
      notifyListeners();
      return;
    }
    updatingTools = true;
    toolUpdateMessage = restoreIncluded
        ? 'Restoring included tools…'
        : 'Checking for updates…';
    notifyListeners();
    try {
      if (restoreIncluded) {
        await toolPaths.useIncluded();
        settings = settings.copyWith(
          ytDlpPath: '',
          ffmpegPath: '',
          ffprobePath: '',
        );
        await settingsService.save(settings);
        toolUpdateMessage = 'Using the tools included with the app.';
      } else {
        toolUpdateMessage = await ToolUpdateService(toolPaths).update(
          onStatus: (message) {
            toolUpdateMessage = message;
            notifyListeners();
          },
        );
      }
      _applySettings();
      await refreshDependencies();
    } catch (error) {
      toolUpdateMessage =
          'Could not update tools. Your current tools were kept. $error';
    } finally {
      updatingTools = false;
      notifyListeners();
    }
  }

  /// Resolves the output directory for new downloads.
  String resolveOutputDirectory() {
    if (settings.rememberLastDirectory &&
        settings.lastDownloadDirectory.isNotEmpty) {
      return settings.lastDownloadDirectory;
    }
    if (settings.defaultDownloadDirectory.isNotEmpty) {
      return settings.defaultDownloadDirectory;
    }
    return defaultDownloadDirectory();
  }

  String defaultDownloadDirectory() {
    final home = Platform.environment['HOME'] ?? '';
    final videos = '$home/Videos';
    return Directory(videos).existsSync() ? videos : '$home/Downloads';
  }
}
