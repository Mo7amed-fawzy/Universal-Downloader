# Universal Downloader

A generic media downloader for Linux desktop, built with Flutter (Material 3).

Paste a URL and the app detects the provider, lists the real available
formats, and downloads the best video stream plus your preferred audio track
(e.g. Arabic) merged into a single file — powered by `yt-dlp` and `ffmpeg`.

## Features

- Provider-agnostic architecture: YouTube today, more providers (Facebook,
  Instagram, TikTok, X/Twitter, Reddit, Vimeo) and direct media URLs planned.
- Per-language audio selection (e.g. prefer Arabic, fall back to English).
- Best video quality selection with a configurable cap (2160p → 360p).
- MP4/MKV container decision based on the actual codecs (stream copy, no
  re-encoding).
- Merged output verified with `ffprobe` (streams present, language matches,
  resolution within the requested cap).
- Queue with concurrency limit, per-task progress, retry and cancellation.
- Missing-dependency banner with install instructions.
- App settings persisted with `shared_preferences`.

## Requirements

- Linux with a GTK desktop environment
- [yt-dlp](https://github.com/yt-dlp/yt-dlp#installation)
  (e.g. `pipx install yt-dlp`)
- [ffmpeg / ffprobe](https://ffmpeg.org/) (e.g. `sudo apt install ffmpeg`)
- Flutter SDK 3.x to build from source

## Build

```sh
flutter pub get
flutter build linux --release
```

The bundle is written to `build/linux/x64/release/bundle/`. Run it with:

```sh
./build/linux/x64/release/bundle/universal_downloader
```

## How to Use

Open the Linux application with the bundle command above. To run it directly
from the source project during development, use:

```sh
flutter run -d linux
```

### 1. Paste a Video Link

On **Home**, paste a YouTube video link into the URL field. The clipboard button
can paste a link you have already copied. Click **Fetch Info** and wait for the
video's details and available formats to appear.

![Home screen with URL input and Fetch Info button](docs/screenshots/home.png)

### 2. Review the Video Details

Check the video's title, duration, and available audio languages. Choose
**Video Quality**, then review the **Audio** language. Select Arabic when it is
available, or choose another listed language. Available tracks depend on the
video; check the selected language before downloading.

![Fetched video details with available formats and Arabic audio selected](docs/screenshots/video-details.jpg)

### 3. Choose Download Options

Keep automatic audio selection enabled to use the best track in the selected
language, or turn it off to choose an audio quality. Choose a **Container**
(Auto, MP4, or MKV), then use **Choose** under **Output Folder** to select where
the file will be saved. Click **Download** to start.

**Subtitles** defaults to **None** each time you fetch a video. To include
captions, choose one of the available tracks and turn on **Add separate subtitle
file** before downloading. The toggle defaults to off and resets on each fetch.
Turning it off keeps the selected language but downloads no subtitle file.
It is disabled while **None** is selected. Automatic
captions are labeled **automatic** or **auto-translated**; subtitle language is
independent of audio language. Videos without supported subtitle tracks keep
this field disabled.

![Subtitle selection with Arabic captions selected](docs/screenshots/subtitles.png)

Auto-translated captions wait about one minute before downloading to allow
YouTube's caption session to become ready. The task shows **Preparing translated
subtitles** and remains cancellable. This addresses the
[known yt-dlp/YouTube HTTP 429 issue](https://github.com/yt-dlp/yt-dlp/issues/13831).
If YouTube still returns HTTP 429, wait a few minutes before retrying.

![Download waiting for translated subtitles](docs/screenshots/preparing-subtitles.png)

With **Add separate subtitle file** on, selected captions are saved beside the
video as a separate `.vtt` file (`.srt`
when VTT is unavailable), using the same filename plus the language code, such
as `Video.ar.vtt`. They are not burned into or embedded in the video. A selected
subtitle download failure fails the task; turn off **Add separate subtitle file**
or select **None** and start a new task
to download without captions. Keep **Automatic downloads** off to choose a
subtitle track before starting. Caption downloads use
[yt-dlp's subtitle options](https://github.com/yt-dlp/yt-dlp#subtitle-options).

![Video quality, audio quality, container, and output folder options](docs/screenshots/download-options.png)

### 4. Monitor Your Downloads

The app opens **Downloads**, where each task shows its progress through
downloading, merging when needed, and verification. When a task shows
**Completed**, click its folder icon (**Open location**) to open the containing
folder with the saved video selected. If the file manager does not support
selection, the app opens the folder instead.
Active tasks have a **Cancel** button; failed tasks provide **View details** and
**Retry**. Use **Clear finished** to remove finished entries from the list.

![Downloads screen showing a completed video and an active download](docs/screenshots/downloads.png)

New YouTube downloads automatically include the original YouTube cover image
inside the saved MP4 or MKV when the video metadata provides one. Video and
audio are copied without re-encoding. Combined WebM downloads use MKV to support
the attachment. A cover download or embedding failure fails the task so it can
be retried. Existing downloads are not modified.

![Downloaded video showing its YouTube thumbnail beside the separate Arabic subtitle file](docs/screenshots/downloaded-video-with-subtitles-and-thumbnail.png)

MP4 uses FFmpeg's [embedded cover support](https://ffmpeg.org/ffmpeg.html#Main-options);
MKV stores a JPEG attachment. File managers and players may still choose a video
frame for previews. On Linux, `ffmpegthumbnailer` needs its `-m` option to prefer
embedded artwork; existing cached previews may need refreshing.
After changing a thumbnailer definition, restart Nemo so it loads the new
command. Refreshing the folder alone may keep using the previous command.

### 5. Configure Settings

In **Settings**, configure the default folder, video quality, and preferred
audio language (`ar` for Arabic or `en` for English). Keep **Automatic downloads**
off when you want to review the formats before each download.

![Settings screen with dependency status and default download preferences](docs/screenshots/settings.png)

If a missing-dependency banner appears, install `yt-dlp`, `ffmpeg`, and `ffprobe`
as described in Requirements. For tools installed outside your `PATH`, enter
their executable paths in **Settings**, then click **Check again**.

## Test

```sh
flutter analyze
flutter test
```

Integration tests run only when `yt-dlp`/`ffmpeg`/`ffprobe` are on `PATH` and
skip otherwise. The network test hits a well-known public video.

## Where files live

- App data, logs and temporary download artifacts:
  `~/.local/share/universal_downloader/`
- Debug log: `~/.local/share/universal_downloader/logs/universal_downloader.log`

## Architecture

```
lib/
├── app/              app shell, composition root, theme, routes
├── core/
│   ├── errors/       typed exceptions
│   ├── models/       MediaInfo, VideoFormat, AudioFormat, DownloadOptions
│   ├── process/      ProcessRunner (argv based, no shell), CancelToken, progress parser
│   ├── services/     DependencyChecker, LogService, MediaAssembler (merge + verify)
│   └── utils/        filename sanitization, path helpers, format helpers
├── providers/        provider interface + registry + format selection
│   ├── youtube/      YouTube provider, yt-dlp extractor, JSON → models mapper
│   └── direct/       direct media URL provider
├── downloads/        task queue, state machine, repository (temp/output naming)
├── settings/         app settings + persistence
└── ui/               pages and widgets (home, downloads, settings)
```

Download steps for a two-stream (video-only + audio-only) YouTube task:

1. Download the original cover, when available, and selected subtitles into the
   task's temporary directory.
2. Download the selected video stream to `temp/download_task_<id>/video.tmp`.
3. Download the selected audio stream to `audio.tmp`.
4. Merge both with ffmpeg stream copy and embed the cover. Cover-enabled merges
   omit `-shortest` to prevent the still image from truncating the video.
   Merges write into a hidden staging directory in the output folder, then
   atomically rename the finished file so thumbnailers never see partial output.
5. Verify the media streams and expected cover with ffprobe, then copy any
   selected subtitles beside the video.
6. Clean up temp files only after successful verification and subtitle saving.

On failure the temp files are intentionally kept so the user can retry without
re-downloading. Cancellation uses cooperative tokens: SIGTERM, then SIGKILL
after a short grace period.
