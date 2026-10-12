/// A video stream offered by a provider.
///
/// Format ids are provider specific and MUST NOT be hardcoded across videos;
/// they are resolved dynamically from provider metadata.
class VideoFormat {
  const VideoFormat({
    required this.formatId,
    this.width,
    this.height,
    this.fps,
    this.codec,
    this.bitrate,
    this.container,
    this.note,
    this.filesize,
    this.videoOnly = false,
    this.hasAudio = false,
  });

  final String formatId;
  final int? width;
  final int? height;
  final int? fps;

  /// Video codec, e.g. `avc1.640028`, `vp9`, `av01.0.08M.08`.
  final String? codec;
  final int? bitrate;

  /// Container extension, e.g. `mp4`, `webm`, `m4a`.
  final String? container;

  /// Human readable note, e.g. `1080p`, `DASH video`.
  final String? note;

  final int? filesize;

  /// True when the stream carries video but NO audio (DASH video).
  final bool videoOnly;

  /// True when the stream carries embedded audio (progressive).
  final bool hasAudio;

  String get resolutionLabel {
    if (height == null) return note ?? 'unknown';
    final fpsPart = (fps != null && fps! > 30) ? ' ${fps!}fps' : '';
    return '${height!}p$fpsPart';
  }

  String get codecLabel => codec?.split('.').first ?? 'unknown';

  /// Approximate quality rank used for sorting. Higher is better.
  int get qualityRank {
    var rank = 0;
    rank += (height ?? 0) * 1000;
    rank += (fps ?? 30) - 30;
    rank += (bitrate ?? 0) ~/ 100000;
    return rank;
  }

  bool hasBetterQualityThan(VideoFormat other) => qualityRank > other.qualityRank;
}
