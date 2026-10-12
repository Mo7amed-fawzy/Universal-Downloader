/// Base class for all application errors.
///
/// [message] is safe to show to end users; technical details are kept in
/// [details] and only surfaced behind a "View details" action.
class DownloaderException implements Exception {
  const DownloaderException(this.message, {this.details});

  final String message;

  /// Technical details / log output for advanced users.
  final String? details;

  @override
  String toString() => '$runtimeType: $message';
}

class ProviderNotSupportedException extends DownloaderException {
  ProviderNotSupportedException(super.message, {super.details});
}

class NetworkException extends DownloaderException {
  NetworkException(super.message, {super.details});
}

class DependencyNotInstalledException extends DownloaderException {
  DependencyNotInstalledException(
    super.message, {
    required this.executable,
    super.details,
  });

  final String executable;
}

class YtDlpNotInstalledException extends DependencyNotInstalledException {
  YtDlpNotInstalledException(super.message, {super.details})
      : super(executable: 'yt-dlp');
}

class FfmpegNotInstalledException extends DependencyNotInstalledException {
  FfmpegNotInstalledException(super.message, {super.details})
      : super(executable: 'ffmpeg');
}

class FfprobeNotInstalledException extends DependencyNotInstalledException {
  FfprobeNotInstalledException(super.message, {super.details})
      : super(executable: 'ffprobe');
}

class FormatExtractionException extends DownloaderException {
  FormatExtractionException(super.message, {super.details});
}

class AudioNotAvailableException extends DownloaderException {
  AudioNotAvailableException(super.message, {super.details});
}

class ArabicAudioNotAvailableException extends AudioNotAvailableException {
  ArabicAudioNotAvailableException(super.message, {super.details});
}

class DownloadCancelledException extends DownloaderException {
  DownloadCancelledException({String? details})
      : super('Download was cancelled.', details: details);
}

class DownloadFailedException extends DownloaderException {
  DownloadFailedException(super.message, {super.details});
}

class MergeException extends DownloaderException {
  MergeException(super.message, {super.details});
}

class VerificationException extends DownloaderException {
  VerificationException(super.message, {super.details});
}

class FilesystemException extends DownloaderException {
  FilesystemException(super.message, {super.details});
}

class UnexpectedException extends DownloaderException {
  UnexpectedException(super.message, {super.details});
}
