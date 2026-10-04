import '../../core/models/audio_format.dart';
import '../../core/models/media_info.dart';
import '../../core/models/subtitle_track.dart';
import '../../core/models/video_format.dart';
import 'youtube_extractor.dart' show M3u8Progressive;

/// Maps raw yt-dlp YouTube JSON into the generic [MediaInfo] model.
///
/// This class contains all YouTube-specific parsing; nothing downstream ever
/// depends on raw YouTube data shapes.
class YoutubeFormatMapper {
  const YoutubeFormatMapper();

  MediaInfo fromJson(Map<String, dynamic> json, Uri pageUrl) {
    final videoFormats = <VideoFormat>[];
    final audioFormats = <AudioFormat>[];

    final rawFormats = json['formats'] as List<dynamic>? ?? const [];

    for (final raw in rawFormats) {
      if (raw is! Map<String, dynamic>) continue;

      final protocol = raw['protocol'] as String?;
      if (protocol == 'mhtml') continue; // storyboards

      final vcodec = raw['vcodec'] as String? ?? 'none';
      final acodec = raw['acodec'] as String? ?? 'none';

      final isStoryboard = vcodec == 'none' && acodec == 'none';
      if (isStoryboard) continue;

      final formatId = raw['format_id'] as String? ?? '';
      if (formatId.isEmpty) continue;

      if (acodec == 'none' && vcodec != 'none') {
        // Video-only DASH stream.
        videoFormats.add(_toVideoFormat(raw, formatId, videoOnly: true));
      } else if (vcodec == 'none' && acodec != 'none') {
        // Audio-only stream.
        audioFormats.add(_toAudioFormat(raw, formatId));
      } else {
        // Progressive (video + embedded audio).
        videoFormats.add(
          _toVideoFormat(raw, formatId, videoOnly: false, hasAudio: true),
        );
      }
    }

    // Deduplicate audio formats that only differ by transient metadata.
    final seenAudio = <String>{};
    final uniqueAudio = <AudioFormat>[];
    for (final f in audioFormats) {
      final key = '${f.language}|${f.bitrate}|${f.sampleRate}|${f.codec}';
      if (seenAudio.add(key)) uniqueAudio.add(f);
    }

    final duration = (json['duration'] as num?)?.toInt();

    return MediaInfo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      providerId: 'youtube',
      providerName: 'YouTube',
      pageUrl: pageUrl,
      thumbnail: _parseUri(json['thumbnail'] as String?),
      duration: duration == null ? null : Duration(seconds: duration),
      uploader: (json['uploader'] as String?) ?? (json['channel'] as String?),
      description: json['description'] as String?,
      videoFormats: videoFormats,
      audioFormats: uniqueAudio,
      subtitleTracks: [
        ..._subtitleTracks(json['subtitles'], isAutomatic: false),
        ..._subtitleTracks(json['automatic_captions'], isAutomatic: true),
      ],
    );
  }

  List<SubtitleTrack> _subtitleTracks(
    Object? raw, {
    required bool isAutomatic,
  }) {
    if (raw is! Map<String, dynamic>) return const [];
    final tracks = <SubtitleTrack>[];
    for (final entry in raw.entries) {
      if (!RegExp(r'^[a-zA-Z0-9]+(?:[-_][a-zA-Z0-9]+)*$')
              .hasMatch(entry.key) ||
          entry.key == 'live_chat') {
        continue;
      }
      final formats = entry.value;
      if (formats is! List) continue;
      for (final extension in const ['vtt', 'srt']) {
        final matches = formats.whereType<Map<String, dynamic>>().where((f) {
          final url = f['url'];
          final uri = url is String ? Uri.tryParse(url) : null;
          return f['ext'] == extension &&
              uri != null &&
              uri.host.isNotEmpty &&
              (uri.scheme == 'https' || uri.scheme == 'http');
        });
        if (matches.isEmpty) continue;
        final name = matches.first['name'];
        tracks.add(SubtitleTrack(
          language: entry.key,
          extension: extension,
          name: name is String && name.trim().isNotEmpty ? name : null,
          isAutomatic: isAutomatic,
          isTranslated: isAutomatic && matches.any((format) {
            final url = format['url'];
            return url is String &&
                (Uri.tryParse(url)?.queryParameters['tlang']?.isNotEmpty ?? false);
          }),
        ));
        break;
      }
    }
    tracks.sort((a, b) => a.label.compareTo(b.label));
    return tracks;
  }

  VideoFormat _toVideoFormat(
    Map<String, dynamic> raw,
    String formatId, {
    required bool videoOnly,
    bool hasAudio = false,
  }) {
    return VideoFormat(
      formatId: formatId,
      width: _toInt(raw['width']),
      height: _toInt(raw['height']),
      fps: _toInt(raw['fps']),
      codec: raw['vcodec'] as String?,
      bitrate: _toInt(raw['vbr']),
      container: raw['ext'] as String?,
      note: raw['format_note'] as String?,
      filesize: _toInt(raw['filesize']) ?? _toInt(raw['filesize_approx']),
      videoOnly: videoOnly,
      hasAudio: hasAudio,
    );
  }

  AudioFormat _toAudioFormat(Map<String, dynamic> raw, String formatId) {
    final language = raw['language'] as String?;
    return AudioFormat(
      formatId: formatId,
      language: language,
      languageName: null,
      bitrate: _toInt(raw['abr']),
      sampleRate: _toInt(raw['asr']),
      codec: raw['acodec'] as String?,
      container: raw['ext'] as String?,
      filesize: _toInt(raw['filesize']) ?? _toInt(raw['filesize_approx']),
    );
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.round();
    return null;
  }

  static Uri? _parseUri(String? value) {
    if (value == null || value.isEmpty) return null;
    return Uri.tryParse(value);
  }

  /// Merges m3u8 progressive streams discovered via `-F` into an existing
  /// [MediaInfo].
  ///
  /// For each progressive stream whose language is NOT already present in
  /// [info.audioFormats], a synthetic [AudioFormat] is created with
  /// [AudioFormat.progressiveFormatId] set to the progressive stream's
  /// format id.  The download layer knows to fetch this single muxed
  /// stream instead of separate video + audio.
  MediaInfo mergeM3u8Progressives(
    MediaInfo info,
    List<M3u8Progressive> progressives,
  ) {
    // Languages already covered by DASH audio tracks.
    final dashLanguages = <String>{};
    for (final f in info.audioFormats) {
      final lang = f.language;
      if (lang != null && lang.isNotEmpty) {
        dashLanguages.add(lang.split('-').first.toLowerCase());
      }
    }

    // For each resolution bucket, pick the best progressive per language.
    // Key = "$lang|$height", value = best progressive.
    final best = <String, M3u8Progressive>{};
    for (final p in progressives) {
      final baseLang = p.language.split('-').first.toLowerCase();
      final key = '$baseLang|${p.height ?? 0}';
      final existing = best[key];
      if (existing == null) {
        best[key] = p;
      } else {
        // Prefer higher bitrate (not available from -F) → prefer larger height.
        if ((p.height ?? 0) > (existing.height ?? 0)) best[key] = p;
      }
    }

    // Create AudioFormat entries for languages only in m3u8 progressive.
    final extraAudio = <AudioFormat>[];
    final seenLangs = <String>{};
    for (final p in best.values) {
      final baseLang = p.language.split('-').first.toLowerCase();
      if (dashLanguages.contains(baseLang)) continue;
      if (!seenLangs.add(baseLang)) continue;

      extraAudio.add(AudioFormat(
        formatId: 'm3u8-${p.formatId}',
        language: p.language,
        languageName: null,
        bitrate: null,
        sampleRate: null,
        codec: p.ext == 'mp4' ? 'mp4a.40.2' : 'opus',
        container: p.ext,
        filesize: null,
        progressiveFormatId: p.formatId,
      ));
    }

    if (extraAudio.isEmpty) return info;

    return MediaInfo(
      id: info.id,
      title: info.title,
      providerId: info.providerId,
      providerName: info.providerName,
      pageUrl: info.pageUrl,
      thumbnail: info.thumbnail,
      duration: info.duration,
      uploader: info.uploader,
      description: info.description,
      videoFormats: info.videoFormats,
      audioFormats: [...info.audioFormats, ...extraAudio],
      subtitleTracks: info.subtitleTracks,
    );
  }
}
