import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/audio_format.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/providers/format_selector.dart';

const selector = FormatSelector();

AudioFormat audio({
  required String id,
  String? language,
  int? bitrate,
  int? sampleRate,
  String? codec,
  String? container,
}) {
  return AudioFormat(
    formatId: id,
    language: language,
    bitrate: bitrate,
    sampleRate: sampleRate,
    codec: codec,
    container: container,
  );
}

VideoFormat video({
  required String id,
  int? width,
  int? height,
  int? fps,
  String? codec,
  int? bitrate,
  String? container,
  bool videoOnly = false,
  bool hasAudio = false,
}) {
  return VideoFormat(
    formatId: id,
    width: width,
    height: height,
    fps: fps,
    codec: codec,
    bitrate: bitrate,
    container: container,
    videoOnly: videoOnly,
    hasAudio: hasAudio,
  );
}

void main() {
  group('manual audio quality', () {
    final formats = [
      audio(id: 'near', language: 'ar', bitrate: 127),
      audio(id: 'aac', language: 'ar', bitrate: 128, codec: 'mp4a'),
      audio(id: 'opus', language: 'ar', bitrate: 128, codec: 'opus'),
      audio(id: 'other', language: 'en', bitrate: 320),
      audio(id: 'unknown', language: 'ar'),
      audio(id: 'invalid', language: 'ar', bitrate: 0),
    ];

    test('lists only distinct positive bitrates of the selected language', () {
      expect(selector.availableAudioBitrates(formats, 'ar'), [128, 127]);
      expect(selector.availableAudioBitrates(formats, 'en'), [320]);
      expect(selector.availableAudioBitrates(formats, 'fr'), isEmpty);
    });

    test('selects the exact bitrate and ranks matching codecs', () {
      expect(
        selector
            .selectAudioAtBitrate(formats, language: 'ar', bitrate: 128)
            ?.formatId,
        'opus',
      );
    });

    test('does not replace an unavailable bitrate or language', () {
      for (final bitrate in [0, 126, 129, 320]) {
        expect(
          selector.selectAudioAtBitrate(
            formats,
            language: 'ar',
            bitrate: bitrate,
          ),
          isNull,
        );
      }
    });
  });

  group('selectBestVideo', () {
    test(
      'offers unique available heights including low and nonstandard ones',
      () {
        final formats = [
          video(id: '720', width: 1280, height: 720, videoOnly: true),
          video(id: '720-copy', width: 1280, height: 720, hasAudio: true),
          video(id: '240', width: 426, height: 240, videoOnly: true),
          video(id: '144', width: 256, height: 144, videoOnly: true),
          video(id: '180', width: 320, height: 180, videoOnly: true),
          video(id: 'unknown'),
          video(id: 'invalid', width: 640, height: 0),
        ];
        expect(selector.availableVideoHeights(formats), [720, 240, 180, 144]);
        for (final height in [240, 180, 144]) {
          expect(
            selector.selectBestVideo(formats, maxHeight: height)?.height,
            height,
          );
        }
        expect(
          selector.selectBestVideo(formats, quality: VideoQuality.q240)?.height,
          240,
        );
        expect(
          selector.selectBestVideo(formats, quality: VideoQuality.q144)?.height,
          144,
        );
      },
    );

    test(
      'does not replace the selected progressive height with lower DASH',
      () {
        final formats = [
          video(id: 'dash', width: 256, height: 144, videoOnly: true),
          video(id: 'progressive', width: 426, height: 240, hasAudio: true),
        ];
        expect(selector.selectBestVideo(formats)?.formatId, 'progressive');
        expect(
          selector.selectBestVideo(formats, maxHeight: 240)?.formatId,
          'progressive',
        );
      },
    );

    test('picks the highest resolution video-only stream for best', () {
      final formats = [
        video(id: 'v360', width: 640, height: 360, videoOnly: true),
        video(id: 'v720', width: 1280, height: 720, videoOnly: true),
        video(id: 'v1080', width: 1920, height: 1080, videoOnly: true),
      ];
      expect(selector.selectBestVideo(formats)?.formatId, 'v1080');
    });

    test('prefers video-only over progressive at equal quality', () {
      final formats = [
        video(id: 'progressive', width: 1920, height: 1080, hasAudio: true),
        video(id: 'dash', width: 1920, height: 1080, videoOnly: true),
      ];
      expect(selector.selectBestVideo(formats)?.formatId, 'dash');
    });

    test('capped quality selects the best stream at or below the cap', () {
      final formats = [
        video(id: 'v360', width: 640, height: 360, videoOnly: true),
        video(id: 'v720', width: 1280, height: 720, videoOnly: true),
        video(id: 'v1080', width: 1920, height: 1080, videoOnly: true),
      ];
      expect(
        selector.selectBestVideo(formats, quality: VideoQuality.q720)?.formatId,
        'v720',
      );
      expect(
        selector
            .selectBestVideo(formats, quality: VideoQuality.q1080)
            ?.formatId,
        'v1080',
      );
    });

    test('capped quality below availability returns the lowest available', () {
      final formats = [
        video(id: 'v720', width: 1280, height: 720, videoOnly: true),
        video(id: 'v1080', width: 1920, height: 1080, videoOnly: true),
      ];
      expect(
        selector.selectBestVideo(formats, quality: VideoQuality.q360)?.formatId,
        'v720',
      );
    });

    test('returns null when no stream has dimensions', () {
      expect(selector.selectBestVideo([]), isNull);
      expect(selector.selectBestVideo([video(id: 'x', height: 0)]), isNull);
    });
  });

  group('selectBestAudio', () {
    test('prefers formats matching the preferred language base code', () {
      final formats = [
        audio(id: 'en1', language: 'en', bitrate: 128),
        audio(id: 'ar1', language: 'ar-EG', bitrate: 96),
        audio(id: 'ar2', language: 'ar', bitrate: 128),
      ];
      expect(
        selector.selectBestAudio(formats, preferredLanguage: 'ar')?.formatId,
        'ar2',
      );
    });

    test('ranks by bitrate within the matched language', () {
      final formats = [
        audio(id: 'low', language: 'ar', bitrate: 48),
        audio(id: 'high', language: 'ar', bitrate: 192),
        audio(id: 'mid', language: 'ar', bitrate: 128),
      ];
      expect(
        selector.selectBestAudio(formats, preferredLanguage: 'ar')?.formatId,
        'high',
      );
    });

    test('breaks bitrate ties by sample rate', () {
      final formats = [
        audio(id: 'low48', language: 'ar', bitrate: 128, sampleRate: 44100),
        audio(id: 'high48', language: 'ar', bitrate: 128, sampleRate: 48000),
      ];
      expect(
        selector.selectBestAudio(formats, preferredLanguage: 'ar')?.formatId,
        'high48',
      );
    });

    test('returns null when the language is unavailable and no fallback', () {
      final formats = [audio(id: 'en', language: 'en', bitrate: 128)];
      expect(
        selector.selectBestAudio(formats, preferredLanguage: 'ar'),
        isNull,
      );
    });

    test('falls back to the fallback language when preferred is missing', () {
      final formats = [
        audio(id: 'en', language: 'en', bitrate: 128),
        audio(id: 'fr', language: 'fr', bitrate: 192),
      ];
      expect(
        selector
            .selectBestAudio(
              formats,
              preferredLanguage: 'ar',
              fallbackLanguage: 'en',
            )
            ?.formatId,
        'en',
      );
    });

    test('allowOtherLanguages picks the best track when nothing matches', () {
      final formats = [
        audio(id: 'en', language: 'en', bitrate: 64),
        audio(id: 'fr', language: 'fr', bitrate: 256),
      ];
      expect(
        selector
            .selectBestAudio(
              formats,
              preferredLanguage: 'ar',
              allowOtherLanguages: true,
            )
            ?.formatId,
        'fr',
      );
    });

    test('returns null for an empty format list', () {
      expect(
        selector.selectBestAudio(const [], preferredLanguage: 'ar'),
        isNull,
      );
    });
  });

  group('audioForLanguage', () {
    test('returns only formats whose base language matches', () {
      final formats = [
        audio(id: 'ar1', language: 'ar'),
        audio(id: 'ar-eg', language: 'ar-EG'),
        audio(id: 'en', language: 'en'),
      ];
      expect(selector.audioForLanguage(formats, 'ar').map((f) => f.formatId), [
        'ar1',
        'ar-eg',
      ]);
    });
  });

  group('language matching', () {
    test('baseLanguage strips the region suffix', () {
      expect(audio(id: 'a', language: 'ar-EG').baseLanguage, 'ar');
      expect(audio(id: 'a', language: 'en-US').baseLanguage, 'en');
      expect(audio(id: 'a', language: null).baseLanguage, '');
    });

    test('languageMatches is case-insensitive on the base code', () {
      expect(audio(id: 'a', language: 'AR-eg').languageMatches('ar'), isTrue);
      expect(audio(id: 'a', language: 'en-US').languageMatches('en'), isTrue);
      expect(audio(id: 'a', language: 'en-US').languageMatches('ar'), isFalse);
      expect(audio(id: 'a', language: null).languageMatches('en'), isFalse);
    });
  });
}
