import 'package:universal_downloader/core/models/audio_format.dart';
import 'package:universal_downloader/core/models/download_options.dart';
import 'package:universal_downloader/core/models/media_info.dart';
import 'package:universal_downloader/core/models/subtitle_track.dart';
import 'package:universal_downloader/core/models/video_format.dart';
import 'package:universal_downloader/downloads/download_task.dart';

MediaInfo cachedMedia() => MediaInfo(
  id: 'NAEp-qL4VHc',
  title: 'فيديو للتجربة',
  providerId: 'youtube',
  providerName: 'YouTube',
  pageUrl: Uri.parse('https://youtu.be/NAEp-qL4VHc'),
  thumbnail: Uri.parse('https://example.com/thumbnail.jpg'),
  duration: const Duration(seconds: 123),
  uploader: 'Creator',
  description: 'Description',
  videoFormats: const [
    VideoFormat(
      formatId: 'v144',
      width: 256,
      height: 144,
      fps: 30,
      codec: 'avc1',
      bitrate: 100,
      container: 'mp4',
      note: '144p',
      filesize: 1234,
      videoOnly: true,
    ),
    VideoFormat(formatId: 'v720', width: 1280, height: 720, hasAudio: true),
  ],
  audioFormats: const [
    AudioFormat(
      formatId: 'ar',
      language: 'ar',
      languageName: 'Arabic',
      bitrate: 128,
      sampleRate: 48000,
      codec: 'mp4a',
      container: 'm4a',
      filesize: 456,
    ),
    AudioFormat(
      formatId: 'hls-en',
      language: 'en',
      progressiveFormatId: '95-1',
    ),
  ],
  subtitleTracks: const [
    SubtitleTrack(
      language: 'ar',
      extension: 'vtt',
      name: 'العربية',
      isAutomatic: true,
      isTranslated: true,
    ),
  ],
);

DownloadTask completedDownload(String location, {String id = 'finished'}) {
  final media = cachedMedia();
  return DownloadTask.completed(
    id: id,
    media: media,
    options: DownloadOptions(
      taskId: id,
      outputDirectory: '/videos',
      title: media.title,
      videoFormatId: 'v144',
      audioFormatId: 'ar',
      audioLanguage: 'ar',
      subtitle: media.subtitleTracks.single,
      containerPreference: ContainerPreference.mkv,
    ),
    providerId: media.providerId,
    providerName: media.providerName,
    videoLabel: '144p',
    audioLabel: 'Arabic 128 kbps',
    outputPath: location,
    startedAt: DateTime.utc(2026, 10, 11, 12),
    completedAt: DateTime.utc(2026, 10, 11, 12, 1),
  );
}
