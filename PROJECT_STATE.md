# Universal Downloader: Project State

Last updated: 2026-10-05 (Africa/Cairo).

## Current Checkpoint

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

Universal Downloader is a Flutter Material 3 Linux desktop app. Dart package:
`universal_downloader`; folder: `video_downloader`; version: `1.0.0+1`.

| Area | Responsibility |
| --- | --- |
| `lib/main.dart`, `lib/app/` | AppController startup, providers, settings, checks, queue composition. |
| `lib/providers/` | Provider contracts, registry, format selection; YouTube extraction/download and direct HTTP(S). |
| `lib/downloads/` | Queue, task state, retry/concurrency, temporary files. |
| `lib/core/process/` | Argument-array execution, output capture, SIGTERM/SIGKILL cancellation. |
| `lib/core/services/` | Media assembly/verification, dependency checks, logging, file reveal. |
| `lib/core/tools/` | Runtime manifests, executable resolution, staged updates, release checks. |
| `lib/settings/`, `lib/core/utils/` | Preferences, filenames, application data paths. |
| `lib/ui/pages/`, `lib/ui/widgets/` | Home, Downloads, Settings and shared controls. |
| `tool/` | Runtime pins, build/packaging, clean-container setup, smoke check. |

Only YouTube and direct HTTP(S) providers are registered. Social-provider files
are stubs; other platform directories do not establish working support.

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
Output defaults to Videos when present, otherwise Downloads, unless overridden.

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

## Next Session

Read this file, inspect relevant source, and follow the user's current request.
Use main only and one-line Conventional Commits when commits are requested.
Use the git-commit skill for commit work. Do not publish releases, fix unrelated
observations, or treat follow-up suggestions as standing authorization.
