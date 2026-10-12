import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/providers/direct/direct_media_provider.dart';
import 'package:universal_downloader/providers/provider_registry.dart';
import 'package:universal_downloader/providers/youtube/youtube_provider.dart';

void main() {
  late ProviderRegistry registry;

  setUp(() {
    final youtube = YoutubeProvider(
      ytDlpPath: 'yt-dlp',
      ffmpegPath: 'ffmpeg',
      ffprobePath: 'ffprobe',
    );
    final direct = DirectMediaProvider(ffprobePath: 'ffprobe');
    registry = ProviderRegistry([youtube, direct]);
  });

  group('YouTube URL detection', () {
    test('recognizes standard youtube.com URLs', () {
      for (final url in [
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://gaming.youtube.com/watch?v=dQw4w9WgXcQ',
      ]) {
        expect(
          registry.resolve(Uri.parse(url))?.id,
          'youtube',
          reason: 'should resolve $url',
        );
      }
    });

    test('recognizes youtu.be short links', () {
      expect(
        registry.resolve(Uri.parse('https://youtu.be/dQw4w9WgXcQ'))?.id,
        'youtube',
      );
      expect(
        registry.resolve(Uri.parse('https://www.youtu.be/dQw4w9WgXcQ'))?.id,
        'youtube',
      );
    });

    test('recognizes youtube-nocookie.com URLs', () {
      expect(
        registry
            .resolve(
              Uri.parse('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'),
            )
            ?.id,
        'youtube',
      );
    });

    test('does not match lookalike hosts', () {
      expect(registry.resolve(Uri.parse('https://notyoutube.com/watch?v=1')),
          isNull);
      expect(
          registry.resolve(Uri.parse('https://youtube.com.evil.example/x')),
          isNull);
    });
  });

  group('ProviderRegistry', () {
    test('resolves the first provider able to handle a URL', () {
      final resolved = registry.resolve(Uri.parse('https://www.youtube.com/'));
      expect(resolved, isNotNull);
      expect(resolved!.id, 'youtube');
    });

    test('falls back to the direct provider for raw media URLs', () {
      final resolved = registry.resolve(
        Uri.parse('https://example.com/files/video.mp4'),
      );
      expect(resolved, isNotNull);
      expect(resolved!.id, 'direct');
    });

    test('byId returns the provider with the matching id', () {
      expect(registry.byId('youtube'), isNotNull);
      expect(registry.byId('direct'), isNotNull);
      expect(registry.byId('unknown'), isNull);
    });
  });
}
