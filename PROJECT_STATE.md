# Universal Downloader: Project State

Last updated: 2026-10-05 (Africa/Cairo).

## Current Checkpoint

Android foreground-download preview is implemented on top of the OS/provider
abstractions. All tools are included in each APK; users install no additional
apps, interpreters, or media tools. Android 10+ (API 29) is required. Linux remains
supported. Changes are organized into separate local commits for provider/OS
abstraction, Android runtime, mobile UI, release startup repair, and documentation.
The abstractions support future extensions; only Linux/Android runtimes and
YouTube/direct HTTP(S) providers are implemented. No push or public release was
performed.

- `AndroidDownloadPlatform` initializes through a Kotlin MethodChannel plugin.
  Python, QuickJS, FFmpeg, and FFprobe come from youtubedl-android 0.18.1 Maven
  artifacts. Native executables run from `nativeLibraryDir`; support files are
  unpacked locally. `BundledTools` launches argument arrays in worker threads,
  returns output/progress, and cancels the process group.
- Gradle embeds official yt-dlp 2026.08.19 with its EJS solver, overriding the
  wrapper's older extractor. `tool/android_tools.json` pins its URL/SHA-256.
  First developer builds download dependencies; runtime startup does not download
  tools. Native/runtime updates occur with a new APK. Desktop paths and arbitrary
  yt-dlp overrides are not exposed on Android.
- Providers, quality/language selection, stream-copy merging, and verification
  remain shared. `DownloadTaskResult` carries subtitle sidecars. Android stages
  privately and publishes video plus subtitles via pending MediaStore rows into
  a unique folder under Downloads/UniversalDownloader. Failed/cancelled copy
  rolls back its rows; local completed files are deleted only after success.
  The queue waits for publication and retains a content URI for Open video.
- Mobile layout uses bottom navigation, stacked URL controls, compact thumbnails,
  and bounded labels. Android output/diagnostics controls describe APK behavior.
  Startup displays preparation progress and a recoverable error screen.
- `DownloadPlatformFactory.create` is now async. `CommandRunner`, provider
  factories/registry, and `ToolConfigurableProvider` preserve platform separation.
  Direct-provider verification uses its injected command runner.

### Checks Actually Run

- `flutter analyze --no-pub`: passed after final source/test changes.
- Broad local unit/widget run including `android_layout_test.dart`: 125 passed.
  Includes 8 Android channel/storage/cancellation tests and responsive checks at
  320, 360, 412, and 1024 logical pixels. Linux and Android widget fixtures use
  explicit themes; global debug platform overrides were removed from tests.
- Local subtitle + cover/merge integration tests: 13 passed with real host tools.
- `flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64`:
  succeeded. ARM64 APK: 99321144 bytes; x86_64: 102641841 bytes. Both use the
  template's debug signing key and are previews, not production-signed releases.
  APK inspection verified all native tools and the exact pinned yt-dlp hash
  inside the shrunk resource (`res/Nc`).
- Real Android 13 x86_64 emulator smoke (`tool/android_smoke.dart`): all five
  tools executed (Python 3.12.11; FFmpeg/FFprobe 7.1.1; yt-dlp 2026.08.19;
  QuickJS evaluated JavaScript). Actual MP4/MKV stream-copy merges with artwork
  passed FFprobe checks and published alongside Arabic VTT files via MediaStore.
  Cancellation passed after mapping interrupted process readers to cancellation.
- Live emulator test: TfoJ55nx1S4 returned 20 audio languages including Arabic.
  jNQXAC9IVRw downloaded through the shared provider and published successfully
  to `content://media/external/downloads/1000000032`. This was a short English
  video download; an actual Arabic-track download was not tested on Android.
- Normal x86_64 release APK installed/launched on the emulator and the Home UI
  was visually checked. A pre-existing emulator System UI ANR dialog had to be
  dismissed/restarted; no app startup exception was observed. Screenshot:
  `/tmp/ud-android-home-final.png`. Physical-device startup validation is below.
- `git diff --check`: passed. Commit-only review checked each staged diff;
  no builds or application tests were rerun while organizing the commits.

### Physical Android Release Startup Fix (2026-10-05)

Reproduced the installed universal release APK crashing on Realme C53/RMX3760,
Android 14, ARM64. The matching R8 mapping decoded `k3.a` as Commons Compress
`AsiExtraField`: its reflective no-argument constructor had been removed.
`ExtraFieldUtils` threw `ExceptionInInitializerError` during `YoutubeDL.init`
while unpacking the bundled tools. Previously extracted tools can mask this
first-start path; emulator/update checks alone did not cover it.

- Added `android/app/proguard-rules.pro`, wired into the release build, keeping
  ZIP extra-field implementations and their public no-argument constructors.
  Class-name obfuscation remains allowed; release shrinking remains enabled.
- `flutter build apk --release`: passed. R8 seeds/mapping confirm the formerly
  removed constructor survives. Installed the resulting universal APK over the
  failing installation via ADB, without clearing data or using `flutter run`.
  Home was visually verified, the process stayed alive, and its crash buffer
  was empty. Force-stop/relaunch also passed.
- Current fixed artifact: `build/app/outputs/flutter-apk/app-release.apk`
  (285.0 MB decimal). SHA-256:
  `ec475aa9336e943eceff4ce7cdd78c7b97533cdf027197c8df492dc44230e4ec`.
  Older split APKs were not rebuilt and still predate this fix.
- `git diff --check`: passed. No Dart changes, analysis, or unit tests in this
  packaging-only fix. No phone download/merge test or uninstall/reinstall cycle
  was performed. Screenshot: `/tmp/ud-realme-release-fixed.png`.

For future release validation, include fresh runtime extraction in addition to
updates; README documents this regression check. Physical ARM64 full tool,
download, merge, and publication validation remains outstanding.

### Local Emulator Troubleshooting (2026-10-05)

Android 16 `pixel_api36_google_apis` was running with `-gpu host -memory 12000
-cores 2 -accel on` and showing a System UI ANR. KVM availability was verified.
Stopped it with `adb -s emulator-5554 emu kill` and restarted with `-gpu host
-no-snapshot -no-boot-anim -memory 4096 -cores 2 -accel on`. Boot completed,
but a startup SystemUIService ANR still occurred (20-second timeout; guest CPU
98% in the ANR report). After startup settled and selecting Wait, Home and
Settings were visually verified responsive; a subsequent Settings launch took
408 ms. This is recovery, not proof the startup ANR cannot recur. No AVD data
was wiped and no persistent AVD configuration was edited. API 33 was not
retested in this troubleshooting session. Emulator log and final screenshot:
`/tmp/ud-emulator-api36.log`, `/tmp/ud-emulator-api36-recovered.png`.

### APKs and Remaining Android Work

Current fixed phone APK: `build/app/outputs/flutter-apk/app-release.apk`.
Rebuild split APKs before use; existing ARM64/x86_64 split files predate the
release startup fix above.

Keep the app open while downloading. Foreground notifications, reliable
background execution, queue persistence/recovery after process death, and
sharing are not implemented. Native MediaStore cleanup after abrupt process
death is not yet implemented. Test the full download flow on ARM64 hardware,
validate 16 KB page-size compatibility, and test actual Arabic audio/subtitles
before wider distribution.
Opening a saved video requires an installed player and was not exercised live.
Prepare production signing and complete license/corresponding-source materials
for the Android binaries before public release; see THIRD_PARTY_NOTICES.md.
Facebook/Instagram/TikTok/X remain unregistered stubs.

## Previous Verified Linux Bundle Checkpoint

The requested self-contained Linux tool bundle is implemented and organized into
focused packaging, application, and documentation commits. The app still uses
yt-dlp, FFmpeg, and FFprobe internally, and now
includes Deno for YouTube JavaScript extraction. Users of the packaged app do
not install these tools or Python separately. Normal GTK/EGL desktop libraries
remain system requirements. Linux x86_64 is the supported package target.

- `tool/prepare_tools.py` downloads exact versions and checksums from
  `tool/tool_versions.json`, stages executables, licenses, and a file manifest.
- `python3 tool/build_linux.py` prepares tools, builds Flutter release, and writes
  the app tarball, tool update ZIP, metadata, and checksums into ignored `dist/`.
  CMake refuses a release build without a prepared runtime.
- `ToolPaths` prefers a validated active update or included `tools/` beside the
  app executable. Saved custom executable paths remain supported. Source-only
  debug runs without a runtime may fall back to PATH.
- Versions and paths moved from the main Settings view into
  **Advanced → Diagnostics**, with Check tools, Update tools, and Use included
  tools. Restoring also clears custom executable overrides.
- Updates use the latest stable GitHub release in this project's repository.
  ZIP and file hashes, paths, revision, and executable version commands are
  validated in staging before activating an immutable directory. Failed
  installations preserve the prior active bundle. Installation runs in a
  background isolate. Queued/active downloads block changing tools.
- Bundled YouTube execution explicitly uses its Deno and FFmpeg paths, ignores
  external yt-dlp configuration, and disables remote JavaScript components
  because the standalone yt-dlp includes its solver. Language selection and
  stream-copy paths remain intact.

Current pins: yt-dlp 2026.08.19, Deno 2.9.7, FFmpeg/FFprobe LGPL
n8.1.3-14-g330caae0c1-20261003; bundle revision 2026100401.

### Checks Actually Run

- `flutter analyze --no-pub`: passed after the final functional changes.
- Broad local unit/widget run: 98 tests passed (unit directory, widget_test,
  subtitle_picker, downloads_page, download_location_button).
- Focused update/UI run: 12 tests passed; the subsequent command-name override
  regression brought the bundle suite to 11 passing tests (plus two UI tests).
- `python3 tool/build_linux.py`: release and both archives built successfully;
  app tarball 212229108 bytes, tool ZIP 202425033 bytes.
- Compiled `tool/smoke_runtime.dart`: all four included tools ran. Actual local
  FFmpeg merges and FFprobe verification passed for MP4/MKV with artwork;
  included Deno evaluated JavaScript.
- The same runtime smoke passed in a fresh Ubuntu 24.04 container with network
  disabled and no yt-dlp, FFmpeg, FFprobe, Deno, or Python installed on PATH.
- Live metadata using the included tools succeeded for TfoJ55nx1S4: video/audio
  formats and multilingual tracks including Arabic were returned. This was
  metadata extraction, not a complete video download.
- The actual 202 MB tool update ZIP installed successfully through a background
  isolate, validated all four executables, activated, and reset its pointer.
  Temporary validation script: `/tmp/universal-smoke-update.dart`.
- Headless GUI startup passed in fresh Ubuntu with GTK/EGL libraries, no network,
  and no system media tools or Python. Xwininfo confirmed the app's 1280x760
  window was viewable after Flutter's first frame. The container emitted an ATK
  accessibility warning. The test image initially lacked libEGL; its Dockerfile
  now includes the desktop graphics libraries. Use `docker run --init` for Xvfb
  signal handling. Validation script: `/tmp/ud-check-window.sh`.

### Remaining Release Work

No GitHub release or assets were published, and network update installation
from a published release has not been exercised. The updater handles absent
releases; attach matching runtime ZIP/JSON assets when publishing a tested
stable release. SHA-256 provides integrity; authenticity relies on HTTPS and
repository release permissions, not a separate signing key.

The packager includes license notices and binary provenance, but does not
assemble complete corresponding source/build materials for redistribution.
Prepare those for the exact bundled binaries before a public release. See
`tool/README.md` and `tool/THIRD_PARTY_NOTICES.md`. The FFmpeg pin is a daily
upstream release with limited retention; preserve its verified download cache
or re-pin and test a replacement when necessary.

## Existing Functionality and Important Findings

- YouTube downloads embed the original cover when metadata supplies one. MP4
  uses an attached JPEG; MKV uses a cover attachment. Combined WebM uses MKV.
  Video/audio are copied without re-encoding. A requested cover failure fails
  the task. Cover-enabled merges omit `-shortest`, which previously truncated
  video packets; packet-preservation tests cover this.
- MediaAssembler writes into a hidden destination-side staging directory and
  atomically publishes completed media. Failure/cancellation preserves existing
  destination files and cleans staging. Raw failed inputs remain for retry.
- Subtitles default to None. The separate subtitle-file toggle defaults off;
  explicitly selected captions save as language-tagged VTT/SRT beside the video.
  Auto-translated captions wait 60 seconds to address a reproduced YouTube 429.
- Open location uses `gdbus` FileManager1.ShowItems with an encoded file URI and
  five-second timeout, then falls back to `xdg-open` on the folder. Tests and
  live Nemo selection passed on 2026-10-04.
- Nemo thumbnail troubleshooting confirmed that embedded covers were present.
  A per-user ffmpegthumbnailer definition with `-m` prefers artwork, and Nemo
  needed restarting to reload it. A later controlled test reproduced SIGPIPE
  when thumbnailer stderr had no reader. Restarting Nemo with stderr redirected
  and refreshing only the video's stale cache restored its YouTube preview.
  Always redirect long-lived GUI process stdout/stderr when launching via tools.
  These desktop fixes are not portable app settings; file managers may choose
  video frames despite embedded artwork.
- README uses `docs/screenshots/downloaded-video-with-subtitles-and-thumbnail.png`.

Earlier relevant commits: `872e1d7` atomic media publication, `e284efc` subtitle
file toggle, `427f5ff` media documentation/screenshot, `2f8ae05` reveal/select
file. The bundling changes are committed locally on main; no push was requested.
The commit-only review checked staged diffs and preserved application file
contents. No build or application tests were rerun for this commit request;
the successful implementation checks above remain the validation evidence.
Use `git status -sb` and `git log` for the current local/remote relationship.

## Architecture

Universal Downloader is a Flutter Material 3 Linux desktop app with an Android preview. Dart package:
`universal_downloader`; folder: `video_downloader`; version: `1.0.0+1`.

| Area | Responsibility |
| --- | --- |
| `lib/main.dart`, `lib/app/` | AppController startup, providers, settings, checks, queue composition. |
| `lib/platform/` | OS detection, DownloadPlatform contract, Linux and Android runtime services. |
| `lib/providers/` | Provider contracts, factories, injected dependencies, registry, format selection; YouTube and direct HTTP(S). |
| `lib/downloads/` | Queue, task state, retry/concurrency, temporary files. |
| `lib/core/process/` | CommandRunner contract; local argument-array execution, output capture, SIGTERM/SIGKILL cancellation. |
| `lib/core/services/` | Media assembly/verification, dependency checks, logging, file reveal. |
| `lib/core/tools/` | Runtime manifests, executable resolution, staged updates, release checks. |
| `lib/settings/`, `lib/core/utils/` | Preferences, filenames, application data paths. |
| `lib/ui/pages/`, `lib/ui/widgets/` | Home, Downloads, Settings and shared controls. |
| `tool/` | Runtime pins, build/packaging, clean-container setup, smoke check. |

Only YouTube and direct HTTP(S) providers are registered. Social-provider files
are stubs; Linux and the Android preview have runtime implementations.

YouTube metadata/DASH audio uses `ios,web_embedded,default`; video uses
`web_embedded,default`; HLS uses `tv_embedded`. Metadata combines JSON with a
secondary language-tagged m3u8 format listing. Synthetic HLS audio choices map
to combined streams. Failed stream downloads can refresh metadata and remap
format IDs. Preserve multilingual choices and stream-copy behavior.

## Validation and Local Data

SDK baseline: Flutter 3.44.6 / Dart 3.12.2; pubspec requires Dart ^3.12.2.

```sh
flutter analyze --no-pub
flutter test --no-pub test/unit test/widget_test.dart test/subtitle_picker_test.dart test/downloads_page_test.dart test/download_location_button_test.dart test/tool_diagnostics_test.dart --reporter expanded
flutter test --no-pub test/integration/subtitle_download_test.dart --reporter expanded
flutter test --no-pub test/integration/media_cover_test.dart --reporter expanded
flutter test --no-pub test/integration/media_pipeline_test.dart --name 'MediaAssembler|cancellation' --reporter expanded
python3 tool/build_linux.py
dart compile exe tool/smoke_runtime.dart -o build/runtime-smoke
./build/runtime-smoke build/linux/x64/release/bundle
```

The full test suite includes live YouTube requests. Selected local media tests
need tools on PATH and may skip without them; distinguish skips from passes.
The packaging smoke uses absolute included paths. `tool/README.md` documents
its optional live metadata argument and Docker workflow. Do not claim full live
download success from metadata extraction or local media generation.

Data root: `$XDG_DATA_HOME/universal_downloader`, default
`~/.local/share/universal_downloader`. Logs are under `logs/`, task artifacts
under `temp/download_task_<id>/`, updates under `tools/`. Preferences use
shared_preferences key `settings_v1`. Queue history/theme are not persisted.
Linux output defaults to Videos when present, otherwise Downloads, unless overridden.
Android app data is under files/universal_downloader; completed public downloads
are under Downloads/UniversalDownloader in a unique folder per task.

## Unresolved Source Observations

These pre-existing observations are outside the bundling request:

1. Direct-provider metadata lacks dimensions required by Home's video selector;
   verification also expects both video and audio for audio-only inputs.
2. HLS language mapping keeps the first progressive per language; the provider
   ignores the selected DASH height and verifies no expected height on that path.
3. Home selects the first language if the preferred one is absent, before the
   configured fallback is applied during download selection.
4. Language verification tolerates missing/und/eng tags and does not generally
   normalize two-letter versus three-letter codes; spoken language is not audited.

## Legacy Project Review

Read-only source/artifact review on 2026-10-05 of the older project at
`/media/abdin_02/MyMiscellaneous/study/self learning/Moblie App/My Apps/video_downloader`.
It contains a Windows x64 Debug EXE and Windows FFmpeg/FFprobe/yt-dlp binaries,
but its current downloader uses youtube_explode_dart and Process.run('ffmpeg').
The bundled executable path is not passed by DownloadCubit. Windows copying
uses inconsistent source/build paths; treat it as a reference, not a verified
portable build. Android native code is the default Flutter activity; the
ffmpeg_kit_flutter dependency has no calls in lib/, and no APK/AAB was found
under build/. No native background/storage integration was found. The upstream
original FFmpegKit is retired; its official repository points to FFmpegKitNext.
Useful ideas: platform-aware directories and Dart extraction. Do not copy the
download pipeline wholesale: it lacks language/subtitle selection, ignores
YouTube cancellation and merge exit status, and dereferences a null video
selection when no resolution is supplied. Neither old platform was built or
run during this review. Keep the current app as the implementation base.

## Next Session

Read this file, inspect relevant source, and follow the user's current request.
Android follow-ups are hardware validation and background/queue recovery; follow
the current user request before starting them.
Use main only and one-line Conventional Commits when commits are requested.
Use the git-commit skill for commit work. Do not publish releases, fix unrelated
observations, or treat follow-up suggestions as standing authorization.
