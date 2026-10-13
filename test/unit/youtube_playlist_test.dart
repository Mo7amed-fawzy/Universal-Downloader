import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/command_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/providers/youtube/youtube_extractor.dart';
import 'package:universal_downloader/providers/youtube/youtube_playlist.dart';

void main() {
  test(
    'normalizes playlist and watch aliases while rejecting unrelated URLs',
    () {
      for (final link in [
        'https://youtube.com/playlist?list=PL_one&index=2',
        'https://music.youtube.com/watch?v=abcdefghijk&list=PL_one',
        'https://youtu.be/abcdefghijk?list=PL_one',
      ]) {
        expect(
          YoutubePlaylist.normalizeUrl(Uri.parse(link)).toString(),
          'https://www.youtube.com/playlist?list=PL_one',
        );
      }
      for (final link in [
        'https://evil.example/playlist?list=PL_one',
        'https://youtube.com.evil.example/playlist?list=PL_one',
        'file://youtube.com/playlist?list=PL_one',
        'https://youtube.com/watch?v=abcdefghijk',
        'https://youtube.com/playlist?list=',
      ]) {
        expect(YoutubePlaylist.normalizeUrl(Uri.parse(link)), isNull);
      }
    },
  );

  test('preserves order, removes duplicates and counts unreadable entries', () {
    final playlist = YoutubePlaylist.fromJson({
      '_type': 'playlist',
      'title': 'Course',
      'entries': [
        {'id': 'abcdefghijk'},
        null,
        {'id': 'invalid'},
        {'id': '12345678901', 'availability': 'private'},
        {'id': 'abcdefghijk'},
      ],
    });
    expect(playlist.title, 'Course');
    expect(playlist.videoUrls.map((url) => url.queryParameters['v']), [
      'abcdefghijk',
      '12345678901',
    ]);
    expect(
      playlist.videoUrls.every(
        (url) => !url.queryParameters.containsKey('list'),
      ),
      isTrue,
    );
    expect(playlist.unavailableCount, 2);
    expect(
      () => YoutubePlaylist.fromJson({'id': 'abcdefghijk'}),
      throwsFormatException,
    );
  });

  test('large playlist keeps every page entry without a client side limit', () {
    final playlist = YoutubePlaylist.fromJson({
      '_type': 'playlist',
      'entries': List.generate(
        250,
        (index) => {'id': index.toString().padLeft(11, '0')},
      ),
    });
    expect(playlist.videoUrls, hasLength(250));
  });

  test(
    'extracts a complete flat playlist through the configured runner',
    () async {
      final runner = PlaylistRunner(
        jsonEncode({
          '_type': 'playlist',
          'title': 'Course',
          'entries': [
            {'id': 'abcdefghijk'},
          ],
        }),
      );
      final token = CancelToken();
      final result =
          await YoutubeExtractor(
            ytDlpPath: '/tools/yt-dlp',
            runner: runner,
          ).extractPlaylist(
            Uri.parse(
              'https://youtube.com/watch?v=abcdefghijk&list=PLtest&index=9',
            ),
            cancelToken: token,
          );
      expect(result.videoUrls, hasLength(1));
      expect(
        runner.arguments,
        containsAll([
          '--flat-playlist',
          '--yes-playlist',
          '--skip-download',
          '--dump-single-json',
        ]),
      );
      expect(
        runner.arguments.last,
        'https://www.youtube.com/playlist?list=PLtest',
      );
      expect(runner.token, same(token));
      expect(runner.arguments, isNot(contains('--no-playlist')));
    },
  );

  test(
    'invalid output and extraction errors become actionable failures',
    () async {
      for (final runner in [
        PlaylistRunner('bad json'),
        PlaylistRunner('{}'),
        PlaylistRunner('', exitCode: 1),
      ]) {
        await expectLater(
          YoutubeExtractor(ytDlpPath: 'yt-dlp', runner: runner).extractPlaylist(
            Uri.parse('https://youtube.com/playlist?list=PLtest'),
          ),
          throwsA(isA<FormatExtractionException>()),
        );
      }
    },
  );

  test('cancelled extraction cannot return a playlist', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      YoutubeExtractor(
        ytDlpPath: 'yt-dlp',
        runner: PlaylistRunner('{}'),
      ).extractPlaylist(
        Uri.parse('https://youtube.com/playlist?list=PLtest'),
        cancelToken: token,
      ),
      throwsA(isA<DownloadCancelledException>()),
    );
  });
}

class PlaylistRunner implements CommandRunner {
  PlaylistRunner(this.output, {this.exitCode = 0});
  final String output;
  final int exitCode;
  List<String> arguments = [];
  CancelToken? token;

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String, bool)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    this.arguments = arguments;
    token = cancelToken;
    return ProcessRunnerResult(
      exitCode: exitCode,
      stdout: output,
      stderr: 'Unavailable',
    );
  }
}
