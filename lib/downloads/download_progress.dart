/// Immutable snapshot of download progress.
class DownloadProgress {
  const DownloadProgress({
    this.percent,
    this.downloadedBytes,
    this.totalBytes,
    this.speedBytesPerSecond,
    this.eta,
    this.statusLabel,
  });

  /// 0..100, or null when progress cannot be determined (indeterminate).
  final double? percent;

  final int? downloadedBytes;
  final int? totalBytes;
  final int? speedBytesPerSecond;
  final Duration? eta;

  /// Short human label describing the current activity.
  final String? statusLabel;

  static const indeterminate = DownloadProgress();

  DownloadProgress copyWith({
    double? percent,
    int? downloadedBytes,
    int? totalBytes,
    int? speedBytesPerSecond,
    Duration? eta,
    String? statusLabel,
  }) {
    return DownloadProgress(
      percent: percent ?? this.percent,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      eta: eta ?? this.eta,
      statusLabel: statusLabel ?? this.statusLabel,
    );
  }
}
