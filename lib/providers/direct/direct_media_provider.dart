import 'dart:io';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/models/audio_format.dart';
import '../../core/models/audio_output_format.dart';
import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/models/video_format.dart';
import '../../core/process/cancel_token.dart';
import '../../core/process/command_runner.dart';
import '../../core/process/process_runner.dart';
import '../../core/services/audio_exporter.dart';
import '../../core/services/audio_stem_processor.dart';
import '../../core/services/log_service.dart';
import '../../core/services/media_assembler.dart';
import '../../core/services/media_file_publisher.dart';
import '../../core/tools/media_tools.dart';
import '../../downloads/download_repository.dart';
import '../../downloads/download_task_state.dart';
import '../downloader_provider.dart';
import '../tool_configurable_provider.dart';
import 'direct_file_downloader.dart';

/// Handles direct media URLs (e.g. https://example.com/video.mp4) without a
/// site-specific extractor, by streaming the file over HTTP.
class DirectMediaProvider
    implements DownloaderProvider, ToolConfigurableProvider {
  DirectMediaProvider({
    required this.ffprobePath,
    this.ffmpegPath = 'ffmpeg',
    CommandRunner? runner,
    DownloadRepository? repository,
    LogService? log,
  }) : runner = runner ?? const ProcessRunner(),
       repository = repository ?? DownloadRepository(),
       log = log ?? LogService();

  final CommandRunner runner;
  String ffprobePath;
  String ffmpegPath;
  final DownloadRepository repository;
  final LogService log;

  @override
  void configureTools(MediaTools tools) {
    ffprobePath = tools.ffprobe;
    ffmpegPath = tools.ffmpeg;
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
    cancelToken.throwIfCancelled();
    final recovered = await repository.loadVerifiedResult(taskId);
    if (recovered != null) return recovered;
    final tempDir = repository.createTaskDirectory(taskId);
    final tmpFile = File('${tempDir.path}/direct.tmp');

    try {
      if (options.audioOutputFormat != null && options.isMuted) {
        throw DownloadFailedException('No audio remains to export.');
      }
      final stemProcessor = AudioStemProcessor(runner: runner);
      if (options.needsAudioProcessing && !options.isMuted) {
        await stemProcessor.ensureAvailable(cancelToken);
      }
      onPhase(
        options.audioOutputFormat == null
            ? DownloadTaskState.downloadingVideo
            : DownloadTaskState.downloadingAudio,
      );
      log.info('Downloading direct file from ${media.pageUrl}');
      await const DirectFileDownloader().download(
        media.pageUrl,
        tmpFile,
        onProgress,
        cancelToken,
      );

      if (options.audioOutputFormat case final format?) {
        var source = tmpFile;
        if (options.needsAudioProcessing) {
          onPhase(DownloadTaskState.processingAudio);
          source = await stemProcessor.process(
            source: source,
            workspace: tempDir,
            ffmpegPath: ffmpegPath,
            options: options,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        }
        onPhase(DownloadTaskState.processingAudio);
        final exported =
            await AudioExporter(ffmpegPath: ffmpegPath, runner: runner).export(
              source: source,
              workspace: tempDir,
              format: format,
              cancelToken: cancelToken,
            );
        onPhase(DownloadTaskState.verifying);
        final assembler = MediaAssembler(
          ffmpegPath: ffmpegPath,
          ffprobePath: ffprobePath,
          runner: runner,
        );
        final report = await assembler.verify(exported, expectVideo: false);
        if (!report.passed) {
          throw VerificationException(
            'The audio file failed verification.',
            details: report.failures.join('\n'),
          );
        }
        final outputPath = repository.buildUniqueOutputPath(
          outputDirectory: options.outputDirectory,
          baseName: options.title,
          extension: format.id,
          overwrite: options.overwrite,
        );
        final outputFile = await const MediaFilePublisher().publish(
          exported,
          outputPath,
          cancelToken,
        );
        final result = DownloadTaskResult(outputFile: outputFile, merged: true);
        await repository.saveVerifiedResult(taskId, result);
        return result;
      }

      final ext = media.videoFormats.isEmpty
          ? 'mp4'
          : (media.videoFormats.first.container ?? 'mp4');
      final outputPath = repository.buildUniqueOutputPath(
        outputDirectory: options.outputDirectory,
        baseName: options.title,
        extension:
            options.needsAudioProcessing && !options.isMuted && ext != 'mp4'
            ? 'mkv'
            : ext,
        overwrite: options.overwrite,
      );
      final assembler = MediaAssembler(
        ffmpegPath: ffmpegPath,
        ffprobePath: ffprobePath,
        runner: runner,
      );
      var mediaFile = tmpFile;
      if (options.needsAudioProcessing) {
        onPhase(DownloadTaskState.merging);
        final processedExtension = options.isMuted
            ? ext
            : ext == 'mp4'
            ? 'mp4'
            : 'mkv';
        final processed = '${tempDir.path}/processed.$processedExtension';
        if (options.isMuted) {
          mediaFile = await assembler.merge(
            tmpFile,
            null,
            processed,
            cancelToken: cancelToken,
            includeAudio: false,
          );
        } else {
          final source = await assembler.merge(
            tmpFile,
            null,
            '${tempDir.path}/source.$processedExtension',
            cancelToken: cancelToken,
          );
          onPhase(DownloadTaskState.processingAudio);
          final selectedAudio = await stemProcessor.process(
            source: source,
            workspace: tempDir,
            ffmpegPath: ffmpegPath,
            options: options,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
          onPhase(DownloadTaskState.merging);
          mediaFile = await assembler.merge(
            source,
            selectedAudio,
            processed,
            cancelToken: cancelToken,
          );
        }
      }
      onPhase(DownloadTaskState.verifying);
      final report = await assembler.verify(
        mediaFile,
        expectAudio: !options.isMuted,
      );
      if (!report.passed) {
        throw VerificationException(
          'The downloaded file failed verification. It was kept for inspection.',
          details: report.failures.join('\n'),
        );
      }

      cancelToken.throwIfCancelled();
      final outputFile = await const MediaFilePublisher().publish(
        mediaFile,
        outputPath,
        cancelToken,
      );
      log.info('Direct download completed: ${outputFile.path}');
      final result = DownloadTaskResult(
        outputFile: outputFile,
        merged: options.needsAudioProcessing,
      );
      await repository.saveVerifiedResult(taskId, result);
      return result;
    } catch (e) {
      if (e is DownloadCancelledException) {
        log.info('Direct download cancelled (task $taskId)');
        rethrow;
      }
      log.error('Direct download failed (task $taskId): $e');
      rethrow;
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
