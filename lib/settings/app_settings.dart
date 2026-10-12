import '../core/models/download_options.dart';
import '../providers/format_selector.dart';

/// Serializable application settings.
class AppSettings {
  const AppSettings({
    this.defaultDownloadDirectory = '',
    this.rememberLastDirectory = true,
    this.lastDownloadDirectory = '',
    this.autoStartDownload = false,
    this.defaultVideoQuality = VideoQuality.best,
    this.containerPreference = ContainerPreference.auto,
    this.preferredLanguage = 'ar',
    this.autoSelectBestAudio = true,
    this.fallbackLanguage = '',
    this.ytDlpPath = '',
    this.ffmpegPath = '',
    this.ffprobePath = '',
    this.extraYtDlpArgs = '',
    this.debugLogging = false,
  });

  final String defaultDownloadDirectory;
  final bool rememberLastDirectory;
  final String lastDownloadDirectory;
  final bool autoStartDownload;
  final VideoQuality defaultVideoQuality;
  final ContainerPreference containerPreference;

  /// Preferred audio language code, e.g. `ar`. Fully configurable.
  final String preferredLanguage;

  /// When true, automatically pick the best audio track in the preferred
  /// language instead of asking the user for a specific bitrate.
  final bool autoSelectBestAudio;

  /// Fallback language when the preferred language has no audio track.
  /// Empty string means "None" (never fall back silently).
  final String fallbackLanguage;

  final String ytDlpPath;
  final String ffmpegPath;
  final String ffprobePath;
  final String extraYtDlpArgs;
  final bool debugLogging;

  AppSettings copyWith({
    String? defaultDownloadDirectory,
    bool? rememberLastDirectory,
    String? lastDownloadDirectory,
    bool? autoStartDownload,
    VideoQuality? defaultVideoQuality,
    ContainerPreference? containerPreference,
    String? preferredLanguage,
    bool? autoSelectBestAudio,
    String? fallbackLanguage,
    String? ytDlpPath,
    String? ffmpegPath,
    String? ffprobePath,
    String? extraYtDlpArgs,
    bool? debugLogging,
  }) {
    return AppSettings(
      defaultDownloadDirectory:
          defaultDownloadDirectory ?? this.defaultDownloadDirectory,
      rememberLastDirectory: rememberLastDirectory ?? this.rememberLastDirectory,
      lastDownloadDirectory:
          lastDownloadDirectory ?? this.lastDownloadDirectory,
      autoStartDownload: autoStartDownload ?? this.autoStartDownload,
      defaultVideoQuality: defaultVideoQuality ?? this.defaultVideoQuality,
      containerPreference: containerPreference ?? this.containerPreference,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      autoSelectBestAudio: autoSelectBestAudio ?? this.autoSelectBestAudio,
      fallbackLanguage: fallbackLanguage ?? this.fallbackLanguage,
      ytDlpPath: ytDlpPath ?? this.ytDlpPath,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      ffprobePath: ffprobePath ?? this.ffprobePath,
      extraYtDlpArgs: extraYtDlpArgs ?? this.extraYtDlpArgs,
      debugLogging: debugLogging ?? this.debugLogging,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultDownloadDirectory': defaultDownloadDirectory,
        'rememberLastDirectory': rememberLastDirectory,
        'lastDownloadDirectory': lastDownloadDirectory,
        'autoStartDownload': autoStartDownload,
        'defaultVideoQuality': defaultVideoQuality.name,
        'containerPreference': containerPreference.name,
        'preferredLanguage': preferredLanguage,
        'autoSelectBestAudio': autoSelectBestAudio,
        'fallbackLanguage': fallbackLanguage,
        'ytDlpPath': ytDlpPath,
        'ffmpegPath': ffmpegPath,
        'ffprobePath': ffprobePath,
        'extraYtDlpArgs': extraYtDlpArgs,
        'debugLogging': debugLogging,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      defaultDownloadDirectory:
          json['defaultDownloadDirectory'] as String? ?? '',
      rememberLastDirectory:
          json['rememberLastDirectory'] as bool? ?? true,
      lastDownloadDirectory: json['lastDownloadDirectory'] as String? ?? '',
      autoStartDownload: json['autoStartDownload'] as bool? ?? false,
      defaultVideoQuality: VideoQuality.values.firstWhere(
        (v) => v.name == json['defaultVideoQuality'],
        orElse: () => VideoQuality.best,
      ),
      containerPreference: ContainerPreference.values.firstWhere(
        (v) => v.name == json['containerPreference'],
        orElse: () => ContainerPreference.auto,
      ),
      preferredLanguage: json['preferredLanguage'] as String? ?? 'ar',
      autoSelectBestAudio: json['autoSelectBestAudio'] as bool? ?? true,
      fallbackLanguage: json['fallbackLanguage'] as String? ?? '',
      ytDlpPath: json['ytDlpPath'] as String? ?? '',
      ffmpegPath: json['ffmpegPath'] as String? ?? '',
      ffprobePath: json['ffprobePath'] as String? ?? '',
      extraYtDlpArgs: json['extraYtDlpArgs'] as String? ?? '',
      debugLogging: json['debugLogging'] as bool? ?? false,
    );
  }
}
