import 'dart:async';
import 'dart:io';

import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/process/cancel_token.dart';
import 'package:universal_downloader/core/utils/path_utils.dart';
import 'package:universal_downloader/providers/downloader_provider.dart';

class ControlledDownloadProvider implements DownloaderProvider {
  final List<Completer<DownloadTaskResult>> calls = [];

  @override
  String get id => 'test';

  @override
  String get displayName => 'Test';

  @override
  bool canHandle(Uri url) => true;

  @override
  Future<MediaInfo> fetchInfo(Uri url) async => throw UnimplementedError();

  @override
  Future<DownloadTaskResult> download(
    MediaInfo media,
    DownloadOptions options, {
    required PhaseCallback onPhase,
    required ProgressCallback onProgress,
    required CancelToken cancelToken,
  }) {
    final call = Completer<DownloadTaskResult>();
    calls.add(call);
    return call.future;
  }
}

class QueueTestPaths extends PathUtils {
  const QueueTestPaths(this.root);
  final Directory root;

  @override
  Directory appDataDirectory() => root;
}
