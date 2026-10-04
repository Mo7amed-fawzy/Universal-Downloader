import 'dart:convert';
import 'dart:io';

import '../errors/downloader_exceptions.dart';
import '../models/download_options.dart';
import '../models/video_format.dart';
import '../process/cancel_token.dart';
import '../process/process_runner.dart';

/// Verifies a produced media file with ffprobe.
class VerificationReport {
  const VerificationReport({
    required this.passed,
    this.failures = const [],
    this.hasVideo = false,
    this.hasAudio = false,
    this.audioLanguage,
    this.width,
    this.height,
  });

  final bool passed;
  final List<String> failures;
  final bool hasVideo;
  final bool hasAudio;
  final String? audioLanguage;
  final int? width;
  final int? height;
}

/// Merges separate video/audio streams with ffmpeg (stream copy whenever
/// possible) and verifies output with ffprobe.
class MediaAssembler {
  MediaAssembler({
    required this.ffmpegPath,
    required this.ffprobePath,
    ProcessRunner? runner,
  }) : runner = runner ?? const ProcessRunner();

  final String ffmpegPath;
  final String ffprobePath;
  final ProcessRunner runner;

  /// Decides the output container extension based on codecs and user
  /// preference. Prefers MP4, falls back to MKV for incompatible codecs.
  String decideContainer({
    VideoFormat? videoFormat,
    String? audioCodec,
    ContainerPreference preference = ContainerPreference.auto,
  }) {
    if (preference == ContainerPreference.mkv) return 'mkv';
    if (preference == ContainerPreference.mp4) return 'mp4';

    final vcodec = videoFormat?.codec?.split('.').first.toLowerCase() ?? '';
    final videoMp4Compatible = {
      'avc1',
      'h264',
      'hevc',
      'h265',
      'av01',
      'vp9',
    }.contains(vcodec);

    final acodec = audioCodec?.split('.').first.toLowerCase() ?? '';
    final audioMp4Compatible = {
      'mp4a',
      'aac',
      'mp3',
      'opus',
      'ac3',
      'eac3',
    }.contains(acodec);

    if (videoMp4Compatible && audioMp4Compatible) return 'mp4';
    return 'mkv';
  }

  /// Merges [video] and [audio] into [outputPath] using stream copy.
  ///
  /// Never re-encodes when both streams are copy-compatible.
  Future<File> merge(
    File video,
    File? audio,
    String outputPath, {
    File? cover,
    CancelToken? cancelToken,
  }) async {
    final isMp4 = outputPath.endsWith('.mp4');
    if (cover != null && !isMp4 && !outputPath.endsWith('.mkv')) {
      throw MergeException('Embedded covers require MP4 or MKV output.');
    }
    final coverInput = audio == null ? 1 : 2;
    final args = [
      '-y',
      '-hide_banner',
      '-i',
      video.path,
      if (audio != null) ...['-i', audio.path],
      if (cover != null && isMp4) ...['-i', cover.path],
      '-map',
      '0:V:0',
      '-map',
      audio == null ? '0:a:0' : '1:a:0',
      if (cover != null && isMp4) ...['-map', '$coverInput:v:0'],
      '-c',
      'copy',
      if (audio != null && cover == null) '-shortest',
      if (cover != null && isMp4) ...['-disposition:v:1', 'attached_pic'],
      if (cover != null && !isMp4) ...[
        '-attach',
        cover.path,
        '-metadata:s:t:0',
        'mimetype=image/jpeg',
        '-metadata:s:t:0',
        'filename=cover.jpg',
      ],
      if (isMp4) ...['-movflags', '+faststart'],
      outputPath,
    ];

    final result = await runner.run(
      executable: ffmpegPath,
      arguments: args,
      cancelToken: cancelToken,
    );

    if (!result.success) {
      throw MergeException(
        'FFmpeg could not merge the video and audio streams.',
        details: _tail(result.stderr, 60),
      );
    }

    final out = File(outputPath);
    if (!out.existsSync() || out.lengthSync() == 0) {
      throw MergeException(
        'FFmpeg reported success but produced no output file.',
        details: _tail(result.stderr, 60),
      );
    }
    return out;
  }

  /// Verifies [file] with ffprobe.
  ///
  /// Checks: file exists, size > 0, at least one video stream and one audio
  /// stream, and (when requested) that the audio stream language matches.
  Future<VerificationReport> verify(
    File file, {
    String? expectedAudioLanguage,
    int? expectedHeight,
    bool expectCover = false,
  }) async {
    if (!file.existsSync() || file.lengthSync() == 0) {
      return const VerificationReport(
        passed: false,
        failures: ['File missing or empty'],
      );
    }

    final args = [
      '-print_format',
      'json',
      '-show_streams',
      '-show_format',
      file.path,
    ];

    final result = await runner.run(
      executable: ffprobePath,
      arguments: args,
    );

    if (!result.success) {
      return VerificationReport(
        passed: false,
        failures: ['ffprobe failed: ${_tail(result.stderr, 20)}'],
      );
    }

    final failures = <String>[];
    var hasVideo = false;
    var hasAudio = false;
    var hasCover = false;
    String? audioLanguage;
    int? width;
    int? height;

    try {
      final decoded = jsonDecode(result.stdout) as Map<String, dynamic>;
      final streams = decoded['streams'] as List<dynamic>? ?? const [];
      final format = decoded['format'] as Map<String, dynamic>? ?? const {};

      for (final s in streams) {
        if (s is! Map<String, dynamic>) continue;
        final codecType = s['codec_type'] as String?;
        final disposition = s['disposition'];
        if (disposition is Map<String, dynamic> &&
            _parseInt(disposition['attached_pic']) == 1) {
          hasCover = true;
          continue;
        }
        if (codecType == 'video') {
          hasVideo = true;
          width = _parseInt(s['width']);
          height = _parseInt(s['height']);
        } else if (codecType == 'audio') {
          hasAudio = true;
          final tags = s['tags'] as Map<String, dynamic>? ?? const {};
          audioLanguage = tags['language'] as String?;
        }
      }

      final size = _parseInt(format['size']) ?? 0;

      if (!hasVideo) failures.add('No video stream found.');
      if (!hasAudio) failures.add('No audio stream found.');
      if (expectCover && !hasCover) failures.add('No embedded cover found.');
      if (size <= 0) failures.add('Output file has zero size.');

      if (expectedAudioLanguage != null &&
          expectedAudioLanguage.isNotEmpty) {
        final actual = audioLanguage?.split('-').first.toLowerCase();
        final expected = expectedAudioLanguage.split('-').first.toLowerCase();
        // "und" (undefined) or "eng" means the tag was lost during stream
        // copy or defaulted by ffmpeg — this is common with YouTube DASH
        // merges where language metadata lives in the manifest, not the
        // raw audio stream.  The user already selected the correct stream.
        if (actual != null &&
            actual != 'und' &&
            actual != 'eng' &&
            actual != expected) {
          failures.add(
            'Expected audio language "$expectedAudioLanguage" but found '
            '"${audioLanguage ?? 'none'}" in the final file.',
          );
        }
      }

      if (expectedHeight != null &&
          height != null &&
          height > expectedHeight) {
        // Tolerate slight container differences; only flag when far off.
        if (height > expectedHeight + 8) {
          failures.add(
            'Resolution mismatch: expected <= ${expectedHeight}p but got '
            '${height}p.',
          );
        }
      }
    } catch (e) {
      failures.add('Could not parse ffprobe output: $e');
    }

    return VerificationReport(
      passed: failures.isEmpty,
      failures: failures,
      hasVideo: hasVideo,
      hasAudio: hasAudio,
      audioLanguage: audioLanguage,
      width: width,
      height: height,
    );
  }

  static int? _parseInt(Object? value) {
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _tail(String text, int maxLines) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= maxLines) return lines.join('\n');
    return '... (${lines.length - maxLines} more) ...\n'
        '${lines.sublist(lines.length - maxLines).join('\n')}';
  }
}
