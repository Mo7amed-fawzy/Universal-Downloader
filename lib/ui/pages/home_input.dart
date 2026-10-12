import '../../core/models/download_options.dart';
import '../../core/models/subtitle_track.dart';
import '../../core/models/video_format.dart';
import '../../providers/format_selector.dart';

class HomeInput {
  int? videoHeight;
  String? audioLanguage;
  bool autoBestAudio = true;
  int? audioBitrate;
  ContainerPreference containerPreference = ContainerPreference.auto;
  String outputDirectory = '';
  SubtitleTrack? subtitle;
  bool downloadSubtitleFile = false;

  SubtitleTrack? get subtitleToDownload =>
      downloadSubtitleFile ? subtitle : null;

  void selectVideoHeight(int? value) => videoHeight = value;

  void resetVideoQuality(List<VideoFormat> formats, VideoQuality preference) {
    videoHeight = preference == VideoQuality.best
        ? null
        : const FormatSelector()
              .selectBestVideo(formats, quality: preference)
              ?.height;
  }

  void selectAudioLanguage(String? value) {
    audioLanguage = value;
    audioBitrate = null;
    autoBestAudio = true;
  }

  void selectAutoBestAudio(bool value) {
    autoBestAudio = value;
    if (value) audioBitrate = null;
  }

  void selectAudioBitrate(int? value) {
    audioBitrate = value;
    autoBestAudio = value == null;
  }

  void selectContainer(ContainerPreference value) =>
      containerPreference = value;

  void selectOutputDirectory(String value) => outputDirectory = value;

  void selectSubtitle(SubtitleTrack? value) {
    subtitle = value;
    if (value == null) downloadSubtitleFile = false;
  }

  void selectDownloadSubtitleFile(bool value) =>
      downloadSubtitleFile = value && subtitle != null;
}
