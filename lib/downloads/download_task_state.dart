/// Lifecycle states of a single download task.
enum DownloadTaskState {
  queued,
  fetchingInfo,
  selectingFormat,
  downloadingVideo,
  downloadingAudio,
  merging,
  verifying,
  completed,
  failed,
  cancelled;

  bool get isActive {
    return this == queued ||
        this == fetchingInfo ||
        this == selectingFormat ||
        this == downloadingVideo ||
        this == downloadingAudio ||
        this == merging ||
        this == verifying;
  }

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;

  String get label {
    switch (this) {
      case DownloadTaskState.queued:
        return 'Queued';
      case DownloadTaskState.fetchingInfo:
        return 'Fetching info';
      case DownloadTaskState.selectingFormat:
        return 'Selecting format';
      case DownloadTaskState.downloadingVideo:
        return 'Downloading video';
      case DownloadTaskState.downloadingAudio:
        return 'Downloading audio';
      case DownloadTaskState.merging:
        return 'Merging';
      case DownloadTaskState.verifying:
        return 'Verifying';
      case DownloadTaskState.completed:
        return 'Completed';
      case DownloadTaskState.failed:
        return 'Failed';
      case DownloadTaskState.cancelled:
        return 'Cancelled';
    }
  }
}
