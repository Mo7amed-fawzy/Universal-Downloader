/// An audio stream offered by a provider.
class AudioFormat {
  const AudioFormat({
    required this.formatId,
    this.language,
    this.languageName,
    this.bitrate,
    this.sampleRate,
    this.codec,
    this.container,
    this.filesize,
    this.progressiveFormatId,
  });

  final String formatId;

  /// ISO 639 language code, e.g. `ar`, `ar-EG`, `en`, `en-US`.
  final String? language;

  /// Human readable language name, e.g. `Arabic`.
  final String? languageName;

  /// Audio bitrate in kbps.
  final int? bitrate;

  /// Sample rate in Hz.
  final int? sampleRate;

  /// Audio codec, e.g. `opus`, `mp4a.40.2`.
  final String? codec;
  final String? container;
  final int? filesize;

  /// When non-null, this audio language is only available inside a muxed
  /// progressive m3u8 stream (video+audio).  The value is the yt-dlp format
  /// id of that progressive stream (e.g. `95-18`).  The download layer
  /// should fetch this single format instead of separate video+audio.
  final String? progressiveFormatId;

  /// Base language code (part before any region suffix).
  String get baseLanguage {
    final lang = language;
    if (lang == null || lang.isEmpty) return '';
    return lang.split('-').first;
  }

  /// True when [code] matches this format's base language.
  bool languageMatches(String code) {
    if (language == null || code.isEmpty) return false;
    return baseLanguage.toLowerCase() == code.split('-').first.toLowerCase();
  }

  String get codecLabel => codec?.split('.').first ?? 'unknown';

  /// Approximate quality rank used for sorting. Higher is better.
  int get qualityRank {
    var rank = 0;
    rank += (bitrate ?? 0) * 100;
    rank += (sampleRate ?? 0) ~/ 1000;
    return rank;
  }

  bool hasBetterQualityThan(AudioFormat other) =>
      qualityRank > other.qualityRank;
}
