import '../../core/models/download_options.dart';
import '../../core/models/subtitle_track.dart';
import '../../providers/format_selector.dart';

class HomeInput {
  VideoQuality videoQuality = VideoQuality.best;
  String? audioLanguage;
  bool autoBestAudio = true;
  int? audioBitrate;
  ContainerPreference containerPreference = ContainerPreference.auto;
  String outputDirectory = '';
  SubtitleTrack? subtitle;

  void selectVideoQuality(VideoQuality value) => videoQuality = value;

  void selectAudioLanguage(String? value) {
    audioLanguage = value;
    audioBitrate = null;
  }

  void selectAutoBestAudio(bool value) => autoBestAudio = value;

  void selectAudioBitrate(int? value) => audioBitrate = value;

  void selectContainer(ContainerPreference value) =>
      containerPreference = value;

  void selectOutputDirectory(String value) => outputDirectory = value;

  void selectSubtitle(SubtitleTrack? value) => subtitle = value;
}
