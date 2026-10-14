import 'dart:convert';

import '../models/audio_format.dart';
import '../models/audio_output_format.dart';
import '../models/download_options.dart';
import '../models/media_info.dart';
import '../models/subtitle_track.dart';
import '../models/video_format.dart';

class MediaInfoCodec {
  const MediaInfoCodec();

  String encode(MediaInfo info) => jsonEncode({
    'version': 1,
    'id': info.id,
    'title': info.title,
    'providerId': info.providerId,
    'providerName': info.providerName,
    'pageUrl': info.pageUrl.toString(),
    'thumbnail': info.thumbnail?.toString(),
    'duration': info.duration?.inMilliseconds,
    'uploader': info.uploader,
    'description': info.description,
    'videoFormats': [
      for (final format in info.videoFormats)
        {
          'id': format.formatId,
          'width': format.width,
          'height': format.height,
          'fps': format.fps,
          'codec': format.codec,
          'bitrate': format.bitrate,
          'container': format.container,
          'note': format.note,
          'filesize': format.filesize,
          'videoOnly': format.videoOnly,
          'hasAudio': format.hasAudio,
        },
    ],
    'audioFormats': [
      for (final format in info.audioFormats)
        {
          'id': format.formatId,
          'language': format.language,
          'languageName': format.languageName,
          'bitrate': format.bitrate,
          'sampleRate': format.sampleRate,
          'codec': format.codec,
          'container': format.container,
          'filesize': format.filesize,
          'progressiveFormatId': format.progressiveFormatId,
        },
    ],
    'subtitles': [
      for (final track in info.subtitleTracks) _subtitleJson(track),
    ],
  });

  MediaInfo decode(String payload) {
    final json = _object(jsonDecode(payload));
    if (json['version'] != 1) {
      throw const FormatException('Unknown cache version');
    }
    final duration = json['duration'] as int?;
    final thumbnail = json['thumbnail'] as String?;
    return MediaInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      pageUrl: Uri.parse(json['pageUrl'] as String),
      thumbnail: thumbnail == null ? null : Uri.parse(thumbnail),
      duration: duration == null ? null : Duration(milliseconds: duration),
      uploader: json['uploader'] as String?,
      description: json['description'] as String?,
      videoFormats: [
        for (final format in _objects(json['videoFormats']))
          VideoFormat(
            formatId: format['id'] as String,
            width: format['width'] as int?,
            height: format['height'] as int?,
            fps: format['fps'] as int?,
            codec: format['codec'] as String?,
            bitrate: format['bitrate'] as int?,
            container: format['container'] as String?,
            note: format['note'] as String?,
            filesize: format['filesize'] as int?,
            videoOnly: format['videoOnly'] as bool,
            hasAudio: format['hasAudio'] as bool,
          ),
      ],
      audioFormats: [
        for (final format in _objects(json['audioFormats']))
          AudioFormat(
            formatId: format['id'] as String,
            language: format['language'] as String?,
            languageName: format['languageName'] as String?,
            bitrate: format['bitrate'] as int?,
            sampleRate: format['sampleRate'] as int?,
            codec: format['codec'] as String?,
            container: format['container'] as String?,
            filesize: format['filesize'] as int?,
            progressiveFormatId: format['progressiveFormatId'] as String?,
          ),
      ],
      subtitleTracks: [
        for (final track in _objects(json['subtitles'])) _subtitle(track),
      ],
    );
  }

  String encodeOptions(DownloadOptions options) => jsonEncode({
    'outputDirectory': options.outputDirectory,
    'videoFormatId': options.videoFormatId,
    'audioFormatId': options.audioFormatId,
    'audioLanguage': options.audioLanguage,
    'subtitle': options.subtitle == null
        ? null
        : _subtitleJson(options.subtitle!),
    'keepSpeech': options.keepSpeech,
    'keepMusic': options.keepMusic,
    'keepEffects': options.keepEffects,
    'speechRemovalStrength': options.speechRemovalStrength,
    'musicRemovalStrength': options.musicRemovalStrength,
    'effectsRemovalStrength': options.effectsRemovalStrength,
    'audioOutputFormat': options.audioOutputFormat?.id,
    'overwrite': options.overwrite,
    'container': switch (options.containerPreference) {
      ContainerPreference.auto => 'auto',
      ContainerPreference.mp4 => 'mp4',
      ContainerPreference.mkv => 'mkv',
    },
  });

  DownloadOptions decodeOptions(
    String payload, {
    required String taskId,
    required String title,
  }) {
    final json = _object(jsonDecode(payload));
    final subtitle = json['subtitle'];
    return DownloadOptions(
      taskId: taskId,
      title: title,
      outputDirectory: json['outputDirectory'] as String,
      videoFormatId: json['videoFormatId'] as String,
      audioFormatId: json['audioFormatId'] as String?,
      audioLanguage: json['audioLanguage'] as String?,
      subtitle: subtitle == null ? null : _subtitle(_object(subtitle)),
      keepSpeech: json['keepSpeech'] != false,
      keepMusic: json['keepMusic'] != false,
      keepEffects: json['keepEffects'] != false,
      speechRemovalStrength:
          (json['speechRemovalStrength'] as num?)?.toDouble() ?? 1,
      musicRemovalStrength:
          (json['musicRemovalStrength'] as num?)?.toDouble() ?? 1,
      effectsRemovalStrength:
          (json['effectsRemovalStrength'] as num?)?.toDouble() ?? 1,
      audioOutputFormat: AudioOutputFormatDetails.fromId(
        json['audioOutputFormat'] as String?,
      ),
      overwrite: json['overwrite'] as bool,
      containerPreference: switch (json['container']) {
        'mp4' => ContainerPreference.mp4,
        'mkv' => ContainerPreference.mkv,
        _ => ContainerPreference.auto,
      },
    );
  }

  Map<String, Object?> _subtitleJson(SubtitleTrack track) => {
    'language': track.language,
    'extension': track.extension,
    'name': track.name,
    'automatic': track.isAutomatic,
    'translated': track.isTranslated,
  };

  SubtitleTrack _subtitle(Map<String, Object?> json) => SubtitleTrack(
    language: json['language'] as String,
    extension: json['extension'] as String,
    name: json['name'] as String?,
    isAutomatic: json['automatic'] as bool,
    isTranslated: json['translated'] as bool,
  );

  Map<String, Object?> _object(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw const FormatException('Expected an object');
  }

  Iterable<Map<String, Object?>> _objects(Object? value) {
    if (value is List<Object?>) return value.map(_object);
    throw const FormatException('Expected a list');
  }
}
