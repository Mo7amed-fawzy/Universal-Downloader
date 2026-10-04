import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/subtitle_track.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/providers/youtube/youtube_subtitle_downloader.dart';

void main() async {
  final which = await Process.run('which', ['yt-dlp']);
  final ytDlp = (which.stdout as String).trim();

  for (final isAutomatic in [false, true]) {
    test(
      'real yt-dlp downloads only the selected ${isAutomatic ? 'automatic' : 'uploaded'} captions',
      () async {
        final root = Directory.systemTemp.createTempSync('subtitle%local_');
        addTearDown(() => root.deleteSync(recursive: true));
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final requests = <String>[];
        server.listen((request) async {
          requests.add(request.uri.path);
          request.response.headers.contentType = ContentType('text', 'vtt');
          request.response.write(
            'WEBVTT\n\n00:00.000 --> 00:01.000\n${request.uri.path}\n',
          );
          await request.response.close();
        });
        final baseUrl = 'http://127.0.0.1:${server.port}';
        final fixture = File('${root.path}/info.json');
        fixture.writeAsStringSync(
          jsonEncode({
            'id': 'local-subtitles',
            'title': 'Local captions',
            'extractor': 'generic',
            'extractor_key': 'Generic',
            'webpage_url': '$baseUrl/video',
            'url': '$baseUrl/video.mp4',
            'ext': 'mp4',
            'subtitles': {
              'ar': [
                {'ext': 'vtt', 'url': '$baseUrl/uploaded.vtt'},
              ],
              'ar-EG': [
                {'ext': 'vtt', 'url': '$baseUrl/regional.vtt'},
              ],
            },
            'automatic_captions': {
              'ar': [
                {'ext': 'vtt', 'url': '$baseUrl/automatic.vtt'},
              ],
            },
          }),
        );
        final output =
            await YoutubeSubtitleDownloader(
              ytDlpPath: ytDlp,
              runner: const ProcessRunner(),
              extraArgs: [
                '--ignore-config',
                '--load-info-json',
                fixture.path,
                '--write-subs',
                '--write-auto-subs',
                '--sub-langs',
                'all',
                '--convert-subs',
                'srt',
              ],
            ).download(
              url: Uri.parse('$baseUrl/video'),
              track: SubtitleTrack(
                language: 'ar',
                extension: 'vtt',
                isAutomatic: isAutomatic,
              ),
              directory: root,
              cancelToken: CancelToken(),
            );
        final expected = isAutomatic ? '/automatic.vtt' : '/uploaded.vtt';
        expect(requests, [expected]);
        expect(output.path, '${root.path}/subtitles.ar.vtt');
        expect(output.readAsStringSync(), contains(expected));
      },
      skip: which.exitCode != 0 ? 'yt-dlp not on PATH' : false,
    );
  }
}
