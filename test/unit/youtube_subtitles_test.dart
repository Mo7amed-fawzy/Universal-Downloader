import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/audio_format.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/subtitle_track.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/process/process_runner.dart';
import 'package:universal_downloader/core/process/process_runner_result.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/core/utils/path_utils.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/youtube/youtube_extractor.dart';
import 'package:universal_downloader/providers/youtube/youtube_format_mapper.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';

const uploaded = SubtitleTrack(language: 'en-US', extension: 'vtt');
const automatic = SubtitleTrack(
  language: 'ar',
  extension: 'vtt',
  isAutomatic: true,
);

void main() {
  final url = Uri.parse('https://www.youtube.com/watch?v=test');
  const mapper = YoutubeFormatMapper();

  group('subtitle metadata', () {
    test(
      'distinguishes translated captions from original-language captions',
      () {
        final info = mapper.fromJson({
          'automatic_captions': {
            'ar': [
              {
                'ext': 'vtt',
                'url': 'https://example.com/captions?lang=en&tlang=ar',
              },
            ],
            'en': [
              {'ext': 'vtt', 'url': 'https://example.com/captions?lang=en'},
            ],
          },
        }, url);
        final arabic = info.subtitleTracks.firstWhere(
          (t) => t.language == 'ar',
        );
        final english = info.subtitleTracks.firstWhere(
          (t) => t.language == 'en',
        );
        expect(arabic.isTranslated, isTrue);
        expect(arabic.label, contains('auto-translated'));
        expect(english.isTranslated, isFalse);
      },
    );
    test('keeps exact languages, source types and one supported format', () {
      final info = mapper.fromJson({
        'subtitles': {
          'en-US': [
            {'ext': 'srt', 'url': 'https://example.com/en.srt'},
            {
              'ext': 'vtt',
              'url': 'https://example.com/en.vtt',
              'name': 'English',
            },
            {'ext': 'vtt', 'url': 'https://example.com/en2.vtt'},
          ],
          'ar': [
            {'ext': 'srt', 'url': 'https://example.com/ar.srt'},
          ],
        },
        'automatic_captions': {
          'en-US': [
            {'ext': 'vtt', 'url': 'https://example.com/auto.vtt'},
          ],
        },
      }, url);
      expect(info.subtitleTracks, hasLength(3));
      final english = info.subtitleTracks.where((t) => t.language == 'en-US');
      expect(english.map((t) => t.id).toSet(), {
        'uploaded:en-US',
        'automatic:en-US',
      });
      expect(english.every((t) => t.extension == 'vtt'), isTrue);
      expect(english.first.name, 'English');
      expect(english.last.label, contains('automatic'));
      expect(info.subtitleTracks.first.extension, 'srt');
    });

    test('ignores live chat, malformed entries and unavailable tracks', () {
      final info = mapper.fromJson({
        'subtitles': {
          'live_chat': [
            {'ext': 'vtt', 'url': 'https://example.com/chat'},
          ],
          '../../bad': [
            {'ext': 'vtt', 'url': 'https://example.com/bad'},
          ],
          'all,ar': [
            {'ext': 'vtt', 'url': 'https://example.com/bad'},
          ],
          'en': null,
          'ar': [],
          'de': [
            null,
            {'ext': 'vtt'},
            {'ext': 'vtt', 'url': 'file:///tmp/a'},
          ],
          'fr': [
            {'ext': 'json3', 'url': 'https://example.com/a'},
          ],
        },
        'automatic_captions': 'invalid',
      }, url);
      expect(info.subtitleTracks, isEmpty);
      expect(mapper.fromJson({}, url).subtitleTracks, isEmpty);
    });

    test('preserves subtitles when HLS audio is added', () {
      final info = MediaInfo(
        id: 'test',
        title: 'Test',
        providerId: 'youtube',
        providerName: 'YouTube',
        pageUrl: url,
        subtitleTracks: [uploaded],
      );
      final merged = mapper.mergeM3u8Progressives(info, [
        const M3u8Progressive(formatId: 'hls', ext: 'mp4', language: 'ar'),
      ]);
      expect(merged.subtitleTracks, [uploaded]);
    });
  });

  group('subtitle download pipeline', () {
    late Directory root;
    late DownloadRepository repository;
    late SubtitleProcessRunner runner;
    late YoutubeProvider provider;
    late List<DownloadTaskState> phases;

    setUp(() {
      root = Directory.systemTemp.createTempSync('subtitle_test_');
      final paths = SubtitleTestPaths(root);
      repository = DownloadRepository(paths: paths);
      runner = SubtitleProcessRunner();
      provider = YoutubeProvider(
        ytDlpPath: 'yt-dlp',
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
        runner: runner,
        repository: repository,
        log: LogService(paths: paths),
      );
      phases = [];
    });

    tearDown(() => root.deleteSync(recursive: true));

    Future<File> download({
      SubtitleTrack? subtitle,
      bool separateAudio = false,
      bool hls = false,
      bool cover = false,
      String container = 'mp4',
      CancelToken? token,
    }) async {
      final result = await provider.download(
        MediaInfo(
          id: 'test',
          title: 'Video',
          providerId: 'youtube',
          providerName: 'YouTube',
          pageUrl: url,
          thumbnail: cover ? Uri.parse('https://example.com/cover.webp') : null,
          videoFormats: [
            VideoFormat(
              formatId: 'video',
              container: container,
              codec: 'avc1',
              height: 720,
              videoOnly: separateAudio,
              hasAudio: !separateAudio,
            ),
          ],
          audioFormats: [
            AudioFormat(
              formatId: 'audio',
              codec: 'mp4a',
              language: 'ar',
              progressiveFormatId: hls ? 'hls-stream' : null,
            ),
          ],
          subtitleTracks: const [uploaded, automatic],
        ),
        DownloadOptions(
          taskId: 'task',
          outputDirectory: root.path,
          title: 'Video',
          videoFormatId: 'video',
          subtitle: subtitle,
          audioFormatId: separateAudio || hls ? 'audio' : null,
          audioLanguage: 'ar',
        ),
        onPhase: phases.add,
        onProgress: (_) {},
        cancelToken: token ?? CancelToken(),
      );
      return result.outputFile;
    }

    test('None downloads no subtitles, overriding subtitle extras', () async {
      provider.setExtraYtDlpArgs('--write-subs --write-auto-subs --embed-subs');
      final output = await download();
      expect(output.existsSync(), isTrue);
      expect(
        runner.calls.where((args) => args.contains('--sub-langs')),
        isEmpty,
      );
      final stream = runner.calls.first;
      expect(
        stream.lastIndexOf('--no-write-subs'),
        greaterThan(stream.indexOf('--write-subs')),
      );
      expect(
        stream.lastIndexOf('--no-write-auto-subs'),
        greaterThan(stream.indexOf('--write-auto-subs')),
      );
      expect(
        stream.lastIndexOf('--no-embed-subs'),
        greaterThan(stream.indexOf('--embed-subs')),
      );
      expect(phases, isNot(contains(DownloadTaskState.downloadingSubtitles)));
    });

    for (final mode in ['dash', 'combined', 'hls', 'webm']) {
      test('$mode embeds the cover and preserves selected subtitles', () async {
        final output = await download(
          cover: true,
          subtitle: automatic,
          separateAudio: mode == 'dash',
          hls: mode == 'hls',
          container: mode == 'webm' ? 'webm' : 'mp4',
        );
        expect(phases.first, DownloadTaskState.downloadingCover);
        expect(DownloadTaskState.downloadingCover.isActive, isTrue);
        expect(phases, contains(DownloadTaskState.merging));
        final mux = runner.calls.singleWhere(
          (args) => args.contains('attached_pic') || args.contains('-attach'),
        );
        expect(mux, contains('copy'));
        expect(output.path, endsWith(mode == 'webm' ? '.mkv' : '.mp4'));
        expect(File('${root.path}/Video.ar.vtt').existsSync(), isTrue);
      });
    }

    test(
      'translated captions wait in yt-dlp and then report downloading',
      () async {
        await download(
          subtitle: const SubtitleTrack(
            language: 'ar',
            extension: 'vtt',
            isAutomatic: true,
            isTranslated: true,
          ),
        );
        final args = runner.calls.first;
        expect(args[args.indexOf('--sleep-subtitles') + 1], '60');
        expect(
          args[args.indexOf('-o') + 1],
          '${repository.createTaskDirectory('task').path}/subtitles.%(ext)s',
        );
        expect(phases.take(2), [
          DownloadTaskState.waitingForSubtitles,
          DownloadTaskState.downloadingSubtitles,
        ]);
        expect(DownloadTaskState.waitingForSubtitles.isActive, isTrue);
      },
    );

    test(
      'rate limiting exposes HTTP 429 instead of a generic failure',
      () async {
        runner.subtitleFailure = 'error';
        await expectLater(
          download(subtitle: automatic),
          throwsA(
            isA<DownloadFailedException>().having(
              (e) => e.message,
              'message',
              contains('HTTP 429'),
            ),
          ),
        );
      },
    );

    for (final track in [uploaded, automatic]) {
      test('downloads ${track.id} beside the uniquely named video', () async {
        File('${root.path}/Video.mp4').writeAsStringSync('existing');
        final output = await download(subtitle: track, separateAudio: true);
        expect(output.path, '${root.path}/Video (1).mp4');
        final subtitle = File('${root.path}/Video (1).${track.language}.vtt');
        expect(subtitle.readAsStringSync(), startsWith('WEBVTT'));
        final args = runner.calls.first;
        expect(args, isNot(contains('--sleep-subtitles')));
        expect(args, contains('--skip-download'));
        expect(
          args[args.indexOf('--sub-langs') + 1],
          '-all,^${track.language}\$',
        );
        expect(
          args,
          contains(track.isAutomatic ? '--no-write-subs' : '--write-subs'),
        );
        expect(
          args,
          contains(
            track.isAutomatic ? '--write-auto-subs' : '--no-write-auto-subs',
          ),
        );
        expect(phases.first, DownloadTaskState.downloadingSubtitles);
        expect(phases, contains(DownloadTaskState.merging));
        expect(
          Directory('${root.path}/temp/download_task_task').existsSync(),
          isFalse,
        );
      });
    }

    test('also saves selected subtitles for HLS combined streams', () async {
      await download(subtitle: automatic, hls: true);
      expect(File('${root.path}/Video.ar.vtt').existsSync(), isTrue);
      expect(runner.calls[1], contains('hls-stream'));
      expect(phases, isNot(contains(DownloadTaskState.merging)));
    });

    for (final mode in ['error', 'missing', 'empty']) {
      test(
        'fails rather than silently completing with $mode subtitles',
        () async {
          runner.subtitleFailure = mode;
          await expectLater(
            download(subtitle: uploaded),
            throwsA(isA<DownloadFailedException>()),
          );
          expect(runner.calls, hasLength(1));
          expect(File('${root.path}/Video.mp4').existsSync(), isFalse);
        },
      );
    }

    test('rejects a selection absent from fetched metadata', () async {
      await expectLater(
        download(
          subtitle: const SubtitleTrack(language: 'fr', extension: 'vtt'),
        ),
        throwsA(isA<DownloadFailedException>()),
      );
      expect(runner.calls, isEmpty);
    });

    test('cancellation during subtitles prevents the media download', () async {
      runner.cancelSubtitles = true;
      await expectLater(
        download(subtitle: automatic),
        throwsA(isA<DownloadCancelledException>()),
      );
      expect(runner.calls, hasLength(1));
      expect(phases, [DownloadTaskState.downloadingSubtitles]);
    });

    test('does not overwrite an unrelated subtitle file', () async {
      final existing = File('${root.path}/Video.ar.vtt')
        ..writeAsStringSync('existing');
      await expectLater(
        download(subtitle: automatic),
        throwsA(isA<FilesystemException>()),
      );
      expect(existing.readAsStringSync(), 'existing');
    });

    test(
      'verification failure retains temporary subtitles for retry',
      () async {
        runner.verificationFails = true;
        await expectLater(
          download(subtitle: automatic),
          throwsA(isA<VerificationException>()),
        );
        expect(File('${root.path}/Video.ar.vtt').existsSync(), isFalse);
        expect(
          File(
            '${repository.createTaskDirectory('task').path}/subtitles.ar.vtt',
          ).existsSync(),
          isTrue,
        );
      },
    );
  });
}

class SubtitleTestPaths extends PathUtils {
  const SubtitleTestPaths(this.root);
  final Directory root;

  @override
  Directory appDataDirectory() => root;
}

class SubtitleProcessRunner extends ProcessRunner {
  final List<List<String>> calls = [];
  String? subtitleFailure;
  bool cancelSubtitles = false;
  bool verificationFails = false;

  @override
  Future<ProcessRunnerResult> run({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
    void Function(String line, bool isStdout)? onLine,
    CancelToken? cancelToken,
    String? workingDirectory,
  }) async {
    calls.add(arguments);
    if (arguments.contains('--sub-langs')) {
      if (cancelSubtitles) cancelToken!.cancel();
      cancelToken?.throwIfCancelled();
      if (subtitleFailure == 'error') {
        return const ProcessRunnerResult(
          exitCode: 1,
          stdout: '',
          stderr: 'HTTP 429',
        );
      }
      if (subtitleFailure != 'missing') {
        final language = arguments[arguments.lastIndexOf('--sub-langs') + 1]
            .split(',')
            .last;
        final code = language.substring(1, language.length - 1);
        final extension = arguments[arguments.indexOf('--sub-format') + 1];
        final template = arguments[arguments.lastIndexOf('-o') + 1].substring(
          'subtitle:'.length,
        );
        final path = template
            .replaceAll('%(ext)s', '$code.$extension')
            .replaceAll('%%', '%');
        File(path).writeAsStringSync(
          subtitleFailure == 'empty'
              ? ''
              : 'WEBVTT\n\n00:00.000 --> 00:01.000\nHello\n',
        );
        onLine?.call('[download] Sleeping 60.00 seconds ...', true);
        onLine?.call('[download] Destination: $path', true);
        onLine?.call('[download] 100%', true);
      }
    } else if (executable == 'ffprobe') {
      final hasCover = calls.any(
        (args) => args.contains('attached_pic') || args.contains('-attach'),
      );
      return ProcessRunnerResult(
        exitCode: verificationFails ? 1 : 0,
        stdout:
            '{"streams":[{"codec_type":"video","height":720},{"codec_type":"audio","tags":{"language":"ar"}}'
            '${hasCover ? ',{"codec_type":"video","height":1080,"disposition":{"attached_pic":1}}' : ''}],"format":{"size":100}}',
        stderr: '',
      );
    } else {
      final path = executable == 'ffmpeg'
          ? arguments.last
          : arguments[arguments.indexOf('-o') + 1];
      File(path).writeAsStringSync('media');
    }
    return const ProcessRunnerResult(exitCode: 0, stdout: '', stderr: '');
  }
}
