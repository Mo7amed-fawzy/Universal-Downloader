import 'home_video_draft.dart';
import 'home_playlist_entry.dart';

class HomeVideoEntry {
  HomeVideoEntry(this.link, {this.playlist});

  final String link;
  final HomePlaylistEntry? playlist;
  HomeVideoDraft? draft;
  bool fetching = false;
  bool selectedForDownload = true;
  String? errorMessage;

  void selectForDownload(bool selected) => selectedForDownload = selected;

  bool get waiting => draft == null && !fetching && errorMessage == null;
}
