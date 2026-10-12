import 'downloader_provider.dart';
import 'provider_dependencies.dart';

abstract interface class ProviderFactory {
  DownloaderProvider create(ProviderDependencies dependencies);
}
