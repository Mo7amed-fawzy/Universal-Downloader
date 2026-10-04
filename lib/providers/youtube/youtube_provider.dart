import 'dart:convert';
import 'dart:io';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/process/cancel_token.dart';
import '../../core/process/process_runner.dart';
import '../../core/process/yt_dlp_progress_parser.dart';
import '../../core/services/log_service.dart';
import '../../core/services/media_assembler.dart';
import '../../downloads/download_repository.dart';
import '../../downloads/download_task_state.dart';
import '../downloader_provider.dart';
import 'youtube_cover_downloader.dart';
import 'youtube_extractor.dart';
import 'youtube_format_mapper.dart';
import 'youtube_subtitle_downloader.dart';

/// YouTube provider backed by yt-dlp.
class YoutubeProvider implements DownloaderProvider {
  YoutubeProvider({
    required this.ytDlpPath,
    required this.ffmpegPath,
    required this.ffprobePath,
    ProcessRunner? runner,
    DownloadRepository? repository,
    LogService? log,
  })  : _runner = runner ?? const ProcessRunner(),
        _repository = repository ?? DownloadRepository(),
        _log = log ?? LogService();

  final ProcessRunner _runner;
  final DownloadRepository _repository;
  final LogService _log;
  String ytDlpPath;
  String ffmpegPath;
  String ffprobePath;
  String _extraArgs = '';

  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube';

  /// Additional raw yt-dlp arguments from user settings (whitespace split).
  void setExtraYtDlpArgs(String value) => _extraArgs = value;

  List<String> get _extraArgList => _extraArgs.trim().isEmpty
      ? const []
      : _extraArgs.trim().split(RegExp(r'\s+'));

  MediaAssembler get _assembler => MediaAssembler(
        ffmpegPath: ffmpegPath,
        ffprobePath: ffprobePath,
        runner: _runner,
      );

  static const _progressParser = YtDlpProgressParser();

  @override
  bool canHandle(Uri url) {
    final host = url.host.toLowerCase();
    return host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'gaming.youtube.com' ||
        host == 'youtu.be' ||
        host == 'www.youtu.be' ||
        host == 'youtube-nocookie.com' ||
        host == 'www.youtube-nocookie.com';
  }

  @override
  Future<MediaInfo> fetchInfo(Uri url) async {
    _log.info('Fetching YouTube metadata for $url');
    final extractor = YoutubeExtractor(
      ytDlpPath: ytDlpPath,
      runner: _runner,
      extraArgs: _extraArgList,
    );
    final json = await extractor.extractJson(url);
    final mapper = const YoutubeFormatMapper();
    var info = mapper.fromJson(json, url);

    // Secondary pass: discover m3u8 progressive streams that
    // --dump-single-json never reports (HLS manifests are only fetched
    // during -F or actual downloads).
    try {
      final progressives = await extractor.listM3u8Progressives(url);
      if (progressives.isNotEmpty) {
        info = mapper.mergeM3u8Progressives(info, progressives);
        _log.info(
          'Merged ${progressives.length} m3u8 progressive formats',
        );
      }
    } catch (_) {
      // Non-fatal: fall back to DASH-only info.
    }

    _log.info(
      'YouTube metadata fetched: "${info.title}" '
      '(${info.videoFormats.length} video, '
      '${info.audioFormats.length} audio formats, '
      'languages: ${info.audioLanguages.join(', ')})',
    );
    return info;
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
    final tempDir = _repository.createTaskDirectory(taskId);
    final videoTmp = File('${tempDir.path}/video.tmp');

    // Check if the audio format is an m3u8 progressive stream.
    // Synthetic audio format ids start with "m3u8-" and carry the real
    // progressive format id in [AudioFormat.progressiveFormatId].
    final audioFormatId = options.audioFormatId;
    final audioFormat = audioFormatId != null
        ? media.audioFormatById(audioFormatId)
        : null;
    final progressiveId = audioFormat?.progressiveFormatId;

    final videoFormat = progressiveId != null
        ? null
        : media.videoFormatById(options.videoFormatId);

    File? audioTmp;
    try {
      File? coverTmp;
      final thumbnail = media.thumbnail;
      if (thumbnail != null) {
        onPhase(DownloadTaskState.downloadingCover);
        coverTmp =
            await YoutubeCoverDownloader(
              ffmpegPath: ffmpegPath,
              runner: _runner,
            ).download(
              url: thumbnail,
              directory: tempDir,
              cancelToken: cancelToken,
            );
      }
      File? subtitleTmp;
      final subtitle = options.subtitle;
      if (subtitle != null) {
        if (!media.subtitleTracks.any((track) =>
            track.id == subtitle.id && track.extension == subtitle.extension)) {
          throw DownloadFailedException(
            'The selected subtitles are unavailable. Fetch info again.',
          );
        }
        onPhase(subtitle.isTranslated
            ? DownloadTaskState.waitingForSubtitles
            : DownloadTaskState.downloadingSubtitles);
        subtitleTmp = await YoutubeSubtitleDownloader(
          ytDlpPath: ytDlpPath,
          runner: _runner,
          extraArgs: _extraArgList,
        ).download(
          url: media.pageUrl,
          track: subtitle,
          directory: tempDir,
          cancelToken: cancelToken,
          onDownloadStarted: () => onPhase(DownloadTaskState.downloadingSubtitles),
        );
      }
      if (progressiveId != null) {
        // m3u8 progressive: download the muxed stream directly as video.
        // Use tv_embedded — the same client that discovered these streams.
        cancelToken.throwIfCancelled();
        onPhase(DownloadTaskState.downloadingVideo);
        _log.info(
          'Downloading m3u8 progressive stream $progressiveId '
          '(video+audio muxed)',
        );
        await _downloadStream(
          media.pageUrl,
          progressiveId,
          videoTmp,
          cancelToken,
          onProgress,
          extractorArgs: YoutubeExtractor.hlsDownloadBaseArgs(),
        );
      } else {
        // DASH: download video + audio separately, then merge.
        final videoArgs = YoutubeExtractor.downloadBaseArgs();
        final audioArgs = YoutubeExtractor.downloadAudioBaseArgs();

        // 1. Download the selected video stream.
        cancelToken.throwIfCancelled();
        onPhase(DownloadTaskState.downloadingVideo);
        _log.info('Downloading video stream ${options.videoFormatId}');
        try {
          await _downloadStream(
            media.pageUrl,
            options.videoFormatId,
            videoTmp,
            cancelToken,
            onProgress,
            extractorArgs: videoArgs,
          );
        } on DownloadFailedException catch (e) {
          // Fallback: refresh metadata with download config and remap.
          _log.info('Video download failed, attempting format remap: $e');
          final remappedId = await _remapFormatId(
            url: media.pageUrl,
            originalFormatId: options.videoFormatId,
            targetHeight: videoFormat?.height,
            isVideo: true,
          );
          if (remappedId == null || remappedId == options.videoFormatId) rethrow;
          _log.info('Remapped video format ${options.videoFormatId} → $remappedId');
          await _downloadStream(
            media.pageUrl,
            remappedId,
            videoTmp,
            cancelToken,
            onProgress,
            extractorArgs: videoArgs,
          );
        }

        // 2. Download the selected audio stream.
        if (audioFormatId != null) {
          cancelToken.throwIfCancelled();
          onPhase(DownloadTaskState.downloadingAudio);
          _log.info('Downloading audio stream $audioFormatId');
          audioTmp = File('${tempDir.path}/audio.tmp');
          try {
            await _downloadStream(
              media.pageUrl,
              audioFormatId,
              audioTmp,
              cancelToken,
              onProgress,
              extractorArgs: audioArgs,
            );
          } on DownloadFailedException catch (e) {
            _log.info('Audio download failed, attempting format remap: $e');
            final remappedId = await _remapFormatId(
              url: media.pageUrl,
              originalFormatId: audioFormatId,
              targetLanguage: options.audioLanguage,
              isVideo: false,
            );
            if (remappedId == null || remappedId == audioFormatId) rethrow;
            _log.info('Remapped audio format $audioFormatId → $remappedId');
            await _downloadStream(
              media.pageUrl,
              remappedId,
              audioTmp,
              cancelToken,
              onProgress,
              extractorArgs: audioArgs,
            );
          }
        }
      }

      File outputFile;
      if (audioTmp != null) {
        // 3. Merge with ffmpeg using stream copy.
        cancelToken.throwIfCancelled();
        onPhase(DownloadTaskState.merging);
        _log.info('Merging video + audio with ffmpeg (stream copy)');

        final mergeAudioFormat = media.audioFormatById(audioFormatId!);
        final extension = _assembler.decideContainer(
          videoFormat: videoFormat,
          audioCodec: mergeAudioFormat?.codec,
          preference: options.containerPreference,
        );
        final outputPath = _repository.buildUniqueOutputPath(
          outputDirectory: options.outputDirectory,
          baseName: options.title,
          extension: extension,
          overwrite: options.overwrite,
        );
        _log.info('Final output path: $outputPath');
        outputFile = await _assembler.merge(
          videoTmp,
          audioTmp,
          outputPath,
          cover: coverTmp,
          cancelToken: cancelToken,
        );
      } else {
        // Combined stream: move the downloaded file into place.
        cancelToken.throwIfCancelled();
        var extension = (videoFormat?.container?.isNotEmpty ?? false)
            ? videoFormat!.container!
            : 'mp4';
        if (coverTmp != null) {
          extension =
              options.containerPreference == ContainerPreference.mkv ||
                  !{'mp4', 'mkv'}.contains(extension)
              ? 'mkv'
              : extension;
        }
        final outputPath = _repository.buildUniqueOutputPath(
          outputDirectory: options.outputDirectory,
          baseName: options.title,
          extension: extension,
          overwrite: options.overwrite,
        );
        if (coverTmp != null) {
          onPhase(DownloadTaskState.merging);
          outputFile = await _assembler.merge(
            videoTmp,
            null,
            outputPath,
            cover: coverTmp,
            cancelToken: cancelToken,
          );
        } else {
          _log.info('Moving combined stream to $outputPath');
          if (videoTmp.path != outputPath) {
            final existing = File(outputPath);
            if (existing.existsSync()) existing.deleteSync();
            videoTmp.renameSync(outputPath);
          }
          outputFile = File(outputPath);
        }
      }

      // 5. Verify the final file.
      onPhase(DownloadTaskState.verifying);
      _log.info('Validating final file with ffprobe');
      final report = await _assembler.verify(
        outputFile,
        expectedAudioLanguage: options.audioLanguage,
        expectedHeight: videoFormat?.height,
        expectCover: coverTmp != null,
      );
      if (!report.passed) {
        throw VerificationException(
          'Merge failed verification. Temporary files were kept for retry.',
          details: report.failures.join('\n'),
        );
      }

      cancelToken.throwIfCancelled();
      if (subtitleTmp != null && subtitle != null) {
        final basePath = outputFile.path.substring(
          0,
          outputFile.path.lastIndexOf('.'),
        );
        final subtitleOutput = File(
          '$basePath.${subtitle.language}.${subtitle.extension}',
        );
        if (subtitleOutput.existsSync() && !options.overwrite) {
          throw FilesystemException(
            'The subtitle file already exists: ${subtitleOutput.path}',
          );
        }
        await subtitleTmp.copy(subtitleOutput.path);
      }

      // 6. Cleanup temp files only after successful verification.
      _log.info('Download completed: ${outputFile.path}');
      _repository.cleanupTaskDirectory(taskId);
      return DownloadTaskResult(
        outputFile: outputFile,
        merged: audioTmp != null,
      );
    } catch (e) {
      if (e is DownloadCancelledException) {
        _log.info('Download cancelled (task $taskId)');
        rethrow;
      }
      // Temporary files are intentionally kept so the user can retry.
      _log.error('Download failed (task $taskId): $e');
      rethrow;
    }
  }

  Future<void> _downloadStream(
    Uri url,
    String formatId,
    File output,
    CancelToken cancelToken,
    ProgressCallback onProgress, {
    List<String>? extractorArgs,
  }) async {
    final baseArgs = extractorArgs ?? YoutubeExtractor.downloadBaseArgs();
    final args = [
      ...baseArgs,
      ..._extraArgList,
      '--no-write-subs',
      '--no-write-auto-subs',
      '--no-embed-subs',
      '--newline',
      '-f',
      formatId,
      '-o',
      output.path,
      url.toString(),
    ];

    _log.info('yt-dlp download args: -f $formatId (extractor: ${baseArgs.join(' ')})');

    final result = await _runner.run(
      executable: ytDlpPath,
      arguments: args,
      cancelToken: cancelToken,
      onLine: (line, _) {
        final progress = _progressParser.parse(line);
        if (progress != null) onProgress(progress);
      },
    );

    if (!result.success) {
      throw DownloadFailedException(
        'Failed to download the selected stream.',
        details: _tail(result.stderr),
      );
    }
    if (!output.existsSync() || output.lengthSync() == 0) {
      throw DownloadFailedException(
        'yt-dlp reported success but produced no output file.',
        details: _tail(result.stderr),
      );
    }
  }

  /// Re-extracts metadata and finds a format matching the original by
  /// properties (resolution, language, bitrate) rather than format ID.
  Future<String?> _remapFormatId({
    required Uri url,
    required String originalFormatId,
    int? targetHeight,
    String? targetLanguage,
    required bool isVideo,
  }) async {
    try {
      final result = await _runner.run(
        executable: ytDlpPath,
        arguments: [
          ...YoutubeExtractor.downloadBaseArgs(),
          '--dump-single-json',
          '--skip-download',
          url.toString(),
        ],
      );
      if (!result.success) return null;

      final json = jsonDecode(result.stdout) as Map<String, dynamic>;
      final formats = json['formats'] as List<dynamic>? ?? const [];

      for (final f in formats) {
        if (f is! Map<String, dynamic>) continue;
        final fid = f['format_id'] as String?;
        if (fid == null || fid == originalFormatId) continue;

        if (isVideo) {
          final height = f['height'] as int?;
          final vcodec = f['vcodec'] as String? ?? 'none';
          final acodec = f['acodec'] as String? ?? 'none';
          if (vcodec == 'none' || acodec != 'none') continue;
          if (targetHeight != null && height != targetHeight) continue;
          return fid;
        } else {
          final lang = (f['language'] ?? '').toString();
          final vcodec = f['vcodec'] as String? ?? 'none';
          final acodec = f['acodec'] as String? ?? 'none';
          if (vcodec != 'none' || acodec == 'none') continue;
          if (targetLanguage != null &&
              !lang.startsWith(targetLanguage.split('-').first)) {
            continue;
          }
          return fid;
        }
      }
    } catch (_) {}
    return null;
  }

  static String _tail(String stderr) {
    final lines =
        stderr.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 80) return lines.join('\n');
    return '... (${lines.length - 80} more) ...\n'
        '${lines.sublist(lines.length - 80).join('\n')}';
  }
}
