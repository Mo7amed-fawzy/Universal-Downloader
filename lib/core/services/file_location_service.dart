import 'dart:convert';
import 'dart:io';

import '../errors/downloader_exceptions.dart';
import '../process/process_runner.dart';

class FileLocationService {
  const FileLocationService({this.runner = const ProcessRunner()});

  final ProcessRunner runner;

  Future<void> open(String path) async {
    final file = File(path).absolute;
    try {
      final result = await runner.run(
        executable: 'gdbus',
        arguments: [
          'call',
          '--session',
          '--dest',
          'org.freedesktop.FileManager1',
          '--object-path',
          '/org/freedesktop/FileManager1',
          '--method',
          'org.freedesktop.FileManager1.ShowItems',
          '--timeout',
          '5',
          jsonEncode([file.uri.toString()]),
          '',
        ],
      );
      if (result.success) return;
    } on ProcessException catch (_) {}

    final result = await runner.run(
      executable: 'xdg-open',
      arguments: [file.parent.path],
    );
    if (!result.success) {
      throw FilesystemException(
        'Could not open the download location.',
        details: result.stderr,
      );
    }
  }
}
