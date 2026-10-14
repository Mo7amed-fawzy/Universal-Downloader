import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/models/audio_format.dart';
import '../../core/models/audio_output_format.dart';
import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/process/cancel_token.dart';
import '../../core/process/command_runner.dart';
import '../../core/process/process_runner.dart';
import '../../core/process/yt_dlp_progress_parser.dart';
import '../../core/services/audio_exporter.dart';
import '../../core/services/audio_stem_processor.dart';
import '../../core/services/log_service.dart';
import '../../core/services/media_assembler.dart';
import '../../core/services/media_file_publisher.dart';
import '../../core/tools/media_tools.dart';
import '../../downloads/download_progress.dart';
import '../../downloads/download_repository.dart';
import '../../downloads/download_retry_policy.dart';
import '../../downloads/download_task_state.dart';
import '../downloader_provider.dart';
import '../tool_configurable_provider.dart';
import 'youtube_cover_downloader.dart';
import 'youtube_extractor.dart';
import 'youtube_format_mapper.dart';
import 'youtube_playlist.dart';
import 'youtube_subtitle_downloader.dart';

/// YouTube provider backed by yt-dlp.
class YoutubeProvider implements DownloaderProvider, ToolConfigurableProvider {
  YoutubeProvider({
    required this.ytDlpPath,
    required this.ffmpegPath,
    required this.ffprobePath,
    this.denoPath,
    CommandRunner? runner,
    DownloadRepository? repository,
    LogService? log,
  }) : _runner = runner ?? const ProcessRunner(),
       _repository = repository ?? DownloadRepository(),
       _log = log ?? LogService();

  final CommandRunner _runner;
  final DownloadRepository _repository;
  final LogService _log;
  String ytDlpPath;
  String ffmpegPath;
  String ffprobePath;
  String? denoPath;
  String _extraArgs = '';
  List<String>? _runtimeArguments;

  @override
  void configureTools(MediaTools tools) {
    ytDlpPath = tools.ytDlp;
    ffmpegPath = tools.ffmpeg;
    ffprobePath = tools.ffprobe;
    denoPath = null;
    _runtimeArguments = tools.ytDlpArguments;
  }

  @override
  String get id => 'youtube';

  @override
  String get displayName => 'YouTube';

  /// Additional raw yt-dlp arguments from user settings (whitespace split).
  void setExtraYtDlpArgs(String value) => _extraArgs = value;

  List<String> get _extraArgList => [
    if (_runtimeArguments != null)
      ..._runtimeArguments!
    else if (denoPath != null) ...[
      '--ignore-config',
      '--no-remote-components',
      '--no-js-runtimes',
      '--js-runtimes',
      'deno:$denoPath',
      '--ffmpeg-location',
      ffmpegPath,
    ],
    if (_extraArgs.trim().isNotEmpty)
      ..._extraArgs.trim().split(RegExp(r'\s+')),
  ];

  MediaAssembler get _assembler => MediaAssembler(
    ffmpegPath: ffmpegPath,
    ffprobePath: ffprobePath,
    runner: _runner,
  );

  static const _progressParser = YtDlpProgressParser();

  Future<YoutubePlaylist> fetchPlaylist(Uri url, {CancelToken? cancelToken}) =>
      YoutubeExtractor(
        ytDlpPath: ytDlpPath,
        runner: _runner,
        extraArgs: _extraArgList,
      ).extractPlaylist(url, cancelToken: cancelToken);

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
        _log.info('Merged ${progressives.length} m3u8 progressive formats');
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
    cancelToken.throwIfCancelled();
    final recovered = await _repository.loadVerifiedResult(taskId);
    if (recovered != null) return recovered;
    final tempDir = _repository.createTaskDirectory(taskId);
    var videoTmp = File('${tempDir.path}/video.tmp');

    // Check if the audio format is an m3u8 progressive stream.
    // Synthetic audio format ids start with "m3u8-" and carry the real
    // progressive format id in [AudioFormat.progressiveFormatId].
    final audioFormatId = options.audioFormatId;
    final audioFormat = audioFormatId != null
        ? media.audioFormatById(audioFormatId)
        : null;
    final progressiveId = audioFormat?.progressiveFormatId;

    final videoFormat = media.videoFormatById(options.videoFormatId);
    final stemProcessor = AudioStemProcessor(runner: _runner);

    File? audioTmp;
    try {
      if (options.audioOutputFormat != null && options.isMuted) {
        throw DownloadFailedException('No audio remains to export.');
      }
      if (options.needsAudioProcessing && !options.isMuted) {
        await stemProcessor.ensureAvailable(cancelToken);
      }
      if (options.audioOutputFormat != null) {
        return await _downloadAudioOnly(
          media,
          options,
          tempDir,
          audioFormat,
          stemProcessor,
          onPhase: onPhase,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      }
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
        if (!media.subtitleTracks.any(
          (track) =>
              track.id == subtitle.id && track.extension == subtitle.extension,
        )) {
          throw DownloadFailedException(
            'The selected subtitles are unavailable. Fetch info again.',
          );
        }
        onPhase(
          subtitle.isTranslated
              ? DownloadTaskState.waitingForSubtitles
              : DownloadTaskState.downloadingSubtitles,
        );
        subtitleTmp =
            await YoutubeSubtitleDownloader(
              ytDlpPath: ytDlpPath,
              runner: _runner,
              extraArgs: _extraArgList,
            ).download(
              url: media.pageUrl,
              track: subtitle,
              directory: tempDir,
              cancelToken: cancelToken,
              onDownloadStarted: () =>
                  onPhase(DownloadTaskState.downloadingSubtitles),
            );
      }
      // Download the selected video and audio sources separately, then merge.
      final videoArgs = YoutubeExtractor.downloadBaseArgs();
      final audioArgs = progressiveId != null
          ? YoutubeExtractor.hlsDownloadBaseArgs()
          : YoutubeExtractor.downloadAudioBaseArgs();

      // 1. Download the selected video stream.
      cancelToken.throwIfCancelled();
      onPhase(DownloadTaskState.downloadingVideo);
      _log.info('Downloading video stream ${options.videoFormatId}');
      try {
        videoTmp = await _downloadStream(
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
        if (remappedId == null || remappedId == options.videoFormatId) {
          rethrow;
        }
        _log.info(
          'Remapped video format ${options.videoFormatId} → $remappedId',
        );
        videoTmp = await _downloadStream(
          media.pageUrl,
          remappedId,
          videoTmp,
          cancelToken,
          onProgress,
          extractorArgs: videoArgs,
        );
      }

      // 2. Download the selected audio stream.
      if (audioFormatId != null && !options.isMuted) {
        cancelToken.throwIfCancelled();
        onPhase(DownloadTaskState.downloadingAudio);
        final sourceAudioId = progressiveId ?? audioFormatId;
        _log.info('Downloading audio stream $sourceAudioId');
        audioTmp = File('${tempDir.path}/audio.tmp');
        try {
          audioTmp = await _downloadStream(
            media.pageUrl,
            sourceAudioId,
            audioTmp,
            cancelToken,
            onProgress,
            extractorArgs: audioArgs,
          );
        } on DownloadFailedException catch (e) {
          if (progressiveId != null) rethrow;
          _log.info('Audio download failed, attempting format remap: $e');
          final remappedId = await _remapFormatId(
            url: media.pageUrl,
            originalFormatId: audioFormatId,
            targetLanguage: options.audioLanguage,
            targetAudio: audioFormat,
            isVideo: false,
          );
          if (remappedId == null || remappedId == audioFormatId) rethrow;
          _log.info('Remapped audio format $audioFormatId → $remappedId');
          audioTmp = await _downloadStream(
            media.pageUrl,
            remappedId,
            audioTmp!,
            cancelToken,
            onProgress,
            extractorArgs: audioArgs,
          );
        }
      }

      File outputFile;
      if (options.needsAudioProcessing) {
        cancelToken.throwIfCancelled();
        final extension = audioTmp != null
            ? _assembler.decideContainer(
                videoFormat: videoFormat,
                audioCodec: audioFormat?.codec,
                preference: options.containerPreference,
              )
            : (videoFormat?.container?.isNotEmpty ?? false)
            ? videoFormat!.container!
            : 'mp4';
        final outputExtension = extension != 'mp4' && !options.isMuted
            ? 'mkv'
            : coverTmp != null && extension != 'mp4'
            ? 'mkv'
            : extension;
        final outputPath = _repository.buildUniqueOutputPath(
          outputDirectory: options.outputDirectory,
          baseName: options.title,
          extension: outputExtension,
          overwrite: options.overwrite,
        );
        if (options.isMuted) {
          onPhase(DownloadTaskState.merging);
          outputFile = await _assembler.merge(
            videoTmp,
            null,
            outputPath,
            cover: coverTmp,
            cancelToken: cancelToken,
            includeAudio: false,
          );
        } else {
          onPhase(DownloadTaskState.merging);
          final source = await _assembler.merge(
            videoTmp,
            audioTmp,
            '${tempDir.path}/source.$outputExtension',
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
          outputFile = await _assembler.merge(
            source,
            selectedAudio,
            outputPath,
            cover: coverTmp,
            cancelToken: cancelToken,
          );
        }
      } else if (audioTmp != null) {
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
          outputFile = await const MediaFilePublisher().publish(
            videoTmp,
            outputPath,
            cancelToken,
          );
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
        expectAudio: !options.isMuted,
      );
      if (!report.passed) {
        throw VerificationException(
          'Merge failed verification. Temporary files were kept for retry.',
          details: report.failures.join('\n'),
        );
      }

      cancelToken.throwIfCancelled();
      final sidecarFiles = <File>[];
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
        sidecarFiles.add(await subtitleTmp.copy(subtitleOutput.path));
      }

      _log.info('Download completed: ${outputFile.path}');
      final result = DownloadTaskResult(
        outputFile: outputFile,
        merged: audioTmp != null || options.needsAudioProcessing,
        sidecarFiles: sidecarFiles,
      );
      await _repository.saveVerifiedResult(taskId, result);
      return result;
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

  Future<DownloadTaskResult> _downloadAudioOnly(
    MediaInfo media,
    DownloadOptions options,
    Directory tempDir,
    AudioFormat? audioFormat,
    AudioStemProcessor stemProcessor, {
    required PhaseCallback onPhase,
    required ProgressCallback onProgress,
    required CancelToken cancelToken,
  }) async {
    final format = options.audioOutputFormat!;
    final progressiveId = audioFormat?.progressiveFormatId;
    final selectedAudioId = progressiveId ?? options.audioFormatId;
    final sourceId = selectedAudioId ?? options.videoFormatId;
    final extractorArgs = selectedAudioId == null
        ? YoutubeExtractor.downloadBaseArgs()
        : progressiveId != null
        ? YoutubeExtractor.hlsDownloadBaseArgs()
        : YoutubeExtractor.downloadAudioBaseArgs();
    onPhase(DownloadTaskState.downloadingAudio);
    var source = File('${tempDir.path}/audio-source.tmp');
    try {
      source = await _downloadStream(
        media.pageUrl,
        sourceId,
        source,
        cancelToken,
        onProgress,
        extractorArgs: extractorArgs,
      );
    } on DownloadFailedException catch (error) {
      if (progressiveId != null) rethrow;
      final remappedId = await _remapFormatId(
        url: media.pageUrl,
        originalFormatId: sourceId,
        targetLanguage: options.audioLanguage,
        targetAudio: audioFormat,
        targetHeight: selectedAudioId == null
            ? media.videoFormatById(sourceId)?.height
            : null,
        isVideo: selectedAudioId == null,
      );
      if (remappedId == null || remappedId == sourceId) rethrow;
      _log.info('Audio source download failed, trying $remappedId: $error');
      source = await _downloadStream(
        media.pageUrl,
        remappedId,
        source,
        cancelToken,
        onProgress,
        extractorArgs: extractorArgs,
      );
    }
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
        await AudioExporter(ffmpegPath: ffmpegPath, runner: _runner).export(
          source: source,
          workspace: tempDir,
          format: format,
          cancelToken: cancelToken,
        );
    onPhase(DownloadTaskState.verifying);
    final report = await _assembler.verify(
      exported,
      expectedAudioLanguage: options.audioLanguage,
      expectVideo: false,
    );
    if (!report.passed) {
      throw VerificationException(
        'The audio file failed verification.',
        details: report.failures.join('\n'),
      );
    }
    cancelToken.throwIfCancelled();
    final outputPath = _repository.buildUniqueOutputPath(
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
    await _repository.saveVerifiedResult(options.taskId, result);
    return result;
  }

  Future<File> _downloadStream(
    Uri url,
    String formatId,
    File output,
    CancelToken cancelToken,
    ProgressCallback onProgress, {
    List<String>? extractorArgs,
  }) async {
    final baseArgs = extractorArgs ?? YoutubeExtractor.downloadBaseArgs();
    final identity = sha256.convert(
      utf8.encode(jsonEncode([url.toString(), formatId, baseArgs])),
    );
    final directory = Directory('${output.parent.path}/streams/$identity');
    await directory.create(recursive: true);
    output = File('${directory.path}/${output.uri.pathSegments.last}');
    final completed = File('${output.path}.complete');
    cancelToken.throwIfCancelled();
    if (output.existsSync() &&
        completed.existsSync() &&
        await completed.readAsString() == '${await output.length()}' &&
        await output.length() > 0) {
      onProgress(
        DownloadProgress(
          percent: 100,
          downloadedBytes: await output.length(),
          totalBytes: await output.length(),
        ),
      );
      return output;
    }
    final args = [
      ...baseArgs,
      ..._extraArgList,
      '--continue',
      '--part',
      '--no-overwrites',
      '--abort-on-unavailable-fragments',
      '--socket-timeout',
      '20',
      '--retries',
      '3',
      '--fragment-retries',
      '3',
      '--retry-sleep',
      'exp=1:8',
      '--no-write-subs',
      '--no-write-auto-subs',
      '--no-embed-subs',
      '--newline',
      '--progress',
      '--progress-template',
      YtDlpProgressParser.progressTemplate,
      '-f',
      formatId,
      '-o',
      output.path,
      url.toString(),
    ];

    _log.info(
      'yt-dlp download args: -f $formatId (extractor: ${baseArgs.join(' ')})',
    );

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
      if (DownloadRetryPolicy.isNetworkMessage(result.stderr)) {
        throw NetworkException(
          'The network connection was interrupted.',
          details: _tail(result.stderr),
        );
      }
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
    await completed.writeAsString('${await output.length()}', flush: true);
    return output;
  }

  /// Re-extracts metadata and finds a format matching the original by
  /// properties (resolution, language, bitrate) rather than format ID.
  Future<String?> _remapFormatId({
    required Uri url,
    required String originalFormatId,
    int? targetHeight,
    String? targetLanguage,
    AudioFormat? targetAudio,
    required bool isVideo,
  }) async {
    try {
      final result = await _runner.run(
        executable: ytDlpPath,
        arguments: [
          ...YoutubeExtractor.downloadBaseArgs(),
          ..._extraArgList,
          '--dump-single-json',
          '--skip-download',
          url.toString(),
        ],
      );
      if (!result.success) return null;

      final json = jsonDecode(result.stdout) as Map<String, dynamic>;
      if (!isVideo) {
        final refreshed = const YoutubeFormatMapper().fromJson(json, url);
        for (final format in refreshed.audioFormats) {
          if (format.formatId == originalFormatId) continue;
          if (targetLanguage != null &&
              !format.languageMatches(targetLanguage)) {
            continue;
          }
          if (targetAudio != null &&
              (format.bitrate != targetAudio.bitrate ||
                  format.codec != targetAudio.codec ||
                  format.sampleRate != targetAudio.sampleRate)) {
            continue;
          }
          return format.formatId;
        }
        return null;
      }
      final formats = json['formats'] as List<dynamic>? ?? const [];

      for (final f in formats) {
        if (f is! Map<String, dynamic>) continue;
        final fid = f['format_id'] as String?;
        if (fid == null || fid == originalFormatId) continue;

        final height = f['height'] as int?;
        final vcodec = f['vcodec'] as String? ?? 'none';
        final acodec = f['acodec'] as String? ?? 'none';
        if (vcodec == 'none' || acodec != 'none') continue;
        if (targetHeight != null && height != targetHeight) continue;
        return fid;
      }
    } catch (_) {}
    return null;
  }

  static String _tail(String stderr) {
    final lines = stderr.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 80) return lines.join('\n');
    return '... (${lines.length - 80} more) ...\n'
        '${lines.sublist(lines.length - 80).join('\n')}';
  }
}
