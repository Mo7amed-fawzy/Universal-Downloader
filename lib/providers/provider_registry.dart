import 'downloader_provider.dart';

/// Registry of all known providers. Resolution order is insertion order.
class ProviderRegistry {
  ProviderRegistry(this.providers);

  final List<DownloaderProvider> providers;

  /// Returns the first provider able to handle [url], or null.
  DownloaderProvider? resolve(Uri url) {
    for (final provider in providers) {
      if (provider.canHandle(url)) {
        return provider;
      }
    }
    return null;
  }

  DownloaderProvider? byId(String id) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }
}
