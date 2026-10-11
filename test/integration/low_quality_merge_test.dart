import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/services/media_assembler.dart';

void main() {
  for (final height in [144, 240]) {
    test(
      'keeps ${height}p video when audio comes from a 720p stream',
      () async {
        final root = Directory.systemTemp.createTempSync('low_quality_merge_');
        addTearDown(() => root.deleteSync(recursive: true));
        final video = File('${root.path}/video.mp4');
        final muxed = File('${root.path}/muxed.mp4');
        final width = height == 144 ? 256 : 426;
        final makeVideo = await Process.run('ffmpeg', [
          '-y',
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'lavfi',
          '-i',
          'color=black:size=${width}x$height:duration=1',
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          video.path,
        ]);
        expect(makeVideo.exitCode, 0, reason: '${makeVideo.stderr}');
        final makeMuxed = await Process.run('ffmpeg', [
          '-y',
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'lavfi',
          '-i',
          'color=red:size=1280x720:duration=1',
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
          '-metadata:s:a:0',
          'language=ara',
          muxed.path,
        ]);
        expect(makeMuxed.exitCode, 0, reason: '${makeMuxed.stderr}');
        final assembler = MediaAssembler(
          ffmpegPath: 'ffmpeg',
          ffprobePath: 'ffprobe',
        );
        final merged = await assembler.merge(
          video,
          muxed,
          '${root.path}/output.mp4',
        );
        final report = await assembler.verify(
          merged,
          expectedHeight: height,
          expectedAudioLanguage: 'ara',
        );
        expect(report.passed, isTrue, reason: report.failures.join('\n'));
        expect(report.height, height);
        expect(report.hasAudio, isTrue);
        expect(report.hasVideo, isTrue);
      },
    );
  }
}
