import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/models/video_format.dart';
import '../../providers/downloader_provider.dart';
import '../../providers/format_selector.dart';
import 'home_input.dart';

class HomeVideoDraft {
  HomeVideoDraft({
    required this.info,
    required this.provider,
    required String preferredLanguage,
    required String outputDirectory,
    required ContainerPreference containerPreference,
  }) {
    final languages = info.audioLanguages;
    input.selectAudioLanguage(
      info.hasAudioForLanguage(preferredLanguage)
          ? preferredLanguage
          : languages.firstOrNull,
    );
    input.selectOutputDirectory(outputDirectory);
    input.selectContainer(containerPreference);
    _defaults = _configuration;
  }

  static int _sequence = 0;
  final String id =
      'task_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
  final MediaInfo info;
  final DownloaderProvider provider;
  final HomeInput input = HomeInput();
  String? errorMessage;

  late final Object _defaults;

  Object get _configuration => (
    input.videoHeight,
    input.audioLanguage,
    input.autoBestAudio,
    input.audioBitrate,
    input.containerPreference,
    input.outputDirectory,
    input.subtitle,
    input.downloadSubtitleFile,
    input.keepSpeech,
    input.keepMusic,
    input.keepEffects,
    input.speechRemovalStrength,
    input.musicRemovalStrength,
    input.effectsRemovalStrength,
  );

  bool get isCustom => _configuration != _defaults;

  VideoFormat? get selectedVideo => const FormatSelector().selectBestVideo(
    info.videoFormats,
    maxHeight: input.videoHeight,
  );

  String get qualityLabel {
    final video = selectedVideo;
    if (video == null) return 'No video available';
    return video.resolutionLabel == 'unknown' ? 'Best' : video.resolutionLabel;
  }
}
