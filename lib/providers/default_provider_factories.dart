import 'factories/direct_media_provider_factory.dart';
import 'factories/youtube_provider_factory.dart';
import 'provider_factory.dart';

const defaultProviderFactories = <ProviderFactory>[
  YoutubeProviderFactory(),
  DirectMediaProviderFactory(),
];
