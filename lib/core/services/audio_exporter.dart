import 'dart:io';

import '../errors/downloader_exceptions.dart';
import '../models/audio_output_format.dart';
import '../process/cancel_token.dart';
import '../process/command_runner.dart';
import '../process/process_runner.dart';

class AudioExporter {
  AudioExporter({required this.ffmpegPath, CommandRunner? runner})
    : _runner = runner ?? const ProcessRunner();

  final String ffmpegPath;
  final CommandRunner _runner;

  Future<File> export({
    required File source,
    required Directory workspace,
    required AudioOutputFormat format,
    required CancelToken cancelToken,
  }) async {
    final output = File('${workspace.path}/audio-only.${format.id}');
    final encoding = switch (format) {
      AudioOutputFormat.mp3 => ['-c:a', 'libmp3lame', '-q:a', '2'],
      AudioOutputFormat.m4a => ['-c:a', 'aac', '-b:a', '192k'],
      AudioOutputFormat.flac => ['-c:a', 'flac'],
    };
    final result = await _runner.run(
      executable: ffmpegPath,
      arguments: [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        source.path,
        '-map',
        '0:a:0',
        '-vn',
        ...encoding,
        output.path,
      ],
      cancelToken: cancelToken,
    );
    if (!result.success || !output.existsSync() || output.lengthSync() == 0) {
      throw DownloadFailedException(
        'Could not create the ${format.label} audio file.',
        details: result.stderr,
      );
    }
    cancelToken.throwIfCancelled();
    return output;
  }
}
