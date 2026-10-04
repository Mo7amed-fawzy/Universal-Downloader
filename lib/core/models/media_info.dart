import 'audio_format.dart';
import 'subtitle_track.dart';
import 'video_format.dart';

/// Metadata about a piece of media (video, audio, or a combined stream)
/// that a [DownloaderProvider] was able to extract from a URL.
class MediaInfo {
  const MediaInfo({
    required this.id,
    required this.title,
    required this.providerId,
    required this.providerName,
    required this.pageUrl,
    this.thumbnail,
    this.duration,
    this.uploader,
    this.description,
    this.videoFormats = const [],
    this.audioFormats = const [],
    this.subtitleTracks = const [],
  });

  /// Provider-unique identifier (e.g. a YouTube video id).
  final String id;

  final String title;

  /// Id of the [DownloaderProvider] that produced this info.
  final String providerId;

  final String providerName;

  /// Original URL the user pasted.
  final Uri pageUrl;

  final Uri? thumbnail;

  final Duration? duration;

  final String? uploader;

  final String? description;

  final List<VideoFormat> videoFormats;

  final List<AudioFormat> audioFormats;

  final List<SubtitleTrack> subtitleTracks;

  /// All languages that have an audio-only track, ordered by preference.
  /// Distinct base codes only (e.g. `ar` and `ar-EG` collapse to `ar`).
  List<String> get audioLanguages {
    final seen = <String>{};
    final result = <String>[];
    for (final f in audioFormats) {
      final lang = f.language;
      if (lang == null || lang.isEmpty) continue;
      final base = lang.split('-').first.toLowerCase();
      if (seen.add(base)) result.add(base);
    }
    return result;
  }

  /// True if any audio-only format exists for [languageCode]
  /// (language code, e.g. `ar` or `en`).
  bool hasAudioForLanguage(String languageCode) {
    return audioFormats.any(
      (f) => f.languageMatches(languageCode),
    );
  }

  VideoFormat? videoFormatById(String formatId) {
    for (final f in videoFormats) {
      if (f.formatId == formatId) return f;
    }
    return null;
  }

  AudioFormat? audioFormatById(String formatId) {
    for (final f in audioFormats) {
      if (f.formatId == formatId) return f;
    }
    return null;
  }
}
