String youtubeCacheKey(Uri url) {
  final segments = url.pathSegments;
  final id = {'youtu.be', 'www.youtu.be'}.contains(url.host.toLowerCase())
      ? segments.firstOrNull
      : url.path == '/watch'
      ? url.queryParameters['v']
      : segments.length >= 2 &&
            {'shorts', 'embed', 'live'}.contains(segments.first)
      ? segments[1]
      : null;
  if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
    return 'youtube:$id';
  }
  return url.toString();
}
