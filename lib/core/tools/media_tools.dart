class MediaTools {
  MediaTools({
    required this.ytDlp,
    required this.ffmpeg,
    required this.ffprobe,
    List<String> ytDlpArguments = const [],
  }) : ytDlpArguments = List.unmodifiable(ytDlpArguments);

  final String ytDlp;
  final String ffmpeg;
  final String ffprobe;
  final List<String> ytDlpArguments;
}
