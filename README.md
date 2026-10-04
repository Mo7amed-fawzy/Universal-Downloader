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

1. Download the selected video stream to `temp/download_task_<id>/video.tmp`.
2. Download the selected audio stream to `audio.tmp`.
3. Merge both with ffmpeg stream copy (`-c:v copy -c:a copy -shortest`).
4. Verify the final file with ffprobe.
5. Clean up temp files only after successful verification.

On failure the temp files are intentionally kept so the user can retry without
re-downloading. Cancellation uses cooperative tokens: SIGTERM, then SIGKILL
after a short grace period.
