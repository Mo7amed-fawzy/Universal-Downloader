# Linux packaging and tool updates

The supported package is Linux x86_64. It includes standalone yt-dlp with its
JavaScript solver, Deno, and an LGPL FFmpeg/FFprobe build. App processes use
absolute paths to these files. Python and system media tools are unnecessary
on the user's computer; normal GTK desktop libraries are still required.

## Build

```sh
flutter pub get
python3 tool/build_linux.py
```

Python 3.11 or newer is a build dependency. `prepare_tools.py` downloads the
versions pinned in `tool_versions.json`, checks the published SHA-256 hashes,
and stages executables, licenses, and a per-file manifest in `build/tool-runtime`.
Downloads are cached in `.tool-cache`. CMake includes this runtime in the app;
release builds fail when it has not been prepared. For debug development,
run `python3 tool/prepare_tools.py` before `flutter run -d linux` to use it too.

The build creates:

- `dist/universal-downloader-linux-x64.tar.gz`: complete app folder.
- `dist/runtime-linux-x64.zip`: tool files and manifest for the updater.
- `dist/runtime-linux-x64.json`: platform, revision, and update ZIP checksum.
- `.sha256` files for the app archive and tool ZIP.

Keep the app's entire extracted directory together. Tool preparation currently
uses an upstream FFmpeg daily release, which upstream may remove later. Preserve
the verified cache for repeat builds, or update the pin and checksum to another
tested release when that happens.

## Updates

Increment the integer `revision` in `tool_versions.json` whenever changing the
tool bundle. Set exact upstream release URLs and verify checksums against their
published checksum files before building. Test the new bundle before publishing.

Attach `runtime-linux-x64.zip` and `runtime-linux-x64.json` from the same build
to a stable release of `Mo7amed-fawzy/Universal-Downloader` on GitHub. The updater
uses that repository's latest stable release; missing releases or assets produce
a friendly message. This build does not publish anything automatically.

Updates verify the archive SHA-256 and every manifest file, reject unsafe paths
and non-advancing revisions, and run each tool's version command. The installer
activates the new directory only after validation succeeds. SHA-256 checks
detect corruption; release authenticity relies on HTTPS and the repository's
release permissions, rather than a separate signing key.

Updated tools live under `$XDG_DATA_HOME/universal_downloader/tools`, defaulting
to `~/.local/share/universal_downloader/tools`. **Settings → Advanced → Diagnostics**
provides update, check, and restore controls. Restoring clears custom executable
paths and removes the active update pointer. A newer included bundle takes
precedence over an older installed update. Old update directories are retained;
they are not removed while another app process might still be using them.

## Verify

```sh
flutter analyze --no-pub
flutter test --no-pub test/unit test/widget_test.dart test/subtitle_picker_test.dart test/downloads_page_test.dart test/download_location_button_test.dart test/tool_diagnostics_test.dart
dart compile exe tool/smoke_runtime.dart -o build/runtime-smoke
./build/runtime-smoke build/linux/x64/release/bundle
```

The smoke check runs the included tools, creates local media, embeds artwork
into MP4 and MKV with the app's assembler, and verifies both outputs. To also
fetch live YouTube metadata and audio languages, pass a video URL as its second
argument. That network check does not download a complete video.

For a fresh Ubuntu environment without installed media tools or Python:

```sh
docker build -t universal-downloader-clean-test -f tool/clean_linux.Dockerfile tool
docker run --rm --network none \
  -v "$PWD/build/linux/x64/release/bundle:/opt/app:ro" \
  -v "$PWD/build/runtime-smoke:/opt/runtime-smoke:ro" \
  universal-downloader-clean-test /opt/runtime-smoke /opt/app
```

The container supplies GTK/EGL libraries and Xvfb for optional headless app
startup checks. Use `docker run --init` when launching Xvfb so signal handling
works correctly. It does not establish compatibility with every Linux
distribution.

## Redistribution

Keep `tools/licenses/` and the manifest with every package and update. Review
[third-party notices](THIRD_PARTY_NOTICES.md) before public distribution. The
current packager collects notices and exact binary provenance; it does not
assemble the complete corresponding source and build materials required by
some bundled components. Prepare those materials for the exact binaries before
publishing a public download. The source repository and upstream links alone
do not complete that step.
