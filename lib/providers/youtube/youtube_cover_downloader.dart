import 'dart:io';
import 'dart:convert';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/process/cancel_token.dart';
import '../../core/process/command_runner.dart';

class YoutubeCoverDownloader {
  const YoutubeCoverDownloader({
    required this.ffmpegPath,
    required this.runner,
  });

  final String ffmpegPath;
  final CommandRunner runner;

  Future<File> download({
    required Uri url,
    required Directory directory,
    required CancelToken cancelToken,
  }) async {
    cancelToken.throwIfCancelled();
    if (!{'http', 'https'}.contains(url.scheme) || url.host.isEmpty) {
      throw DownloadFailedException('The YouTube cover URL is invalid.');
    }
    final output = File('${directory.path}/cover.jpg');
    final completed = File('${output.path}.complete');
    if (output.existsSync() &&
        output.lengthSync() > 0 &&
        completed.existsSync() &&
        await completed.readAsString() ==
            jsonEncode([url.toString(), await output.length()])) {
      return output;
    }
    final result = await runner.run(
      executable: ffmpegPath,
      arguments: [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-protocol_whitelist',
        'http,https,tcp,tls',
        '-rw_timeout',
        '15000000',
        '-i',
        url.toString(),
        '-map',
        '0:v:0',
        '-frames:v',
        '1',
        '-c:v',
        'mjpeg',
        '-q:v',
        '2',
        '-update',
        '1',
        output.path,
      ],
      cancelToken: cancelToken,
    );
    cancelToken.throwIfCancelled();
    if (!result.success || !output.existsSync() || output.lengthSync() == 0) {
      throw DownloadFailedException(
        'Could not download the YouTube cover. Fetch info again and retry.',
        details: result.stderr,
      );
    }
    await completed.writeAsString(
      jsonEncode([url.toString(), await output.length()]),
      flush: true,
    );
    return output;
  }
}
