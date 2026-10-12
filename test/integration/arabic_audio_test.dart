import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/providers/format_selector.dart';
import 'package:universal_downloader/providers/youtube/youtube_extractor.dart';
import 'package:universal_downloader/providers/youtube/youtube_format_mapper.dart';

Future<String?> _which(String name) async {
  final result = await Process.run('which', [name]);
  if (result.exitCode != 0) return null;
  final path = (result.stdout as String).trim();
  return path.isEmpty ? null : path;
}

void main() async {
  final ytDlp = await _which('yt-dlp');

  const testUrl = 'https://youtu.be/XlitAikSDR8';
  const selector = FormatSelector();

  group('Arabic audio detection (XlitAikSDR8)', () {
    test(
      'ios client exposes Arabic audio tracks',
      () async {
        final extractor = YoutubeExtractor(ytDlpPath: ytDlp!);
        final json = await extractor.extractJson(Uri.parse(testUrl));
        final info = const YoutubeFormatMapper().fromJson(
          json,
          Uri.parse(testUrl),
        );

        expect(info.hasAudioForLanguage('ar'), isTrue,
            reason: 'Should find Arabic audio');
        expect(info.audioLanguages, contains('ar'));

        final arabicAudio = selector.selectBestAudio(
          info.audioFormats,
          preferredLanguage: 'ar',
        );
        expect(arabicAudio, isNotNull, reason: 'Should select Arabic audio');
        expect(arabicAudio!.language, anyOf(equals('ar'), startsWith('ar')));
      },
      skip: ytDlp == null ? 'yt-dlp not on PATH' : false,
    );

    test(
      'best Arabic audio is opus ~155kbps (format 251-16)',
      () async {
        final extractor = YoutubeExtractor(ytDlpPath: ytDlp!);
        final json = await extractor.extractJson(Uri.parse(testUrl));
        final info = const YoutubeFormatMapper().fromJson(
          json,
          Uri.parse(testUrl),
        );

        final arabicAudio = selector.selectBestAudio(
          info.audioFormats,
          preferredLanguage: 'ar',
        );
        expect(arabicAudio, isNotNull);
        expect(arabicAudio!.bitrate, greaterThanOrEqualTo(150));
        expect(arabicAudio.language, startsWith('ar'));
      },
      skip: ytDlp == null ? 'yt-dlp not on PATH' : false,
    );
  });

  group('English fallback (dQw4w9WgXcQ)', () {
    test(
      'falls back to English when Arabic is unavailable',
      () async {
        final extractor = YoutubeExtractor(ytDlpPath: ytDlp!);
        final json = await extractor.extractJson(
          Uri.parse('https://youtu.be/dQw4w9WgXcQ'),
        );
        final info = const YoutubeFormatMapper().fromJson(
          json,
          Uri.parse('https://youtu.be/dQw4w9WgXcQ'),
        );

        expect(info.hasAudioForLanguage('ar'), isFalse,
            reason: 'This video has no Arabic audio');

        final fallback = selector.selectBestAudio(
          info.audioFormats,
          preferredLanguage: 'en',
          allowOtherLanguages: true,
        );
        expect(fallback, isNotNull, reason: 'Should still find English audio');
      },
      skip: ytDlp == null ? 'yt-dlp not on PATH' : false,
    );
  });
}
