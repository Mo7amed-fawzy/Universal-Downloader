import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/services/log_service.dart';
import 'package:universal_downloader/core/utils/path_utils.dart';

void main() {
  test('GUI without a console retains logs without failing a download', () {
    final directory = Directory.systemTemp.createTempSync('no-console-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final log = LogService(paths: LogTestPaths(directory));
    IOOverrides.runZoned(
      () => log.info('Download started'),
      stdout: () => UnavailableStdout(),
    );
    expect(log.sessionLog, contains('Download started'));
    expect(log.readPersistedLog(), contains('Download started'));
  });
}

class LogTestPaths extends PathUtils {
  const LogTestPaths(this.root);
  final Directory root;
  @override
  Directory appDataDirectory() => root;
}

class UnavailableStdout implements Stdout {
  @override
  void writeln([Object? object = '']) =>
      throw const StdoutException('No console');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
