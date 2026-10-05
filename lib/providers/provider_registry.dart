import '../core/tools/media_tools.dart';
import 'downloader_provider.dart';
import 'provider_dependencies.dart';
import 'provider_factory.dart';
import 'tool_configurable_provider.dart';

/// Registry of all known providers. Resolution order is insertion order.
class ProviderRegistry {
  ProviderRegistry(Iterable<DownloaderProvider> providers)
    : providers = List.unmodifiable(providers) {
    final ids = <String>{};
    for (final provider in this.providers) {
      if (!ids.add(provider.id)) {
        throw ArgumentError('Duplicate provider id: ${provider.id}');
      }
    }
  }

  factory ProviderRegistry.fromFactories({
    required Iterable<ProviderFactory> factories,
    required ProviderDependencies dependencies,
  }) {
    return ProviderRegistry(
      factories.map((factory) => factory.create(dependencies)),
    );
  }

  void configureTools(MediaTools tools) {
    for (final provider in providers) {
      if (provider case ToolConfigurableProvider configurable) {
        configurable.configureTools(tools);
      }
    }
  }

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
