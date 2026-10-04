import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/providers/youtube/youtube_extractor.dart'
    show YoutubeExtractor, M3u8Progressive;
import 'package:universal_downloader/providers/youtube/youtube_format_mapper.dart';

const mapper = YoutubeFormatMapper();
final pageUrl = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

Map<String, dynamic> format({
  required String id,
  String ext = 'mp4',
  String? vcodec,
  String? acodec,
  int? width,
  int? height,
  int? fps,
  int? abr,
  int? asr,
  String? language,
  String? formatNote,
  String? protocol,
}) {
  return {
    'format_id': id,
    'ext': ext,
    'protocol': protocol,
    'vcodec': vcodec ?? 'none',
    'acodec': acodec ?? 'none',
    'width': width,
    'height': height,
    'fps': fps,
    'abr': abr,
    'asr': asr,
    'language': language,
    'format_note': formatNote,
  };
}

void main() {
  test('maps title, id, duration and page url', () {
    final info = mapper.fromJson({
      'id': 'dQw4w9WgXcQ',
      'title': 'Rick Astley - Never Gonna Give You Up',
      'duration': 212,
      'uploader': 'RickAstleyVEVO',
      'thumbnail': 'https://i.ytimg.com/vi/x/hqdefault.jpg',
      'formats': <Object>[],
    }, pageUrl);

    expect(info.id, 'dQw4w9WgXcQ');
    expect(info.title, 'Rick Astley - Never Gonna Give You Up');
    expect(info.duration, const Duration(seconds: 212));
    expect(info.uploader, 'RickAstleyVEVO');
    expect(info.pageUrl, pageUrl);
    expect(info.thumbnail.toString(), 'https://i.ytimg.com/vi/x/hqdefault.jpg');
  });

  test('classifies video-only, audio-only and progressive formats', () {
    final info = mapper.fromJson({
      'title': 't',
      'formats': <Object>[
        format(
          id: 'v1',
          vcodec: 'avc1.640028',
          width: 1920,
          height: 1080,
          fps: 30,
        ),
        format(
          id: 'a1',
          acodec: 'opus',
          abr: 128,
          asr: 48000,
          language: 'ar',
          ext: 'webm',
        ),
        format(id: 'p1', vcodec: 'avc1', acodec: 'mp4a', width: 640, height: 360),
      ],
    }, pageUrl);

    expect(info.videoFormats.map((f) => f.formatId), ['v1', 'p1']);
    expect(info.audioFormats.map((f) => f.formatId), ['a1']);

    expect(info.videoFormats.first.videoOnly, isTrue);
    expect(info.videoFormats.first.hasAudio, isFalse);
    expect(info.videoFormats.first.resolutionLabel, '1080p');
    expect(info.videoFormats.last.hasAudio, isTrue);
    expect(info.videoFormats.last.videoOnly, isFalse);

    final audio = info.audioFormats.single;
    expect(audio.language, 'ar');
    expect(audio.bitrate, 128);
    expect(audio.sampleRate, 48000);
    expect(audio.codec, 'opus');
  });

  test('skips storyboard and mhtml entries', () {
    final info = mapper.fromJson({
      'title': 't',
      'formats': <Object>[
        format(id: 'sb1', protocol: 'mhtml'),
        {'format_id': 'sb2', 'vcodec': 'none', 'acodec': 'none'},
        format(id: 'a1', acodec: 'mp4a', language: 'en'),
      ],
    }, pageUrl);
    expect(info.videoFormats, isEmpty);
    expect(info.audioFormats.map((f) => f.formatId), ['a1']);
  });

  test('deduplicates audio formats with identical track metadata', () {
    final info = mapper.fromJson({
      'title': 't',
      'formats': <Object>[
        format(id: 'a1', acodec: 'mp4a', abr: 128, asr: 48000, language: 'ar'),
        format(id: 'a2', acodec: 'mp4a', abr: 128, asr: 48000, language: 'ar'),
        format(id: 'a3', acodec: 'opus', abr: 128, asr: 48000, language: 'ar'),
      ],
    }, pageUrl);
    expect(info.audioFormats.map((f) => f.formatId), ['a1', 'a3']);
  });

  test('audioLanguages exposes the distinct languages in order', () {
    final info = mapper.fromJson({
      'title': 't',
      'formats': <Object>[
        format(id: 'a1', acodec: 'mp4a', language: 'ar'),
        format(id: 'a2', acodec: 'mp4a', language: 'ar-EG'),
        format(id: 'a3', acodec: 'mp4a', language: 'en'),
      ],
    }, pageUrl);
    expect(info.audioLanguages, ['ar', 'en']);
  });

  test('falls back to Untitled when title is missing', () {
    final info = mapper.fromJson({'formats': <Object>[]}, pageUrl);
    expect(info.title, 'Untitled');
  });

  group('mergeM3u8Progressives', () {
    test('adds progressive languages missing from DASH audio', () {
      final info = mapper.fromJson({
        'title': 't',
        'formats': <Object>[
          format(id: 'a1', acodec: 'mp4a', language: 'en-US', abr: 128),
        ],
      }, pageUrl);

      expect(info.audioLanguages, ['en']);

      final merged = mapper.mergeM3u8Progressives(info, [
        const M3u8Progressive(
          formatId: '95-18', ext: 'mp4', language: 'ar',
          width: 1280, height: 720,
        ),
        const M3u8Progressive(
          formatId: '96-18', ext: 'mp4', language: 'ar',
          width: 1920, height: 1080,
        ),
        const M3u8Progressive(
          formatId: '93-18', ext: 'mp4', language: 'en',
          width: 640, height: 360,
        ),
      ]);

      // English already exists via DASH → not duplicated.
      expect(
        merged.audioFormats
            .where((f) => f.languageMatches('en') && f.progressiveFormatId != null),
        isEmpty,
      );

      // Arabic added from m3u8 progressive.
      final arabic = merged.audioFormats
          .where((f) => f.languageMatches('ar'))
          .toList();
      expect(arabic.length, 1);
      expect(arabic.first.progressiveFormatId, isNotNull);
    });

    test('does not duplicate DASH-present languages', () {
      final info = mapper.fromJson({
        'title': 't',
        'formats': <Object>[
          format(id: 'a1', acodec: 'opus', language: 'ar', abr: 152),
          format(id: 'a2', acodec: 'mp4a', language: 'en', abr: 128),
        ],
      }, pageUrl);

      final merged = mapper.mergeM3u8Progressives(info, [
        const M3u8Progressive(
          formatId: '95-18', ext: 'mp4', language: 'ar',
          width: 1280, height: 720,
        ),
      ]);

      // Arabic already in DASH → no extra progressive entry.
      final arabicProgressive = merged.audioFormats
          .where((f) => f.languageMatches('ar') && f.progressiveFormatId != null)
          .toList();
      expect(arabicProgressive, isEmpty);
    });
  });

  group('YoutubeExtractor._parseFOutput', () {
    test('parses m3u8 progressive lines with language tags', () {
      const output = '''
ID  EXT   RESOLUTION FPS CH │   FILESIZE  TBR PROTO │ VCODEC       VBR ACODEC      ABR ASR MORE INFO
-----------------------------------------------------------------------------------------------------------------------------------------------------
93-18 mp4   640x360     24    │ ~  3.83MiB 218k m3u8  │ avc1.4D401E      mp4a.40.2           [ar]
95-18 mp4   1280x720    24    │ ~  6.18MiB 353k m3u8  │ avc1.64001F      mp4a.40.2           [ar]
96-18 mp4   1920x1080   24    │ ~  9.22MiB 526k m3u8  │ avc1.640028      mp4a.40.2           [ar]
96-21 mp4   1920x1080   24    │ ~  9.21MiB 526k m3u8  │ avc1.640028      mp4a.40.2           [en-US]
''';
      final results = YoutubeExtractor.parseFOutput(output);
      expect(results.length, 4);

      final arabic = results.where((r) => r.language == 'ar').toList();
      expect(arabic.length, 3);
      expect(arabic[0].formatId, '93-18');
      expect(arabic[0].height, 360);
      expect(arabic[1].formatId, '95-18');
      expect(arabic[1].height, 720);
      expect(arabic[2].formatId, '96-18');
      expect(arabic[2].height, 1080);

      final english = results.where((r) => r.language == 'en-US').toList();
      expect(english.length, 1);
    });

    test('ignores non-m3u8 lines', () {
      const output = '''
ID    EXT   RESOLUTION FPS CH │   FILESIZE  TBR PROTO │ VCODEC       VBR ACODEC      ABR ASR MORE INFO
139   m4a   audio only      2 │  879.07KiB  49k https │ audio only       mp4a.40.5   49k 22k [en-US]
136   mp4   1280x720    24    │    2.44MiB 139k https │ avc1.64001f 139k video only          720p, mp4_dash
''';
      final results = YoutubeExtractor.parseFOutput(output);
      expect(results, isEmpty);
    });
  });
}
