import '../core/errors/downloader_exceptions.dart';
import '../core/models/download_options.dart';
import '../core/models/media_info.dart';
import '../core/process/cancel_token.dart';
import 'downloader_provider.dart';

/// Stub providers for future platforms.
///
/// None of them claim URLs yet (`canHandle` returns false), so they are safe
/// to leave unregistered. Implement them by modelling the behaviour of
/// [YoutubeProvider] against yt-dlp, which already supports these sites.
abstract class _UnimplementedProvider implements DownloaderProvider {
  @override
  bool canHandle(Uri url) => false;

  @override
  Future<MediaInfo> fetchInfo(Uri url) {
    throw ProviderNotSupportedException(
      '$displayName is not supported yet.',
    );
  }

  @override
  Future<DownloadTaskResult> download(
    MediaInfo media,
    DownloadOptions options, {
    required PhaseCallback onPhase,
    required ProgressCallback onProgress,
    required CancelToken cancelToken,
  }) {
    throw ProviderNotSupportedException(
      '$displayName is not supported yet.',
    );
  }
}

class FacebookProvider extends _UnimplementedProvider {
  @override
  String get id => 'facebook';
  @override
  String get displayName => 'Facebook';
}

class InstagramProvider extends _UnimplementedProvider {
  @override
  String get id => 'instagram';
  @override
  String get displayName => 'Instagram';
}

class TikTokProvider extends _UnimplementedProvider {
  @override
  String get id => 'tiktok';
  @override
  String get displayName => 'TikTok';
}

class XProvider extends _UnimplementedProvider {
  @override
  String get id => 'x';
  @override
  String get displayName => 'X / Twitter';
}
