import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/models/audio_output_format.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/services/audio_exporter.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';

void main() {
  test('MP3, M4A and FLAC exports contain audio without video', () async {
    final ffmpegResult = await Process.run('which', ['ffmpeg']);
    final ffprobeResult = await Process.run('which', ['ffprobe']);
    if (ffmpegResult.exitCode != 0 || ffprobeResult.exitCode != 0) return;
    final ffmpeg = (ffmpegResult.stdout as String).trim();
    final ffprobe = (ffprobeResult.stdout as String).trim();
    final directory = Directory.systemTemp.createTempSync('audio_exporter_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/source.mp4');
    final created = await Process.run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=black:size=160x120:duration=1',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-shortest',
      source.path,
    ]);
    expect(created.exitCode, 0, reason: '${created.stderr}');
    final exporter = AudioExporter(ffmpegPath: ffmpeg);
    final assembler = MediaAssembler(ffmpegPath: ffmpeg, ffprobePath: ffprobe);

    for (final format in AudioOutputFormat.values) {
      final output = await exporter.export(
        source: source,
        workspace: directory,
        format: format,
        cancelToken: CancelToken(),
      );
      expect(output.path, endsWith('.${format.id}'));
      final report = await assembler.verify(output, expectVideo: false);
      expect(report.passed, isTrue, reason: report.failures.join('\n'));
      expect(report.hasAudio, isTrue);
      expect(report.hasVideo, isFalse);
    }
  });
}
