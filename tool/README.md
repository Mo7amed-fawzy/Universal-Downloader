# Desktop packaging and tool updates

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
Linux builds, including `flutter run -d linux`, prepare the runtime automatically
when it is missing and stop if any included executable is unavailable. The app
uses only its included or verified updated tools unless a custom executable path
is set in Settings.

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

## Windows x64

The Windows source and packaging path are implemented; native compilation and
execution must be validated on Windows. This Linux session checked Dart logic,
Windows download hashes/PE architecture, and packaging tests, not a Windows EXE.

On the Windows **developer** machine, install Flutter (baseline 3.44.6/Dart 3.12.2),
Visual Studio with **Desktop development with C++**, and Python 3.11 or newer.
These are build requirements only. Flutter's official setup guide is at
https://docs.flutter.dev/platform-integration/windows/setup.

From the project root in PowerShell:

```powershell
flutter doctor -v
flutter pub get
flutter analyze --no-pub
flutter test --no-pub test/unit/windows_platform_test.dart test/unit/log_service_test.dart test/unit/filename_sanitizer_test.dart
python tool/test_windows_packaging.py
python tool/build_windows.py
.\build\windows\x64\runner\Release\universal_downloader.exe
```

`build_windows.py` performs the following steps:

1. Downloads the exact URLs/checksums in `tool_versions_windows.json` into
   `.tool-cache`, then prepares `build/tool-runtime-windows` and its file manifest.
   Tools are official standalone yt-dlp, Deno, and BtbN's static LGPL FFmpeg/FFprobe.
2. Copies release x64 Visual C++ CRT DLLs from the developer's Visual Studio
   redistributable directory into the tools runtime, so updated tools remain
   self-contained. `VCToolsRedistDir` can specify the installed redist directory;
   otherwise `vswhere` selects the latest C++ installation. Debug CRTs are excluded.
3. Runs all four executable version checks and `flutter build windows --release`.
   CMake copies the complete runtime and app-local compiler runtime DLLs.
   Release/Profile installation fails without a prepared runtime; an inspection-only
   runtime made with `--skip-execution` cannot be packaged by CMake.
4. Checks packaged files/hashes, compiles `smoke_runtime.dart`, and runs local
   MP4/MKV artwork merges, FFprobe verification, JavaScript, and Windows child-process
   cancellation. The smoke process PATH contains only Windows system directories.
5. Writes `dist/universal-downloader-windows-x64.zip`, `runtime-windows-x64.zip`,
   `runtime-windows-x64.json`, and SHA-256 sidecars. It does not publish anything.

The app ZIP is portable: extract the entire `universal-downloader` folder and
run `universal_downloader.exe`. Do not send the EXE alone. End users need no
Flutter, Visual Studio, Python, Deno, or media-tool installation. Windows 10/11
supplies the UCRT; the package includes the compiler runtime beside the app.
Microsoft documents app-local deployment at
https://learn.microsoft.com/en-us/cpp/windows/deployment-in-visual-cpp.
Runtime DLL updates therefore require delivering an updated package.

For debug development, run `python tool/prepare_tools.py --platform windows-x64`
then `flutter run -d windows`. On Linux, `--skip-execution` can download and
inspect Windows files, but does not provide the Visual C++ runtime, run EXEs,
or prove a deployable package. Python packaging tests run on either OS.
Some older Linux tests use `/bin/sh` fixtures; the command above selects portable
Windows tests rather than assuming every existing test runs on Windows.

Before distributing the first Windows build:

- Launch the extracted Release app by double-clicking it on clean Windows,
  preferably Windows Sandbox without Python, media tools, or a developer PATH.
  Do not rely only on `flutter run` or the build machine's installed CRT.
- Check all four tools in Diagnostics. Test a path containing spaces and Arabic,
  an actual YouTube download with Arabic audio/subtitles, MP4/MKV artwork,
  cancellation, retries, and Explorer's Open location action.
- Test installing/restoring a local tool update and replacing an existing active
  update. Windows file locking and native process cancellation need real OS coverage.
- Preserve the verified `.tool-cache` when moving machines: BtbN daily assets can
  expire upstream. Re-pin and retest if an upstream download is removed; never
  disable checksum verification or silently switch to `latest`.

Known folders are queried via `SHGetKnownFolderPath`; the app writes to
`%LOCALAPPDATA%/UniversalDownloader`, not the installation directory. Windows
updates use `runtime-windows-x64.*` and cannot activate a Linux runtime.
No Windows build, signature, installer, or clean-machine run has been produced
in this Linux session. The next session on the user's Windows machine should
start with `PROJECT_STATE.md` and the commands above. On 2026-10-07 a Windows
machine produced `dist/universal-downloader-windows-x64.zip` with passing
build-time smoke checks; clean-machine startup and live download validation
remain outstanding.

## Redistribution

Keep `tools/licenses/` and the manifest with every package and update. Review
[third-party notices](THIRD_PARTY_NOTICES.md) before public distribution. The
current packager collects notices and exact binary provenance; it does not
assemble the complete corresponding source and build materials required by
some bundled components. Prepare those materials for the exact binaries before
publishing a public download. The source repository and upstream links alone
do not complete that step.
