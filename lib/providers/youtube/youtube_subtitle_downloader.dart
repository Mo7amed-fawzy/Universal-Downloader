import 'dart:io';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/models/subtitle_track.dart';
import '../../core/process/cancel_token.dart';
import '../../core/process/command_runner.dart';
import 'youtube_extractor.dart';

class YoutubeSubtitleDownloader {
  const YoutubeSubtitleDownloader({
    required this.ytDlpPath,
    required this.runner,
    this.extraArgs = const [],
  });

  final String ytDlpPath;
  final CommandRunner runner;
  final List<String> extraArgs;

  Future<File> download({
    required Uri url,
    required SubtitleTrack track,
    required Directory directory,
    required CancelToken cancelToken,
    void Function()? onDownloadStarted,
  }) async {
    cancelToken.throwIfCancelled();
    if (!RegExp(
          r'^[a-zA-Z0-9]+(?:[-_][a-zA-Z0-9]+)*$',
        ).hasMatch(track.language) ||
        !const ['vtt', 'srt'].contains(track.extension)) {
      throw DownloadFailedException('The selected subtitle track is invalid.');
    }
    final output = File(
      '${directory.path}/subtitles.${track.language}.${track.extension}',
    );
    if (output.existsSync()) output.deleteSync();
    final outputTemplate =
        '${directory.path.replaceAll('%', '%%')}/subtitles.%(ext)s';
    var downloadStarted = false;
    final result = await runner.run(
      executable: ytDlpPath,
      arguments: [
        ...YoutubeExtractor.extractionBaseArgs(),
        ...extraArgs,
        '--skip-download',
        '--no-simulate',
        '--no-embed-subs',
        track.isAutomatic ? '--no-write-subs' : '--write-subs',
        track.isAutomatic ? '--write-auto-subs' : '--no-write-auto-subs',
        '--sub-langs',
        '-all,^${track.language}\$',
        '--sub-format',
        track.extension,
        '--convert-subs',
        'none',
        if (track.isTranslated) ...['--sleep-subtitles', '60'],
        '--newline',
        '-o',
        outputTemplate,
        '-o',
        'subtitle:$outputTemplate',
        url.toString(),
      ],
      cancelToken: cancelToken,
      onLine: (line, isStdout) {
        if (isStdout &&
            !downloadStarted &&
            line.startsWith('[download]') &&
            !line.contains('Sleeping')) {
          downloadStarted = true;
          onDownloadStarted?.call();
        }
      },
    );
    cancelToken.throwIfCancelled();
    if (!result.success || !output.existsSync() || output.lengthSync() == 0) {
      if (RegExp(r'\b429\b').hasMatch(result.stderr)) {
        throw DownloadFailedException(
          'YouTube is temporarily limiting subtitle requests (HTTP 429). '
          'Wait a few minutes before retrying.',
          details: result.stderr,
        );
      }
      throw DownloadFailedException(
        'Could not download the selected subtitles. '
        'Fetch info again or select None to download without subtitles.',
        details: result.stderr,
      );
    }
    return output;
  }
}
