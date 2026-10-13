import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/errors/downloader_exceptions.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/providers/direct/direct_file_downloader.dart';

void main() {
  late Directory root;
  late File output;
  late HttpServer server;
  late Uri url;
  final bytes = List<int>.generate(32768, (index) => index % 251);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('http_resume_');
    output = File('${root.path}/video.tmp');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('http://127.0.0.1:${server.port}/video.mp4');
  });

  tearDown(() async {
    await server.close(force: true);
    root.deleteSync(recursive: true);
  });

  Future<void> seed({
    String? validator = '"original"',
    bool complete = false,
  }) async {
    await output.writeAsBytes(complete ? bytes : bytes.take(4096).toList());
    await File('${output.path}.json').writeAsString(
      jsonEncode({
        'url': '$url',
        'validator': validator,
        'total': bytes.length,
        'complete': complete,
      }),
    );
  }

  Future<void> download({
    CancelToken? token,
    Duration timeout = const Duration(seconds: 2),
  }) => DirectFileDownloader(
    timeout: timeout,
  ).download(url, output, (_) {}, token ?? CancelToken());

  test(
    'a dropped connection resumes exact bytes with Range and If-Range',
    () async {
      var requests = 0;
      server.listen((request) async {
        requests++;
        if (requests == 1) {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          socket.add(
            ascii.encode(
              'HTTP/1.1 200 OK\r\nContent-Length: ${bytes.length}\r\nETag: "original"\r\nConnection: close\r\n\r\n',
            ),
          );
          socket.add(bytes.take(4096).toList());
          await socket.flush();
          await socket.close();
        } else {
          final length = await output.length();
          expect(length, greaterThan(0));
          expect(request.headers.value('range'), 'bytes=$length-');
          expect(request.headers.value('if-range'), '"original"');
          request.response.statusCode = 206;
          request.response.headers.set('etag', '"original"');
          request.response.headers.set(
            'content-range',
            'bytes $length-${bytes.length - 1}/${bytes.length}',
          );
          request.response.contentLength = bytes.length - length;
          request.response.add(bytes.skip(length).toList());
          await request.response.close();
        }
      });
      await expectLater(download(), throwsA(isA<NetworkException>()));
      await download();
      expect(await output.readAsBytes(), bytes);
      expect(requests, 2);
      await download();
      expect(requests, 2);
    },
  );

  test(
    'server ignoring Range replaces the partial file without concatenation',
    () async {
      await seed();
      server.listen((request) async {
        expect(request.headers.value('range'), 'bytes=4096-');
        request.response.headers.set('etag', '"replacement"');
        request.response.contentLength = bytes.length;
        request.response.add(bytes.reversed.toList());
        await request.response.close();
      });
      await download();
      expect(await output.readAsBytes(), bytes.reversed.toList());
    },
  );

  test('without a validator a partial file restarts safely', () async {
    await seed(validator: null);
    server.listen((request) async {
      expect(request.headers.value('range'), isNull);
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    await download();
    expect(await output.readAsBytes(), bytes);
  });

  for (final changed in [false, true]) {
    test(
      'rejects inconsistent 206 without appending (changed validator: $changed)',
      () async {
        await seed();
        server.listen((request) async {
          request.response.statusCode = 206;
          request.response.headers.set(
            'etag',
            changed ? '"different"' : '"original"',
          );
          request.response.headers.set(
            'content-range',
            'bytes ${changed ? 4096 : 0}-${bytes.length - 1}/${bytes.length}',
          );
          request.response.add(bytes.skip(4096).toList());
          await request.response.close();
        });
        await expectLater(download(), throwsA(isA<DownloadFailedException>()));
        expect(await output.readAsBytes(), bytes.take(4096).toList());
      },
    );
  }

  test(
    '416 restarts without Range rather than accepting an unverified file',
    () async {
      await seed();
      var requests = 0;
      server.listen((request) async {
        requests++;
        if (requests == 1) {
          request.response.statusCode = 416;
        } else {
          expect(request.headers.value('range'), isNull);
          request.response.add(bytes);
        }
        await request.response.close();
      });
      await download();
      expect(requests, 2);
      expect(await output.readAsBytes(), bytes);
    },
  );

  for (final status in [404, 503]) {
    test('HTTP $status has the correct retry classification', () async {
      server.listen((request) async {
        request.response.statusCode = status;
        await request.response.close();
      });
      await expectLater(
        download(),
        throwsA(
          status == 503
              ? isA<NetworkException>()
              : isA<DownloadFailedException>(),
        ),
      );
    });
  }

  test('cancellation interrupts a request waiting for headers', () async {
    final arrived = Completer<void>();
    server.listen((request) => arrived.complete());
    final token = CancelToken();
    final pending = expectLater(
      download(token: token),
      throwsA(isA<DownloadCancelledException>()),
    );
    await arrived.future;
    token.cancel();
    await pending;
  });

  test('a stalled server times out as a retryable network failure', () async {
    server.listen((request) {});
    await expectLater(
      download(timeout: const Duration(milliseconds: 50)),
      throwsA(isA<NetworkException>()),
    );
  });

  test('a completed file remains reusable without network access', () async {
    await seed(complete: true);
    await server.close(force: true);
    await download();
    expect(await output.readAsBytes(), bytes);
  });
}
