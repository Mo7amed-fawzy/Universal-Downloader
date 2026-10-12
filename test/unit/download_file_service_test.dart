import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/services/download_file_service.dart';

void main() {
  const service = DownloadFileService();

  test(
    'detects file moves, restoration and deletion without changing files',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'download_file_presence_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}/فيديو with spaces.mkv')
        ..writeAsStringSync('video');
      expect(await service.exists(file.path), isTrue);
      expect(await service.exists(file.uri.toString()), isTrue);
      final moved = await file.rename('${root.path}/moved.mkv');
      expect(await service.exists(file.path), isFalse);
      expect(await service.exists(moved.path), isTrue);
      await moved.rename(file.path);
      expect(await service.exists(file.path), isTrue);
      expect(await file.readAsString(), 'video');
      await file.delete();
      expect(await service.exists(file.path), isFalse);
      expect(await service.exists(root.path), isFalse);
    },
  );

  test('does not treat Android content URIs as missing local files', () async {
    expect(
      await service.exists('content://media/external/downloads/42'),
      isNull,
    );
    expect(await service.exists(null), isFalse);
    expect(await service.exists(''), isFalse);
  });
}
