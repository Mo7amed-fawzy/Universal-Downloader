import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';
import 'package:universal_downloader/providers/youtube/youtube_cover_downloader.dart';

void main() {
  late Directory root;
  late File video;
  late File audio;
  late File cover;
  const runner = ProcessRunner();
  final assembler = MediaAssembler(
    ffmpegPath: 'ffmpeg',
    ffprobePath: 'ffprobe',
  );

  Future<void> ffmpeg(List<String> args) async {
    final result = await runner.run(
      executable: 'ffmpeg',
      arguments: ['-y', '-hide_banner', '-loglevel', 'error', ...args],
    );
    expect(result.success, isTrue, reason: result.stderr);
  }

  Future<String> streamHash(File file, String stream) async {
    final result = await runner.run(
      executable: 'ffmpeg',
      arguments: [
        '-v',
        'error',
        '-i',
        file.path,
        '-map',
        stream,
        '-c',
        'copy',
        '-f',
        'streamhash',
        '-hash',
        'sha256',
        '-',
      ],
    );
    expect(result.success, isTrue, reason: result.stderr);
    return result.stdout;
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('media_cover_');
    video = File('${root.path}/video.mp4');
    audio = File('${root.path}/audio.m4a');
    cover = File('${root.path}/original.jpg');
    await ffmpeg([
      '-f',
      'lavfi',
      '-i',
      'color=black:size=320x240:duration=2',
      '-c:v',
      'libx264',
      video.path,
    ]);
    await ffmpeg([
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=2',
      '-c:a',
      'aac',
      '-metadata:s:a:0',
      'language=ara',
      audio.path,
    ]);
    await ffmpeg([
      '-f',
      'lavfi',
      '-i',
      'color=red:size=640x360',
      '-frames:v',
      '1',
      '-update',
      '1',
      cover.path,
    ]);
  });

  tearDown(() => root.deleteSync(recursive: true));

  for (final extension in ['mp4', 'mkv']) {
    for (final combined in [false, true]) {
      test(
        '$extension embeds cover with ${combined ? 'combined' : 'separate'} streams',
        () async {
          final input = combined
              ? await assembler.merge(video, audio, '${root.path}/combined.mp4')
              : video;
          final output = await assembler.merge(
            input,
            combined ? null : audio,
            '${root.path}/output.$extension',
            cover: cover,
          );
          final report = await assembler.verify(
            output,
            expectedHeight: 240,
            expectedAudioLanguage: 'ara',
            expectCover: true,
          );
          expect(report.passed, isTrue, reason: report.failures.join('\n'));
          expect(report.height, 240);
          expect(report.width, 320);
          expect(
            await streamHash(output, '0:V:0'),
            await streamHash(video, '0:v:0'),
          );
          expect(
            await streamHash(output, '0:a:0'),
            await streamHash(audio, '0:a:0'),
          );
          final extracted = File('${root.path}/extracted.jpg');
          await ffmpeg([
            '-i',
            output.path,
            '-map',
            '0:v:1',
            '-c',
            'copy',
            '-frames:v',
            '1',
            '-update',
            '1',
            extracted.path,
          ]);
          expect(extracted.readAsBytesSync(), cover.readAsBytesSync());
        },
      );
    }
  }

  test('missing artwork fails verification when a cover is expected', () async {
    final output = await assembler.merge(
      video,
      audio,
      '${root.path}/plain.mp4',
    );
    final report = await assembler.verify(output, expectCover: true);
    expect(report.passed, isFalse);
    expect(report.failures, contains('No embedded cover found.'));
  });

  test('artwork alone does not satisfy the video-stream check', () async {
    final output = File('${root.path}/audio_with_cover.mp4');
    await ffmpeg([
      '-i',
      audio.path,
      '-i',
      cover.path,
      '-map',
      '0:a:0',
      '-map',
      '1:v:0',
      '-c',
      'copy',
      '-disposition:v:0',
      'attached_pic',
      output.path,
    ]);
    final report = await assembler.verify(output, expectCover: true);
    expect(report.hasVideo, isFalse);
    expect(report.failures, contains('No video stream found.'));
  });

  test('downloads a WebP cover over HTTP and converts it to JPEG', () async {
    final webp = File('${root.path}/source.webp');
    await ffmpeg(['-i', cover.path, '-frames:v', '1', webp.path]);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'webp');
      request.response.add(webp.readAsBytesSync());
      await request.response.close();
    });
    final downloaded =
        await const YoutubeCoverDownloader(
          ffmpegPath: 'ffmpeg',
          runner: runner,
        ).download(
          url: Uri.parse('http://127.0.0.1:${server.port}/cover.webp'),
          directory: root,
          cancelToken: CancelToken(),
        );
    final probe = await runner.run(
      executable: 'ffprobe',
      arguments: [
        '-v',
        'error',
        '-show_streams',
        '-of',
        'json',
        downloaded.path,
      ],
    );
    final decoded = jsonDecode(probe.stdout) as Map<String, dynamic>;
    final streams = decoded['streams'] as List<dynamic>;
    expect(streams.single['codec_name'], 'mjpeg');
    expect(streams.single['width'], 640);
  });

  test('HTTP failure never reuses stale artwork', () async {
    File('${root.path}/cover.jpg').writeAsBytesSync(cover.readAsBytesSync());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    await expectLater(
      const YoutubeCoverDownloader(
        ffmpegPath: 'ffmpeg',
        runner: runner,
      ).download(
        url: Uri.parse('http://127.0.0.1:${server.port}/missing.jpg'),
        directory: root,
        cancelToken: CancelToken(),
      ),
      throwsA(isA<DownloadFailedException>()),
    );
  });

  test('a cancelled cover download aborts before starting ffmpeg', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      const YoutubeCoverDownloader(
        ffmpegPath: '/nonexistent',
        runner: runner,
      ).download(
        url: Uri.parse('https://example.com/cover.jpg'),
        directory: root,
        cancelToken: token,
      ),
      throwsA(isA<DownloadCancelledException>()),
    );
  });

  test('cancels a cover request while the server is stalled', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requested = Completer<void>();
    server.listen((request) => requested.complete());
    final token = CancelToken();
    final result = expectLater(
      const YoutubeCoverDownloader(
        ffmpegPath: 'ffmpeg',
        runner: runner,
      ).download(
        url: Uri.parse('http://127.0.0.1:${server.port}/cover.jpg'),
        directory: root,
        cancelToken: token,
      ),
      throwsA(isA<DownloadCancelledException>()),
    );
    await requested.future.timeout(const Duration(seconds: 5));
    token.cancel();
    await result.timeout(const Duration(seconds: 6));
  });

  test('rejects local file URLs before starting ffmpeg', () async {
    await expectLater(
      const YoutubeCoverDownloader(
        ffmpegPath: '/nonexistent',
        runner: runner,
      ).download(url: cover.uri, directory: root, cancelToken: CancelToken()),
      throwsA(isA<DownloadFailedException>()),
    );
  });
}
