import 'dart:io';

import '../process/cancel_token.dart';

class MediaFilePublisher {
  const MediaFilePublisher();

  Future<File> publish(
    File source,
    String outputPath,
    CancelToken token,
  ) async {
    token.throwIfCancelled();
    final output = File(outputPath);
    await output.parent.create(recursive: true);
    final staging = await output.parent.createTemp('.universal-downloader-');
    try {
      final pending = await source.copy('${staging.path}/download');
      token.throwIfCancelled();
      return await pending.rename(outputPath);
    } finally {
      if (staging.existsSync()) await staging.delete(recursive: true);
    }
  }
}
