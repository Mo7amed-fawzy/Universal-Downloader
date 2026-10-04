import 'dart:io';

import '../core/models/download_options.dart';
import '../core/models/media_info.dart';
import '../core/process/cancel_token.dart';
import '../downloads/download_progress.dart';
import '../downloads/download_task_state.dart';

/// Result of a completed provider download.
class DownloadTaskResult {
  const DownloadTaskResult({
    required this.outputFile,
    required this.merged,
  });

  final File outputFile;

  /// True when separate video + audio streams were merged by ffmpeg.
  final bool merged;
}

/// Phase callback used by providers to report pipeline progress.
typedef PhaseCallback = void Function(DownloadTaskState state);

/// Progress callback used by providers to report byte-level progress.
typedef ProgressCallback = void Function(DownloadProgress progress);

/// A generic media provider.
///
/// Implementations are responsible for:
///  * deciding whether they can handle a URL ([canHandle]),
///  * extracting media metadata and formats ([fetchInfo]),
///  * downloading the selected streams and producing a final file
///    ([download]).
///
/// Providers MUST NOT contain UI code, and the UI MUST NOT contain
/// provider-specific logic.
abstract class DownloaderProvider {
  /// Stable identifier, e.g. `youtube`.
  String get id;

  /// Human readable name, e.g. `YouTube`.
  String get displayName;

  /// True when this provider understands [url].
  bool canHandle(Uri url);

  /// Fetches media metadata and the list of available video/audio formats.
  Future<MediaInfo> fetchInfo(Uri url);

  /// Downloads [media] using the formats selected in [options].
  ///
  /// [onPhase] is invoked with the current pipeline state and [onProgress]
  /// with byte-level progress. Cancellation is cooperative via
  /// [cancelToken]; implementers should check it between steps.
  Future<DownloadTaskResult> download(
    MediaInfo media,
    DownloadOptions options, {
    required PhaseCallback onPhase,
    required ProgressCallback onProgress,
    required CancelToken cancelToken,
  });
}
