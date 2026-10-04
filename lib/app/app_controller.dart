import 'dart:io';

import 'package:flutter/material.dart';

import '../core/process/process_runner.dart';
import '../core/services/dependency_checker.dart';
import '../core/services/log_service.dart';
import '../core/utils/path_utils.dart';
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
  });

  final LogService log;
  AppSettings settings;
  final SettingsService settingsService;
  final ProviderRegistry registry;
  final DownloadManager manager;
  final DependencyChecker dependencyChecker;
  final PathUtils pathUtils;

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

    final ytDlp = settings.ytDlpPath.isNotEmpty ? settings.ytDlpPath : 'yt-dlp';
    final ffmpeg =
        settings.ffmpegPath.isNotEmpty ? settings.ffmpegPath : 'ffmpeg';
    final ffprobe =
        settings.ffprobePath.isNotEmpty ? settings.ffprobePath : 'ffprobe';

    final youtubeProvider = YoutubeProvider(
      ytDlpPath: ytDlp,
      ffmpegPath: ffmpeg,
      ffprobePath: ffprobe,
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

    final checker = DependencyChecker(
      runner: runner,
      ytDlpPathOverride:
          settings.ytDlpPath.isNotEmpty ? settings.ytDlpPath : null,
      ffmpegPathOverride:
          settings.ffmpegPath.isNotEmpty ? settings.ffmpegPath : null,
      ffprobePathOverride:
          settings.ffprobePath.isNotEmpty ? settings.ffprobePath : null,
    );

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
    );

    controller._applySettings();
    await controller.refreshDependencies();
    return controller;
  }

  void _applySettings() {
    log.debugEnabled = settings.debugLogging;
    final ytDlp = registry.byId('youtube');
    if (ytDlp is YoutubeProvider) {
      ytDlp.ytDlpPath =
          settings.ytDlpPath.isNotEmpty ? settings.ytDlpPath : 'yt-dlp';
      ytDlp.ffmpegPath =
          settings.ffmpegPath.isNotEmpty ? settings.ffmpegPath : 'ffmpeg';
      ytDlp.ffprobePath =
          settings.ffprobePath.isNotEmpty ? settings.ffprobePath : 'ffprobe';
      ytDlp.setExtraYtDlpArgs(settings.extraYtDlpArgs);
    }
    final direct = registry.byId('direct');
    if (direct is DirectMediaProvider) {
      direct.ffprobePath =
          settings.ffprobePath.isNotEmpty ? settings.ffprobePath : 'ffprobe';
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
