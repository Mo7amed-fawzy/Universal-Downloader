class YoutubePlaylist {
  const YoutubePlaylist({
    required this.title,
    required this.videoUrls,
    this.unavailableCount = 0,
  });

  final String title;
  final List<Uri> videoUrls;
  final int unavailableCount;

  static Uri? normalizeUrl(Uri url) {
    if (!['http', 'https'].contains(url.scheme) ||
        !const {
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
          'music.youtube.com',
          'youtu.be',
          'www.youtu.be',
        }.contains(url.host.toLowerCase())) {
      return null;
    }
    final id = url.queryParameters['list'];
    if (id == null || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      return null;
    }
    return Uri.https('www.youtube.com', '/playlist', {'list': id});
  }

  static bool isPlaylistUrl(Uri url) =>
      normalizeUrl(url) != null ||
      (const {
            'youtube.com',
            'www.youtube.com',
            'm.youtube.com',
            'music.youtube.com',
          }.contains(url.host.toLowerCase()) &&
          url.path == '/playlist');

  factory YoutubePlaylist.fromJson(Map<String, dynamic> json) {
    final entries = json['entries'];
    if (json['_type'] != 'playlist' || entries is! List) {
      throw const FormatException(
        'This link did not return a YouTube playlist.',
      );
    }
    final urls = <Uri>[];
    final seen = <String>{};
    var unavailable = 0;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        unavailable++;
        continue;
      }
      final id = entry['id'];
      if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
        unavailable++;
        continue;
      }
      if (seen.add(id)) {
        urls.add(Uri.https('www.youtube.com', '/watch', {'v': id}));
      }
    }
    final title = json['title'];
    return YoutubePlaylist(
      title: title is String && title.trim().isNotEmpty
          ? title
          : 'YouTube playlist',
      videoUrls: List.unmodifiable(urls),
      unavailableCount: unavailable,
    );
  }
}
