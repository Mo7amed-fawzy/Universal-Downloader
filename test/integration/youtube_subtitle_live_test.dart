import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/providers/youtube/youtube_extractor.dart';
import 'package:universal_downloader/providers/youtube/youtube_format_mapper.dart';
import 'package:universal_downloader/providers/youtube/youtube_subtitle_downloader.dart';

void main() {
  test(
    'downloads Arabic translated captions for the reported YouTube video',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'youtube_arabic_subtitles_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final url = Uri.parse('https://youtu.be/vNwCw6uVyTg');
      final json = await YoutubeExtractor(ytDlpPath: 'yt-dlp').extractJson(url);
      final info = const YoutubeFormatMapper().fromJson(json, url);
      final track = info.subtitleTracks.firstWhere(
        (track) => track.language == 'ar' && track.isAutomatic,
      );
      expect(track.isTranslated, isTrue);
      var started = false;
      final file =
          await const YoutubeSubtitleDownloader(
            ytDlpPath: 'yt-dlp',
            runner: ProcessRunner(),
          ).download(
            url: url,
            track: track,
            directory: root,
            cancelToken: CancelToken(),
            onDownloadStarted: () => started = true,
          );
      final contents = file.readAsStringSync();
      expect(started, isTrue);
      expect(contents, startsWith('WEBVTT'));
      expect(contents, contains('Language: ar'));
      expect(contents, contains('-->'));
      expect(RegExp(r'[\u0600-\u06ff]').hasMatch(contents), isTrue);
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_SUBTITLE_TEST')
        ? 'Opt in with --dart-define=RUN_LIVE_SUBTITLE_TEST=true'
        : false,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
