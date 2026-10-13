import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/core/tools/media_tools.dart';
import 'package:universal_downloader/downloads/download_repository.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';

import 'package:universal_downloader/core/storage/app_database.dart';
import 'package:universal_downloader/downloads/download_history.dart';
import 'package:universal_downloader/downloads/download_manager.dart';
import 'package:universal_downloader/downloads/download_recovery_store.dart';
import 'package:universal_downloader/downloads/download_task.dart';
import 'package:universal_downloader/downloads/download_task_state.dart';
import 'package:universal_downloader/providers/provider_registry.dart';

import '../support/controlled_download_provider.dart';

void main() {
  for (final stopMode in ['provider interruption', 'pause', 'shutdown']) {
    test(
      'real yt-dlp resumes after $stopMode with identical output bytes',
      () async {
        for (final tool in ['yt-dlp', 'ffmpeg', 'ffprobe']) {
          expect(
            (await Process.run('which', [tool])).exitCode,
            0,
            reason: '$tool must be installed',
          );
        }
        final root = Directory.systemTemp.createTempSync('real_resume_');
        addTearDown(() => root.deleteSync(recursive: true));
        final sample = File('${root.path}/source.mp4');
        final generated = await Process.run('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'lavfi',
          '-i',
          'testsrc2=size=640x360:rate=30',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=440',
          '-t',
          '8',
          '-c:v',
          'mpeg4',
          '-q:v',
          '3',
          '-c:a',
          'aac',
          '-movflags',
          '+faststart',
          sample.path,
        ]);
        expect(generated.exitCode, 0, reason: '${generated.stderr}');
        final bytes = await sample.readAsBytes();
        expect(bytes.length, greaterThan(65536));
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final ranges = <int>[];
        var throttled = true;
        server.listen((request) async {
          final header = request.headers.value('range');
          final start = header == null
              ? 0
              : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(header)![1]!);
          ranges.add(start);
          request.response.headers.set('content-type', 'video/mp4');
          request.response.headers.set('accept-ranges', 'bytes');
          if (start > 0) {
            request.response.statusCode = 206;
            request.response.headers.set(
              'content-range',
              'bytes $start-${bytes.length - 1}/${bytes.length}',
            );
          }
          request.response.contentLength = bytes.length - start;
          try {
            for (var offset = start; offset < bytes.length; offset += 16384) {
              final end = (offset + 16384).clamp(0, bytes.length);
              request.response.add(bytes.sublist(offset, end));
              await request.response.flush();
              if (throttled) {
                await Future<void>.delayed(const Duration(milliseconds: 10));
              }
            }
            await request.response.close();
          } on IOException {
            request.response.close().ignore();
          }
        });
        final url = Uri.parse('http://127.0.0.1:${server.port}/source.mp4');
        final info = File('${root.path}/info.json');
        await info.writeAsString(
          jsonEncode({
            'id': 'local',
            'title': 'Local resume',
            'extractor': 'generic',
            'extractor_key': 'Generic',
            'webpage_url': '$url',
            'formats': [
              {
                'format_id': 'local',
                'url': '$url',
                'ext': 'mp4',
                'vcodec': 'mpeg4',
                'acodec': 'aac',
                'height': 360,
              },
            ],
          }),
        );
        final paths = QueueTestPaths(root);
        final repository = DownloadRepository(paths: paths);
        YoutubeProvider provider() =>
            YoutubeProvider(
              ytDlpPath: 'yt-dlp',
              ffmpegPath: 'ffmpeg',
              ffprobePath: 'ffprobe',
              repository: repository,
              log: LogService(paths: paths),
            )..configureTools(
              MediaTools(
                ytDlp: 'yt-dlp',
                ffmpeg: 'ffmpeg',
                ffprobe: 'ffprobe',
                ytDlpArguments: [
                  '--ignore-config',
                  '--no-remote-components',
                  '--load-info-json',
                  info.path,
                ],
              ),
            );
        final media = MediaInfo(
          id: 'local',
          title: 'Local resume',
          providerId: 'youtube',
          providerName: 'YouTube',
          pageUrl: url,
          videoFormats: const [
            VideoFormat(
              formatId: 'local',
              container: 'mp4',
              height: 360,
              hasAudio: true,
              videoOnly: false,
            ),
          ],
        );
        final options = DownloadOptions(
          taskId: 'resume',
          outputDirectory: root.path,
          title: 'Recovered',
          videoFormatId: 'local',
        );
        if (stopMode == 'provider interruption') {
          final token = CancelToken();
          await expectLater(
            provider().download(
              media,
              options,
              onPhase: (_) {},
              onProgress: (progress) {
                if ((progress.downloadedBytes ?? 0) >= 65536) token.cancel();
              },
              cancelToken: token,
            ),
            throwsA(isA<DownloadCancelledException>()),
          );
          final parts = repository
              .createTaskDirectory('resume')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.part'))
              .toList();
          expect(parts, hasLength(1));
          final preservedBytes = await parts.single.length();
          expect(preservedBytes, greaterThan(0));
          expect(preservedBytes, lessThan(bytes.length));
          throttled = false;
          final result = await provider().download(
            media,
            options,
            onPhase: (_) {},
            onProgress: (_) {},
            cancelToken: CancelToken(),
          );
          expect(ranges.any((offset) => offset > 0), isTrue);
          expect(
            sha256.convert(await result.outputFile.readAsBytes()),
            sha256.convert(bytes),
          );
          final requestCount = ranges.length;
          final recovered = await provider().download(
            media,
            options,
            onPhase: (_) {},
            onProgress: (_) {},
            cancelToken: CancelToken(),
          );
          expect(recovered.outputFile.path, result.outputFile.path);
          expect(ranges, hasLength(requestCount));
        } else {
          var database = AppDatabase.open(paths);
          addTearDown(() => database.close());
          DownloadManager createManager() => DownloadManager(
            registry: ProviderRegistry([provider()]),
            repository: repository,
            log: LogService(paths: paths),
            recovery: DownloadRecoveryStore(database),
            history: DownloadHistory(database),
          );
          var downloads = createManager();
          addTearDown(() async {
            await downloads.shutdown();
            downloads.dispose();
          });
          downloads.add(
            provider: downloads.registry.byId('youtube')!,
            media: media,
            options: options,
            videoLabel: '360p',
            audioLabel: 'Original',
          );
          final task = downloads.tasks.single;
          final interrupted = Completer<void>();
          Future<void>? closing;
          void interrupt() {
            if (interrupted.isCompleted ||
                (task.progress.downloadedBytes ?? 0) < 65536) {
              return;
            }
            interrupted.complete();
            if (stopMode == 'pause') {
              downloads.pause(task.id);
            } else {
              closing = downloads.shutdown();
            }
          }

          task.addListener(interrupt);
          await interrupted.future.timeout(const Duration(seconds: 40));
          task.removeListener(interrupt);
          if (stopMode == 'pause') {
            await waitForState(task, DownloadTaskState.paused);
          } else {
            await closing;
          }
          final parts = repository
              .createTaskDirectory('resume')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.part'))
              .toList();
          expect(parts, hasLength(1));
          expect(
            await parts.single.length(),
            inExclusiveRange(0, bytes.length),
          );
          expect(await DownloadRecoveryStore(database).load(), hasLength(1));
          if (stopMode == 'shutdown') {
            downloads.dispose();
            await database.close();
            database = AppDatabase.open(paths);
            downloads = createManager();
            await downloads.restoreHistory();
            expect(downloads.tasks.single.state, DownloadTaskState.interrupted);
            expect(downloads.activeCount, 0);
          }
          throttled = false;
          await downloads.retry('resume');
          await waitForState(
            downloads.tasks.single,
            DownloadTaskState.completed,
          );
          await downloads.shutdown();
          expect(ranges.any((offset) => offset > 0), isTrue);
          expect(
            sha256.convert(
              await File(downloads.tasks.single.outputPath!).readAsBytes(),
            ),
            sha256.convert(bytes),
          );
          expect(await DownloadRecoveryStore(database).load(), isEmpty);
          expect(await DownloadHistory(database).load(), hasLength(1));
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

Future<void> waitForState(DownloadTask task, DownloadTaskState state) async {
  if (task.state == state) return;
  final reached = Completer<void>();
  void check() {
    if (task.state == state && !reached.isCompleted) reached.complete();
  }

  task.addListener(check);
  try {
    await reached.future.timeout(const Duration(seconds: 40));
  } finally {
    task.removeListener(check);
  }
}
