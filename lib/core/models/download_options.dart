import 'subtitle_track.dart';

/// Options that drive a single download operation.
///
/// The concrete video/audio formats are selected by the `FormatSelector`
/// before a download starts; the provider only receives the format ids.
class DownloadOptions {
  const DownloadOptions({
    required this.taskId,
    required this.outputDirectory,
    required this.title,
    required this.videoFormatId,
    this.audioFormatId,
    this.audioLanguage,
    this.subtitle,
    this.overwrite = false,
    this.containerPreference = ContainerPreference.auto,
  });

  /// Unique id used for temporary working directories.
  final String taskId;

  /// Absolute path of the directory where the final file is written.
  final String outputDirectory;

  /// Sanitized base filename without extension.
  final String title;

  final String videoFormatId;

  /// When null the video stream carries the required audio and no merge
  /// happens (combined stream).
  final String? audioFormatId;

  /// Language code the selected audio track should carry (used for
  /// verification, e.g. `ar`). Null disables language verification.
  final String? audioLanguage;

  final SubtitleTrack? subtitle;

  final bool overwrite;

  final ContainerPreference containerPreference;
}

enum ContainerPreference { auto, mp4, mkv }

extension ContainerPreferenceX on ContainerPreference {
  String get label {
    switch (this) {
      case ContainerPreference.auto:
        return 'Auto';
      case ContainerPreference.mp4:
        return 'MP4';
      case ContainerPreference.mkv:
        return 'MKV';
    }
  }
}
