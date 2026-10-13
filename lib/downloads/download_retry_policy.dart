import 'dart:async';
import 'dart:io';

import '../core/errors/downloader_exceptions.dart';

class DownloadRetryPolicy {
  static bool isRetryable(Object error) {
    if (error is NetworkException ||
        error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return true;
    }
    if (error is! DownloadFailedException &&
        error is! FormatExtractionException) {
      return false;
    }
    final failure = error as DownloaderException;
    return isNetworkMessage('${failure.message}\n${failure.details ?? ''}');
  }

  static bool isNetworkMessage(String message) => RegExp(
    r'timed? out|timeout|connection (reset|refused|aborted|closed)|'
    r'network is unreachable|network is down|temporary failure in name resolution|'
    r'failed host lookup|unable to resolve|remote end closed|'
    r'incomplete read|incompleteread|HTTP (?:Error )?(?:408|429|5\d\d)\b',
    caseSensitive: false,
  ).hasMatch(message);
}
