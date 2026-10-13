import '../../core/process/cancel_token.dart';

class HomePlaylistEntry {
  HomePlaylistEntry(this.url);

  final Uri url;
  CancelToken cancelToken = CancelToken();
  String title = 'YouTube playlist';
  bool fetching = true;
  bool collapsed = false;
  int unavailableCount = 0;
  int queuedCount = 0;
  String? errorMessage;
  String outputDirectory = '';

  void selectOutputDirectory(String directory) => outputDirectory = directory;
}
