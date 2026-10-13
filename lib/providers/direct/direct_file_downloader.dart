import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/process/cancel_token.dart';
import '../../downloads/download_progress.dart';
import '../downloader_provider.dart';

class DirectFileDownloader {
  const DirectFileDownloader({this.timeout = const Duration(seconds: 30)});

  final Duration timeout;

  Future<void> download(
    Uri url,
    File output,
    ProgressCallback onProgress,
    CancelToken cancelToken,
  ) async {
    final checkpoint = File('${output.path}.json');
    Map<String, Object?> saved = {};
    try {
      if (checkpoint.existsSync()) {
        final decoded = jsonDecode(await checkpoint.readAsString());
        if (decoded is Map<String, Object?> && decoded['url'] == '$url') {
          saved = decoded;
        }
      }
    } on FormatException {
      saved = {};
    }
    cancelToken.throwIfCancelled();
    final length = output.existsSync() ? await output.length() : 0;
    if (saved['complete'] == true && saved['total'] == length && length > 0) {
      onProgress(
        DownloadProgress(
          percent: 100,
          downloadedBytes: length,
          totalBytes: length,
        ),
      );
      return;
    }
    final storedValidator = saved['validator'];
    final validator = storedValidator is String ? storedValidator : null;
    var offset = validator == null ? 0 : length;
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = timeout;
    var active = true;
    unawaited(
      cancelToken.whenCancelled.then((_) {
        if (active) client.close(force: true);
      }),
    );
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        cancelToken.throwIfCancelled();
        final request = await cancelToken.race(
          client.getUrl(url).timeout(timeout),
        );
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        if (offset > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
          request.headers.set(HttpHeaders.ifRangeHeader, validator!);
        }
        final response = await cancelToken.race(
          request.close().timeout(timeout),
        );
        final status = response.statusCode;
        if (status == 416 && offset > 0) {
          offset = 0;
          await response.drain<void>().timeout(timeout);
          continue;
        }
        if (status != 200 && status != 206) {
          final message = 'Server returned HTTP $status for the media URL.';
          if (status == 408 || status == 429 || status >= 500) {
            throw NetworkException(message);
          }
          throw DownloadFailedException(message);
        }
        final etag = response.headers.value(HttpHeaders.etagHeader);
        final modified = response.headers.value(HttpHeaders.lastModifiedHeader);
        final nextValidator = etag != null && !etag.startsWith('W/')
            ? etag
            : modified;
        int? total;
        if (status == 206) {
          final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(
            response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
          );
          final start = range == null ? null : int.parse(range[1]!);
          final end = range == null ? null : int.parse(range[2]!);
          total = range == null ? null : int.parse(range[3]!);
          if (offset == 0 ||
              start != offset ||
              end == null ||
              total == null ||
              end < offset ||
              end >= total ||
              (response.contentLength >= 0 &&
                  response.contentLength != end - offset + 1) ||
              (saved['total'] != null && saved['total'] != total) ||
              (nextValidator != null && nextValidator != validator)) {
            throw DownloadFailedException(
              'The server returned an inconsistent resume response.',
            );
          }
        } else {
          offset = 0;
          total = response.contentLength >= 0 ? response.contentLength : null;
          await output.writeAsBytes(const [], flush: true);
        }
        final metadata = <String, Object?>{
          'url': '$url',
          'validator': nextValidator ?? (status == 206 ? validator : null),
          'total': total,
          'complete': false,
        };
        await _save(checkpoint, metadata);
        final sink = await output.open(mode: FileMode.append);
        var downloaded = offset;
        try {
          await for (final chunk in response.timeout(timeout)) {
            cancelToken.throwIfCancelled();
            await sink.writeFrom(chunk);
            downloaded += chunk.length;
            if (total != null && downloaded > total) {
              throw DownloadFailedException(
                'The server sent more bytes than expected.',
              );
            }
            onProgress(
              DownloadProgress(
                percent: total == null || total == 0
                    ? null
                    : (downloaded / total * 100).clamp(0, 99),
                downloadedBytes: downloaded,
                totalBytes: total,
              ),
            );
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        cancelToken.throwIfCancelled();
        if (total != null && downloaded != total) {
          throw NetworkException(
            'The connection ended before the file was complete.',
          );
        }
        metadata['total'] = downloaded;
        metadata['complete'] = true;
        await _save(checkpoint, metadata);
        onProgress(
          DownloadProgress(
            percent: 100,
            downloadedBytes: downloaded,
            totalBytes: downloaded,
          ),
        );
        return;
      }
      throw DownloadFailedException(
        'The server could not restart this download.',
      );
    } on SocketException catch (error) {
      cancelToken.throwIfCancelled();
      throw NetworkException(
        'The connection was interrupted.',
        details: '$error',
      );
    } on HttpException catch (error) {
      cancelToken.throwIfCancelled();
      throw NetworkException(
        'The connection was interrupted.',
        details: '$error',
      );
    } on TimeoutException catch (error) {
      cancelToken.throwIfCancelled();
      throw NetworkException('The connection timed out.', details: '$error');
    } finally {
      active = false;
      client.close(force: true);
    }
  }

  Future<void> _save(File checkpoint, Map<String, Object?> metadata) async {
    final pending = File('${checkpoint.path}.new');
    await pending.writeAsString(jsonEncode(metadata), flush: true);
    await pending.rename(checkpoint.path);
  }
}
