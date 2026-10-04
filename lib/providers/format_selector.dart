import '../core/models/audio_format.dart';
import '../core/models/video_format.dart';

/// Preferred video quality for the UI.
enum VideoQuality {
  best,
  q2160,
  q1440,
  q1080,
  q720,
  q480,
  q360;

  int? get maxHeight {
    switch (this) {
      case VideoQuality.best:
        return null;
      case VideoQuality.q2160:
        return 2160;
      case VideoQuality.q1440:
        return 1440;
      case VideoQuality.q1080:
        return 1080;
      case VideoQuality.q720:
        return 720;
      case VideoQuality.q480:
        return 480;
      case VideoQuality.q360:
        return 360;
    }
  }

  String get label {
    switch (this) {
      case VideoQuality.best:
        return 'Best available';
      case VideoQuality.q2160:
        return '2160p (4K)';
      case VideoQuality.q1440:
        return '1440p (2K)';
      case VideoQuality.q1080:
        return '1080p (Full HD)';
      case VideoQuality.q720:
        return '720p (HD)';
      case VideoQuality.q480:
        return '480p';
      case VideoQuality.q360:
        return '360p';
    }
  }
}

/// Pure, UI-free format selection logic.
///
/// Selection always inspects real format metadata (resolution, fps, bitrate,
/// sample rate, codec, language); format ids are never hardcoded.
class FormatSelector {
  const FormatSelector();

  /// Selects the best video format for [quality].
  ///
  /// * For `best`: the highest-quality video-only (DASH) stream, falling back
  ///   to progressive streams.
  /// * For a capped quality: the best stream at or below the requested height;
  ///   if nothing is that tall, the lowest available is returned.
  ///
  /// Prefers streams without embedded audio so a separate, higher-quality
  /// audio track (e.g. Arabic) can be merged in without quality loss.
  VideoFormat? selectBestVideo(
    List<VideoFormat> formats, {
    VideoQuality quality = VideoQuality.best,
  }) {
    final video = formats
        .where((f) => f.width != null && f.height != null && f.height! > 0)
        .toList();
    if (video.isEmpty) return null;

    final capped = <VideoFormat>[];
    final maxHeight = quality.maxHeight;
    if (maxHeight != null) {
      capped.addAll(video.where((f) => f.height! <= maxHeight));
    }

    final candidates = capped.isNotEmpty
        ? capped
        : (maxHeight == null ? video : _lowestAvailable(video));

    // Prefer video-only streams (DASH) for the highest quality source.
    final videoOnly = candidates.where((f) => f.videoOnly).toList();
    final progressive = candidates.where((f) => f.hasAudio).toList();
    final pool = videoOnly.isNotEmpty
        ? videoOnly
        : (progressive.isNotEmpty ? progressive : candidates);

    pool.sort((a, b) => b.qualityRank.compareTo(a.qualityRank));
    return pool.first;
  }

  List<VideoFormat> _lowestAvailable(List<VideoFormat> formats) {
    final copy = List<VideoFormat>.of(formats);
    copy.sort((a, b) => a.height!.compareTo(b.height!));
    return [copy.first];
  }

  /// Selects the best audio-only format for [preferredLanguage].
  ///
  /// Ranking per spec:
  ///   1. language match (base code, e.g. `ar` matches `ar-EG`)
  ///   2. audio-only preference (audioFormats are already audio-only)
  ///   3. bitrate
  ///   4. sample rate
  ///   5. codec quality
  ///   6. container compatibility
  ///
  /// When no format matches [preferredLanguage] and [fallbackLanguage] is
  /// provided, the fallback language is tried. When nothing matches and
  /// [allowOtherLanguages] is false (default), returns null so callers never
  /// silently download a different language.
  AudioFormat? selectBestAudio(
    List<AudioFormat> formats, {
    required String preferredLanguage,
    String? fallbackLanguage,
    bool allowOtherLanguages = false,
  }) {
    if (formats.isEmpty) return null;

    var matching = _matching(formats, preferredLanguage);
    if (matching.isEmpty &&
        fallbackLanguage != null &&
        fallbackLanguage.isNotEmpty) {
      matching = _matching(formats, fallbackLanguage);
    }
    if (matching.isEmpty) {
      if (allowOtherLanguages) return _bestOf(formats);
      return null;
    }
    return _bestOf(matching);
  }

  /// All audio formats available in [languageCode].
  List<AudioFormat> audioForLanguage(
    List<AudioFormat> formats,
    String languageCode,
  ) {
    return _matching(formats, languageCode);
  }

  List<AudioFormat> _matching(
    List<AudioFormat> formats,
    String languageCode,
  ) {
    return formats
        .where((f) => f.language != null && f.languageMatches(languageCode))
        .toList();
  }

  AudioFormat _bestOf(List<AudioFormat> formats) {
    final copy = List<AudioFormat>.of(formats);
    copy.sort((a, b) {
      final byBitrate = (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
      if (byBitrate != 0) return byBitrate;
      final bySampleRate = (b.sampleRate ?? 0).compareTo(a.sampleRate ?? 0);
      if (bySampleRate != 0) return bySampleRate;
      final byCodec = codecScore(b.codec).compareTo(codecScore(a.codec));
      if (byCodec != 0) return byCodec;
      return containerScore(a.container).compareTo(containerScore(b.container));
    });
    return copy.first;
  }

  static int codecScore(String? codec) {
    final c = codec?.split('.').first.toLowerCase() ?? '';
    switch (c) {
      case 'opus':
        return 7;
      case 'flac':
        return 6;
      case 'mp4a':
      case 'aac':
        return 5;
      case 'ac3':
      case 'eac3':
      case 'dts':
        return 5;
      case 'mp3':
        return 4;
      case 'vorbis':
        return 4;
      case 'pcm':
        return 3;
      case 'none':
        return 0;
      default:
        return 2;
    }
  }

  static int containerScore(String? container) {
    final c = container?.toLowerCase() ?? '';
    if (c.contains('mp4') || c.contains('m4a')) return 3;
    if (c.contains('webm') || c.contains('ogg')) return 2;
    if (c.contains('mkv')) return 2;
    return 1;
  }
}
