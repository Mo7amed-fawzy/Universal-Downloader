import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';
import 'package:universal_downloader/providers/youtube/youtube_extractor.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';

/// Finds the absolute path of [name] on PATH, or null when unavailable.
Future<String?> _which(String name) async {
  final result = await Process.run('which', [name]);
  if (result.exitCode != 0) return null;
  final path = (result.stdout as String).trim();
  return path.isEmpty ? null : path;
}

const _testVideoUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

void main() async {
  final ytDlp = await _which('yt-dlp');
  final ffmpeg = await _which('ffmpeg');
  final ffprobe = await _which('ffprobe');

  group('yt-dlp extraction (network)', () {
    test(
      'fetches real metadata with video and audio formats',
      () async {
        final extractor = YoutubeExtractor(ytDlpPath: ytDlp!);
        final json = await extractor.extractJson(Uri.parse(_testVideoUrl));

        expect(json['id'], 'dQw4w9WgXcQ');
        expect(json['title'], isNotEmpty);
        final formats = json['formats'] as List<dynamic>? ?? const [];
        expect(formats, isNotEmpty);
      },
      skip: ytDlp == null ? 'yt-dlp not on PATH' : false,
    );

    test(
      'YouTube provider detects the URL',
      () {
        final provider = YoutubeProvider(
          ytDlpPath: ytDlp!,
          ffmpegPath: ffmpeg!,
          ffprobePath: ffprobe!,
        );
        expect(provider.canHandle(Uri.parse(_testVideoUrl)), isTrue);
        expect(provider.canHandle(Uri.parse('https://youtu.be/x')), isTrue);
        expect(
          provider.canHandle(Uri.parse('https://example.com/video.mp4')),
          isFalse,
        );
      },
      skip: ytDlp == null ? 'yt-dlp not on PATH' : false,
    );
  });

  group('MediaAssembler (ffmpeg)', () {
    test(
      'merges separate video and audio streams without re-encoding',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('merge_test_');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        final video = File('${tempDir.path}/video.mp4');
        final audio = File('${tempDir.path}/audio.m4a');
        final out = '${tempDir.path}/merged.mp4';

        // 1-second black video + 1-second sine tone.
        final makeVideo = await Process.run(ffmpeg!, [
          '-y', '-hide_banner', '-loglevel', 'error',
          '-f', 'lavfi', '-i', 'color=black:size=320x240:duration=1',
          '-c:v', 'libx264', '-pix_fmt', 'yuv420p', video.path,
        ]);
        expect(makeVideo.exitCode, 0,
            reason: 'ffmpeg could not create test video: ${makeVideo.stderr}');

        final makeAudio = await Process.run(ffmpeg, [
          '-y', '-hide_banner', '-loglevel', 'error',
          '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
          '-c:a', 'aac', audio.path,
        ]);
        expect(makeAudio.exitCode, 0,
            reason: 'ffmpeg could not create test audio: ${makeAudio.stderr}');

        final assembler = MediaAssembler(
          ffmpegPath: ffmpeg,
          ffprobePath: ffprobe!,
        );

        final merged = await assembler.merge(video, audio, out);
        expect(merged.existsSync(), isTrue);
        expect(merged.lengthSync(), greaterThan(0));

        final report = await assembler.verify(merged);
        expect(report.passed, isTrue, reason: report.failures.join('\n'));
        expect(report.hasVideo, isTrue);
        expect(report.hasAudio, isTrue);
        expect(report.height, 240);
      },
      skip: (ffmpeg == null || ffprobe == null)
          ? 'ffmpeg/ffprobe not on PATH'
          : false,
    );

    test(
      'verification tolerates "und" language tag when user expects Arabic',
      () async {
        // Simulates the exact YouTube scenario: user picks Arabic audio,
        // merge succeeds, but ffprobe only sees "und" as the language tag.
        final tempDir = Directory.systemTemp.createTempSync('und_test_');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        final video = File('${tempDir.path}/video.mp4');
        final audio = File('${tempDir.path}/audio.m4a');
        final out = '${tempDir.path}/merged.mp4';

        await Process.run(ffmpeg!, [
          '-y', '-hide_banner', '-loglevel', 'error',
          '-f', 'lavfi', '-i', 'color=black:size=1920x1080:duration=1',
          '-c:v', 'libx264', '-pix_fmt', 'yuv420p', video.path,
        ]);
        // Deliberately no -metadata language flag → ffprobe will report "und".
        await Process.run(ffmpeg, [
          '-y', '-hide_banner', '-loglevel', 'error',
          '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
          '-c:a', 'aac', audio.path,
        ]);

        final assembler = MediaAssembler(
          ffmpegPath: ffmpeg,
          ffprobePath: ffprobe!,
        );

        final merged = await assembler.merge(video, audio, out);

        // Expected audio language "ar" but actual is "und" → must pass.
        final report = await assembler.verify(
          merged,
          expectedAudioLanguage: 'ar',
        );
        expect(report.passed, isTrue,
            reason: 'Verification should tolerate "und" tag: ${report.failures.join(', ')}');

        // But a real mismatch (expected "ar", actual "fr") must still fail.
        final video2 = File('${tempDir.path}/video2.mp4');
        final audio2 = File('${tempDir.path}/audio2.m4a');
        final out2 = '${tempDir.path}/merged2.mp4';
        await Process.run(ffmpeg, [
          '-y', '-hide_banner', '-loglevel', 'error',
          '-f', 'lavfi', '-i', 'color=black:size=320x240:duration=1',
          '-c:v', 'libx264', '-pix_fmt', 'yuv420p', video2.path,
        ]);
        await Process.run(ffmpeg, [
          '-y', '-hide_banner', '-loglevel', 'error',
          '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
          '-c:a', 'aac', '-metadata:s:a:0', 'language=fra', audio2.path,
        ]);
        final merged2 = await assembler.merge(video2, audio2, out2);
        final report2 = await assembler.verify(
          merged2,
          expectedAudioLanguage: 'ar',
        );
        expect(report2.passed, isFalse);
        expect(report2.failures.join('\n'), contains('Expected audio language'));
      },
      skip: (ffmpeg == null || ffprobe == null)
          ? 'ffmpeg/ffprobe not on PATH'
          : false,
    );
  });

  group('cancellation', () {
    test('a pre-cancelled token aborts immediately', () {
      final token = CancelToken();
      token.cancel();
      expect(() => token.throwIfCancelled(),
          throwsA(isA<DownloadCancelledException>()));
    });

    test('a live token does not throw', () {
      final token = CancelToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('cancellation is sticky after cancel', () async {
      final token = CancelToken();
      token.cancel();
      await expectLater(
        token.race(Future.delayed(const Duration(milliseconds: 50))),
        throwsA(isA<DownloadCancelledException>()),
      );
    });
  });
}
