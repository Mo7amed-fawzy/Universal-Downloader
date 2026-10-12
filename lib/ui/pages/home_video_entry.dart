import 'home_video_draft.dart';

class HomeVideoEntry {
  HomeVideoEntry(this.link);

  final String link;
  HomeVideoDraft? draft;
  bool fetching = false;
  String? errorMessage;

  bool get waiting => draft == null && !fetching && errorMessage == null;
}
