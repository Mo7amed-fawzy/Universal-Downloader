import '../direct/direct_media_provider.dart';
import '../downloader_provider.dart';
import '../provider_dependencies.dart';
import '../provider_factory.dart';

class DirectMediaProviderFactory implements ProviderFactory {
  const DirectMediaProviderFactory();

  @override
  DownloaderProvider create(ProviderDependencies dependencies) {
    return DirectMediaProvider(
      ffprobePath: dependencies.tools.ffprobe,
      runner: dependencies.runner,
      repository: dependencies.repository,
      log: dependencies.log,
    );
  }
}
