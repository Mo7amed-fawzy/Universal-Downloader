import 'package:flutter/material.dart';

import '../core/services/dependency_checker.dart';
import '../core/services/log_service.dart';
import '../core/utils/path_utils.dart';
import '../downloads/download_manager.dart';
import '../downloads/download_repository.dart';
import '../platform/download_platform.dart';
import '../platform/download_platform_factory.dart';
import '../providers/default_provider_factories.dart';
import '../providers/provider_dependencies.dart';
import '../providers/provider_factory.dart';
import '../providers/provider_registry.dart';
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
    required this.platform,
  });

  final LogService log;
  AppSettings settings;
  final SettingsService settingsService;
  final ProviderRegistry registry;
  final DownloadManager manager;
  final DownloadPlatform platform;
  PathUtils get pathUtils => platform.paths;
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
  static Future<AppController> create({
    DownloadPlatform? platform,
    Iterable<ProviderFactory> providerFactories = defaultProviderFactories,
  }) async {
    final selectedPlatform =
        platform ?? await const DownloadPlatformFactory().create();
    final settingsService = SettingsService();
    final settings = await settingsService.load();
    final log = LogService(
      paths: selectedPlatform.paths,
      debugEnabled: settings.debugLogging,
    );
    final repository = DownloadRepository(paths: selectedPlatform.paths);
    final registry = ProviderRegistry.fromFactories(
      factories: providerFactories,
      dependencies: ProviderDependencies(
        runner: selectedPlatform.runner,
        repository: repository,
        log: log,
        tools: selectedPlatform.resolveTools(settings),
      ),
    );
    final manager = DownloadManager(
      registry: registry,
      repository: repository,
      log: log,
      publishDownload: (result, cancelToken) =>
          selectedPlatform.publishDownload(result, cancelToken: cancelToken),
    );
    final controller = AppController._(
      log: log,
      settings: settings,
      settingsService: settingsService,
      registry: registry,
      manager: manager,
      platform: selectedPlatform,
    );
    await controller.refreshDependencies();
    return controller;
  }

  void _applySettings() {
    log.debugEnabled = settings.debugLogging;
    registry.configureTools(platform.resolveTools(settings));
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
      dependencies = await platform.checkTools(settings);
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
        await platform.useIncludedTools();
        settings = settings.copyWith(
          ytDlpPath: '',
          ffmpegPath: '',
          ffprobePath: '',
        );
        await settingsService.save(settings);
        toolUpdateMessage = 'Using the tools included with the app.';
      } else {
        toolUpdateMessage = await platform.updateTools(
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
  String resolveOutputDirectory() => platform.resolveOutputDirectory(settings);

  String defaultDownloadDirectory() => platform.defaultDownloadDirectory();

  Future<void> openDownload(String location) => platform.openDownload(location);
}
