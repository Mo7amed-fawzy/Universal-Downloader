import 'dart:io';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/models/audio_format.dart';
import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/models/video_format.dart';
import '../../core/process/cancel_token.dart';
import '../../core/process/command_runner.dart';
import '../../core/process/process_runner.dart';
import '../../core/services/log_service.dart';
import '../../core/services/media_assembler.dart';
import '../../core/tools/media_tools.dart';
import '../../downloads/download_progress.dart';
import '../../downloads/download_repository.dart';
import '../../downloads/download_task_state.dart';
import '../downloader_provider.dart';
import '../tool_configurable_provider.dart';

/// Handles direct media URLs (e.g. https://example.com/video.mp4) without a
/// site-specific extractor, by streaming the file over HTTP.
class DirectMediaProvider
    implements DownloaderProvider, ToolConfigurableProvider {
  DirectMediaProvider({
    required this.ffprobePath,
    CommandRunner? runner,
    DownloadRepository? repository,
    LogService? log,
  }) : runner = runner ?? const ProcessRunner(),
       repository = repository ?? DownloadRepository(),
       log = log ?? LogService();

  final CommandRunner runner;
  String ffprobePath;
  final DownloadRepository repository;
  final LogService log;

  @override
  void configureTools(MediaTools tools) {
    ffprobePath = tools.ffprobe;
  }

  @override
  String get id => 'direct';

  @override
  String get displayName => 'Direct URL';

  static const List<String> _mediaExtensions = [
    '.mp4',
    '.mkv',
    '.webm',
    '.mov',
    '.m4v',
    '.avi',
    '.flv',
    '.ts',
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.wma',
    '.3gp',
  ];

  @override
  bool canHandle(Uri url) {
    final scheme = url.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    final path = url.path.toLowerCase();
    return _mediaExtensions.any(path.endsWith);
  }

  @override
  Future<MediaInfo> fetchInfo(Uri url) async {
    log.info('Probing direct URL $url');
    var contentLength = 0;
    String? mimeType;
    String? suggestedName;

    try {
      final client = HttpClient()..autoUncompress = false;
      try {
        final request = await client.headUrl(url);
        request.followRedirects = true;
        request.maxRedirects = 5;
        final response = await request.close();
        contentLength = response.contentLength > 0 ? response.contentLength : 0;
        mimeType = response.headers.contentType?.mimeType;
        suggestedName = _contentDispositionFilename(
          response.headers.value('content-disposition'),
        );
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      throw NetworkException(
        'Could not reach the direct media URL.',
        details: e.toString(),
      );
    }

    final name = suggestedName ?? _filenameFromUrl(url);
    final ext = _extensionFromUrl(url);
    final formatId = 'direct';

    return MediaInfo(
      id: 'direct',
      title: name,
      providerId: id,
      providerName: displayName,
      pageUrl: url,
      videoFormats: [
        VideoFormat(
          formatId: formatId,
          container: ext,
          note: mimeType ?? 'Direct media',
          filesize: contentLength > 0 ? contentLength : null,
          videoOnly: false,
          hasAudio: true,
        ),
      ],
      audioFormats: const <AudioFormat>[],
    );
  }

  @override
  Future<DownloadTaskResult> download(
    MediaInfo media,
    DownloadOptions options, {
    required PhaseCallback onPhase,
    required ProgressCallback onProgress,
    required CancelToken cancelToken,
  }) async {
    final taskId = options.taskId;
    final tempDir = repository.createTaskDirectory(taskId);
    final tmpFile = File('${tempDir.path}/direct.tmp');

    try {
      onPhase(DownloadTaskState.downloadingVideo);
      log.info('Downloading direct file from ${media.pageUrl}');
      await _streamDownload(media.pageUrl, tmpFile, onProgress, cancelToken);

      onPhase(DownloadTaskState.verifying);
      final ext = media.videoFormats.isEmpty
          ? 'mp4'
          : (media.videoFormats.first.container ?? 'mp4');
      final outputPath = repository.buildUniqueOutputPath(
        outputDirectory: options.outputDirectory,
        baseName: options.title,
        extension: ext,
        overwrite: options.overwrite,
      );
      log.info('Moving to $outputPath');
      if (File(outputPath).existsSync()) File(outputPath).deleteSync();
      tmpFile.renameSync(outputPath);
      final outputFile = File(outputPath);

      final assembler = MediaAssembler(
        ffmpegPath: '/nonexistent',
        ffprobePath: ffprobePath,
        runner: runner,
      );
      final report = await assembler.verify(outputFile);
      if (!report.passed) {
        throw VerificationException(
          'The downloaded file failed verification. It was kept for inspection.',
          details: report.failures.join('\n'),
        );
      }

      log.info('Direct download completed: ${outputFile.path}');
      repository.cleanupTaskDirectory(taskId);
      return DownloadTaskResult(outputFile: outputFile, merged: false);
    } catch (e) {
      if (e is DownloadCancelledException) {
        log.info('Direct download cancelled (task $taskId)');
        rethrow;
      }
      log.error('Direct download failed (task $taskId): $e');
      rethrow;
    }
  }

  Future<void> _streamDownload(
    Uri url,
    File output,
    ProgressCallback onProgress,
    CancelToken cancelToken,
  ) async {
    final client = HttpClient()..autoUncompress = false;
    try {
      final request = await client.getUrl(url);
      request.followRedirects = true;
      request.maxRedirects = 5;

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NetworkException(
          'Server returned HTTP ${response.statusCode} for the media URL.',
        );
      }

      final total = response.contentLength > 0 ? response.contentLength : null;
      final sink = output.openWrite();
      var downloaded = 0;

      try {
        await for (final chunk in response) {
          cancelToken.throwIfCancelled();
          sink.add(chunk);
          downloaded += chunk.length;
          onProgress(
            DownloadProgress(
              percent: total == null ? null : (downloaded / total) * 100,
              downloadedBytes: downloaded,
              totalBytes: total,
            ),
          );
        }
      } finally {
        await sink.close();
      }

      if (cancelToken.isCancelled) {
        throw DownloadCancelledException();
      }
    } finally {
      client.close(force: true);
    }
  }

  static String _filenameFromUrl(Uri url) {
    final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final last = segments.last;
      final dot = last.lastIndexOf('.');
      return dot > 0 ? last.substring(0, dot) : last;
    }
    return 'download';
  }

  static String _extensionFromUrl(Uri url) {
    final segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return 'mp4';
    final last = segments.last;
    final dot = last.lastIndexOf('.');
    if (dot < 0 || dot == last.length - 1) return 'mp4';
    final ext = last.substring(dot + 1);
    return _mediaExtensions.any((e) => e == '.$ext') ? ext : 'mp4';
  }

  static String? _contentDispositionFilename(String? header) {
    if (header == null) return null;
    // filename="x" or filename*=UTF-8''x
    final match = RegExp(
      r"""filename\*?=(?:UTF-8'')?"?([^";]+)""",
    ).firstMatch(header);
    return match?.group(1);
  }
}
