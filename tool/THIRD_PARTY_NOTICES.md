# Included media tools

Universal Downloader runs these unmodified tools as separate processes:

- yt-dlp: https://github.com/yt-dlp/yt-dlp. Source is under the Unlicense;
  the standalone Linux executable includes third-party components and is
  distributed under GPLv3+. See the included third-party licenses.
- FFmpeg and FFprobe: https://ffmpeg.org, LGPL build supplied by
  https://github.com/BtbN/FFmpeg-Builds. The exact build, checksum and upstream
  URL are recorded in manifest.json. Included license files describe the
  bundled libraries. Build recipes: https://github.com/BtbN/FFmpeg-Builds.
- Deno: https://github.com/denoland/deno, MIT license; its LICENSE.md includes
  third-party notices.
- yt-dlp's standalone executable includes yt-dlp-ejs. Full YouTube support
  uses the included Deno runtime.

The manifest identifies the versions used in this package. Keep all notices
with redistributed packages. Before public distribution, provide the complete
corresponding source and build materials required by the licenses of the exact
binary builds; upstream download links alone are not a source distribution.

## Android preview

Android uses `io.github.junkfood02.youtubedl-android:library:0.18.1` and
`ffmpeg:0.18.1` from Maven Central. The wrapper source is available at
https://github.com/yausername/youtubedl-android and is licensed GPL-3.0.
These artifacts include Android builds of Python, QuickJS, FFmpeg, FFprobe,
and their native dependencies; the Linux BtbN build/license description above
does not describe these Android binaries.

The APK overrides the wrapper's older extractor with the unmodified official
yt-dlp zipapp pinned in `android_tools.json`, which also includes yt-dlp-ejs.
Runtime unpacking uses local APK resources; it does not download executable
updates. Preserve the upstream wrapper and individual component license notices
and provide required corresponding source/build materials for the exact Android
binaries before public redistribution. This preview does not assemble a complete
Android corresponding-source distribution.
