import '../downloader_provider.dart';
import '../provider_dependencies.dart';
import '../provider_factory.dart';
import '../youtube/youtube_provider.dart';

class YoutubeProviderFactory implements ProviderFactory {
  const YoutubeProviderFactory();

  @override
  DownloaderProvider create(ProviderDependencies dependencies) {
    return YoutubeProvider(
      ytDlpPath: dependencies.tools.ytDlp,
      ffmpegPath: dependencies.tools.ffmpeg,
      ffprobePath: dependencies.tools.ffprobe,
      runner: dependencies.runner,
      repository: dependencies.repository,
      log: dependencies.log,
    )..configureTools(dependencies.tools);
  }
}
