# Universal Downloader: Project State

Last updated: 2026-10-12 (Africa/Cairo).

## Current Checkpoint: Reveal and Highlight Previous Download

Clicking Already downloaded now routes to the exact matching completed task in
Downloads. When multiple records match a video, the most recent completion is
selected; multi-link input targets the first matched input video. A typed route
argument carries the task ID. The warning remains a compact amber line below
Provider and does not block downloading.

Downloads keeps its header visible and opens its lazily built, variable-height
history at the selected row using a centered sliver list. Original record order
and access to records above/below are preserved without rendering the whole
history or estimating row heights. A history scroll controller bounds the offset
using the trailing sliver's measured extent: revealing a final row does not leave
extra empty space below it, and short histories retain their normal placement.
The bounds also update when the marker disappears. After the route transition
finishes, an arrow and Downloaded before label appear above the card with a brief amber border/glow
pulse. The label and border disappear three seconds after arrival, restoring the
normal card without resetting the scroll position. Reduced motion shows a static
marker for the same duration. Ordinary Downloads navigation has no marker.
Removing the target clears the marker; timers, route/list listeners and
controllers are disposed.

Verified on 2026-10-12 after the spacing fix: reproduced extra trailing space
with failing tests for 2-row and 30-row histories (212px and 492px differences).
All 39 Home/Downloads widget tests now pass, including normal placement after
revealing the final row and after marker expiry. The arrival tests still verify
the 3-second duration, reduced motion, and lazy access to row 800 of 1000.
Earlier history matching tests passed before these visual changes.
Analysis and whitespace checks passed.
Hot reload succeeded; no runtime errors were reported. No live download or
release build was started. Next: use normally; no outstanding work for this request.

Git checkpoint: the progress fix, optional multi-download mode, and previous
download warning/navigation are saved as separate local commits, with related
tests alongside each change. The historical HTML concept in `output/` remains
untracked. No push was performed; this commit-only pass reused the validation
above and checked staged diffs and whitespace without rerunning tests.

## Previous Checkpoint: Previously Downloaded Video Warning

Home shows a single-line Already downloaded warning immediately below Provider
inside the URL card when a link matches a completed record in Downloads. It uses
an amber icon/text (darker gold in light mode), without a panel or separate button.
Clicking the warning opens Downloads; its tooltip names that action, and fetching/
downloading remains available. Long text truncates to one line. The warning updates on
typing, paste, clear, download completion, and history removal. It uses restored
history as well as current-session completions. Queued/active/failed/cancelled
tasks do not trigger it. A missing output file still counts as previously
downloaded because this checks history, not file presence.

YouTube watch/short/shorts/embed/live URL variants match the same video while
ignoring tracking/timestamp parameters. www.youtu.be now shares the existing
cache normalization. Other providers compare their source URLs without fragments;
unrelated query parameters remain significant. Batch input counts unique matched
videos, avoiding duplicate warnings for multiple records or URL aliases.

Verified on 2026-10-12 after the compact layout revision: all four focused warning
tests passed, including placement below Provider, navigation, light/dark 375px
layouts at 1.3x text, and completion/removal updates. Analysis and whitespace
checks passed; hot reload succeeded. The earlier 45 Home/history/cache tests
passed before this visual revision. Those cover persisted history, URL variants and false
matches, completion/removal updates, navigation, clearing, and 375px light/dark
layouts at 1.3x text size. These exposed an existing provider-label overflow;
the label now wraps within its row. Earlier runtime inspection found the warning
for the current link. No live download or release
build was started. Next: use normally; no outstanding work for this request.

## Previous Checkpoint: Forward-only Stream Progress

Reproduced percentage reversal (6% → 5.5%) and premature 100% with failing
regression tests. yt-dlp now emits explicit progress fields; segmented streams
use fragment index/count and ordinary streams use confirmed byte totals.
Estimated file sizes remain statistics only, never the percentage denominator.
Unknown totals retain the last bar position while reporting transferred bytes.
In-flight percentages are capped at 99%; only a finished stream reports 100%.
DownloadTask holds the highest valid percentage within a phase; changing phase
or retrying resets it. Legacy text/fragment parsing supports already-running
processes. This supersedes the estimate-following checkpoint below.

Verified on 2026-10-12: all 46 progress/parser/YouTube subtitle pipeline/queue/
downloads/completed-card tests passed, as did analysis and whitespace checks.
A real yt-dlp localhost download of a generated four-fragment HLS video produced
17 updates; the production Dart parser yielded 0 → 25 → 50 → 75 → 99 → 100
without regression despite fluctuating estimated sizes. No remote download or
release build was started. Hot reload succeeded; runtime inspection found no
errors. The user's x86 vs ARM task already displayed Completed, so its in-flight
behavior after this fix was not observed. Next: observe the next normal download.

## Previous Checkpoint: Optional Multi-download Mode

Settings → General now has a persisted Multi-download mode switch, off by
default for both new and existing settings. Compared the original Home and URL
card using `git show HEAD` with the working changes using `git diff`. Off restores
the single URL / Fetch Info flow, automatically opens the video editor, applies
saved quality/audio/container preferences, and queues one video with the original
Downloads navigation. Enter fetches; Ctrl+Enter fetches or downloads. On retains
the batch strip, per-video settings, and Download all workflow.

Single and batch drafts remain separate in memory while Home is mounted and
survive switching modes. Disabling batch mode hides its strip and prevents a
pending batch fetch from auto-queueing hidden videos. Existing queue tasks are
unaffected. The mode preference survives app restart; drafts do not.

Verified on 2026-10-12: all 58 local Home, responsive layout, format selector,
subtitle picker, and download manager tests passed. Covers settings UI toggling,
preference persistence/default migration, single-video queue selections, Enter /
Ctrl+Enter, automatic download navigation, and switching during a batch fetch.
Analysis and `git diff --check` passed. Hot reload failed twice through the
existing Flutter tooling session with `s1.reloadSources` error -32000; runtime
error inspection reported none, but the new UI was not verified in the running
Linux app. No restart, release build, or live download was performed.
Next: relaunch the development app when current downloads are finished and
check Settings → General → Multi-download mode in both positions.

## Previous Checkpoint: Progress Corrects Early 100% Estimates

Fixed DownloadTask retaining the highest percentage within a phase, which could
pin the UI at 100% after yt-dlp revised its total-size estimate. Display progress
now follows the latest finite percentage (bounded to 0–100); status-only messages
still preserve numeric stats, and phase/retry resets remain unchanged. Estimates
can decrease when the source corrects its total size. This supersedes the earlier
monotonic-percentage behavior described under Stable Download Progress.

Verified on 2026-10-12: the regression test failed before the fix (bar 1.0 instead
of 0.05), then all 14 focused progress/queue/downloads/completed-card tests passed.
Analysis and git diff whitespace checks passed. Read-only inspection of the two
user-started Linux downloads confirmed raw/display values of 26.9/100 and
14.3/100 before hot reload, and matching 31.1/31.1 and 16.5/16.5 afterward.
Both remained in downloadingVideo; no restart/cancellation was performed and no
runtime errors were reported. No new live download or release build was started.
Next: observe progress through audio/merge/completion during normal use.

## Previous Checkpoint: Batch Video Preparation

Home keeps the original full video editor above a single horizontal Your videos
strip. Add videos immediately creates pending cards in that strip and clears the
URL field. Fetch/wait/error status and Retry live exclusively in those cards;
the URL field and Add videos button remain available during metadata fetching.
Metadata requests are processed sequentially, including links added mid-fetch.
Removing a pending card prevents its async result from returning to the list.
Duplicate input links and resolved provider/media IDs are deduplicated.

Only clicking a ready video card selects its data for the main editor. Adding or
finishing a fetch never auto-selects a video or replaces the current editor.
The editor reuses MediaInfoCard, FormatSelectionCard, OutputFolderRow, and Download
in their original order. Card selection scrolls back to that editor. Collapse
hides only the strip; removing/queueing the selected draft clears its editor.
Each ready draft owns its provider and HomeInput, with best video/audio defaults
and saved language/container/output-directory preferences. Selections survive
switching between cards.

Download all queues ready drafts only; pending/failed fetch cards remain.
Individual Download queues only the selected draft. Validation failures remain
on their cards without changing selection. Existing download concurrency remains
two. Auto-start, if enabled, queues newly fetched drafts after pending metadata
is processed and leaves the user on Home instead of navigating during fetching.

Verified on 2026-10-12: all 19 Home tests passed, including strip-only fetching,
no automatic editor selection, adding links during fetch, removal of pending
cards, card-level retry, deduplication, settings isolation, and batch queueing.
Responsive tests cover 320/375/900/1162-pixel layouts, light/dark, 1.3x text and
reduced animations. Analysis and git diff whitespace checks passed. Hot reload
succeeded and no runtime errors were reported. The earlier 48 selector/audio/
subtitle/queue/local merge tests remain historical; they were not rerun for this
fetch-location correction. No live network download or release build was run.

Drafts remain in memory while Home stays mounted; they are not restored after
app exit. Queue restart recovery and desktop background/tray handling remain
unimplemented. Next: review the restored editor and bottom video strip in the
Linux app and exercise a real batch download. The earlier illustrative concept
at `output/batch-download-concept.html` is historical; this task changed the app,
not that prototype. No macOS platform implementation was added.

## App Update Reference Review (2026-10-12)

Reviewed source at
`/home/abdin_02/Mohamed_tips/updates_app/Alrahma-CI-CD-main` at the user's request.
Its Android update flow builds/releases APKs with GitHub Actions, reads Supabase
update metadata at startup/every six hours, downloads an APK, and opens the native
installer. Source observations: build numbers are ignored during comparison;
SHA-256 is computed in CI but not passed through the active download flow;
forced updates retain a Later button; the realtime listener passes inserted rows
while its consumer expects an `action` field absent from the shown table schema.
The workflow and embedded Edge Function example also disagree on release tags.
These are source findings, not verified behavior of deployed services.

Universal Downloader currently updates desktop tool bundles, not the application.
Its Linux/Windows packagers already produce complete app archives and checksums;
no `.github` workflow directory exists in this checkout. Suggested next step,
only if requested: define app update metadata and platform installation behavior,
reusing the existing release infrastructure. No app code changed, builds/tests
run, remote services checked, or releases published during this review.

## Current Checkpoint: Relative Download Dates and Missing Files

Completed cards show Just now for the first minute, Today/Yesterday with local
time, and an absolute date for older downloads. A tooltip retains the full date
and time, respecting the device's 12/24-hour preference. Calendar days are
compared in local time, including month/year boundaries. Existing persisted
completion timestamps are used without a database change.

Linux/local-file checks run when cards mount or complete, every 15 seconds while
visible, and on app resume. Missing or moved files show a File not found badge
and hide Open location. Restoring the saved path restores the action. Opening
also rechecks existence. Async results for replaced/disposed cards are ignored;
timers and observers are disposed. Android content URIs remain unknown to this
local-file check, preserving Open video; native URI existence checking is not
implemented by this change.

Remove and Clear finished require confirmation and explain that files stay on
the device. The video's title was removed from the confirmation as requested.
Cancel/dismissal preserves records. Bulk clearing snapshots finished task IDs,
preserving active tasks and downloads that finish while the dialog is open.

Verified on 2026-10-12: 30 focused tests passed across date formatting, real-file
move/delete/restore checks, availability widgets, completed cards, confirmation,
progress, and persisted history (27 initial passes, then 3 availability tests
after correcting a test compilation error). Includes 320/360/1162-pixel layouts,
resume/poll refresh, stale async results, and file preservation. Analysis and
`git diff --check` passed. Hot reload succeeded; no runtime errors were reported.
Flutter Driver remains disabled. No release build or live download was run.
Commit review on 2026-10-12 organized the changes into history confirmation
(`22d778e`), relative dates/file availability (`b6d2b34`), and this handoff.
Staged diffs passed `git diff --check`; all 13 reviewed file contents matched the
pre-commit snapshot before this handoff update. No application tests or builds
were rerun during commit organization; validation above remains applicable.
Next: review relative dates and missing-file badges in the Linux app. Use
`git status -sb` for the current local/remote relationship.

## Previous Checkpoint: Stable Download Progress

DownloadTask keeps a separate monotonic displayed percentage for each phase,
while retaining the latest raw size/percentage estimates. Status-only yt-dlp
messages preserve numeric progress instead of switching the bar to an
indeterminate animation. Phase changes and retries reset progress; repeated
notifications for the same phase do not. Invalid/out-of-range percentages cannot
reach the bar. DownloadActiveProgress holds download statistics to one line with
tabular digits and a tooltip, keeping the card height fixed. Merging/verifying
use their own processing labels without stale transfer statistics.

Verified: a widget reproduction failed before the fix when source estimates
changed from 6% to 5.5%. All 38 focused local tests passed afterward, covering
progress, status messages, phase/retry resets, card geometry, queue behavior,
YouTube provider, and responsive layouts. `flutter analyze --no-pub` and scoped
`git diff --check` passed. Hot reload succeeded in the running Linux app and
reported no runtime errors. No new live YouTube download or release build was
performed. Next: observe the next real download through video/audio phases.

Commit review on 2026-10-11: `flutter analyze --no-pub` passed, and all 12
local tests in download_progress, download_manager, downloads_page, and
android_layout passed. Staged `git diff --check` passed. No live download or
release build was run during this review.

The progress fix and regression tests are committed as `52c0352` and pushed to
`origin/main` through the existing `github-personal` SSH alias. The sandboxed
push could not resolve github.com; the approved network retry succeeded.
Origin's push URL uses SSH while fetch remains HTTPS.

On 2026-10-12, the user explicitly requested committing all remaining file-mode
changes. Review found 290 tracked files changing from 100644 to 100755, with no
content changes, staged changes, or untracked files before this handoff update.
These executable-bit changes are included in the repository housekeeping commit.
No application tests or builds were rerun for this permissions-only follow-up.
Use `git status -sb` for the current local/remote relationship.

## Previous Checkpoint: Audio Quality From Available Source Bitrates

Audio Quality lists distinct positive bitrates from the selected language's
formats. Unknown bitrates show an explicit source-metadata explanation. The
YouTube mapper uses positive `abr`, falling back to `tbr` only for audio-only
streams; muxed-stream total bitrate never becomes an audio quality choice.
Manual selection now requires an exact bitrate and uses existing quality ranking
for ties. An unavailable manual choice fails instead of silently selecting a
nearby/best bitrate. Audio format refresh/retry preserves bitrate, codec, sample
rate, and language; it fails if no matching replacement is available. Video and
stream-copy merging behavior remain unchanged. The picker is extracted into
`lib/ui/widgets/audio_quality_dropdown.dart`.

Verified: 75 focused local tests passed across audio/video pickers, selectors,
YouTube metadata/provider (including retry), and responsive layouts.
`flutter analyze --no-pub` and scoped `git diff --check` passed. Hot reload
succeeded in the running Linux app; no runtime errors were reported. No live
YouTube download or release rebuild was performed. Next: fetch a video's
metadata and check the available bitrates after selecting each audio language.

## Previous Checkpoint: Persistent Link Cache and Download History

Drift/SQLite now stores link metadata and completed-download records in
`library.sqlite` under the platform app-data directory. Database work runs in a
background isolate. Media files remain in their existing output locations;
history stores file paths or Android content URIs, metadata, selected options,
and completion timestamps. Downloads renders rows lazily and restores completed
records at startup. Remove/Clear finished deletes records, never media files.

Fetch Info reuses successful metadata for five minutes (maximum 100 entries),
normalizes YouTube video URL variants, separates tool configurations, and
deduplicates concurrent requests. Cached metadata preserves qualities, audio
languages/HLS source IDs, and subtitles. Settings → Storage has a clear-cache
icon; clearing does not touch history and blocks earlier in-flight requests
from repopulating the cache. Corrupt cache entries are refetched. History write
failures remain visible without marking successfully downloaded files failed.

Verified: 181 local unit/widget tests passed, including file-backed database
reopening, TTL, eviction, cache clearing races, controller wiring, history
removal, content URIs, and storage failures. `flutter analyze --no-pub`, scoped
`git diff --check`, and `flutter build linux --debug --no-pub` passed. Schema v1
was exported to `drift_schemas/`. The running app's old queue was verified empty
before hot restart; startup created the database and reported no runtime errors.
No live YouTube download/cache timing or Windows/Android rebuild was performed.

Remaining: only completed downloads are durable; queued/failed/cancelled tasks
and in-progress resumption are not persisted. Older files are not automatically
imported. A future player can add playback position/playlists via schema
migrations; it has not been implemented. Next: fetch a link twice within five
minutes, clear it in Settings, and verify a new completed download after restart.

## Previous Checkpoint: Clear URL Action

The URL field now shows a close (×) button before the existing clipboard button
when text is present. It clears the controller and returns keyboard focus to
the field. The link icon, clipboard action, and Fetch Info button remain.

Verified: `flutter analyze --no-pub` passed; all four responsive layout tests
passed at widths 320, 360, 412, and 1024. Hot reload succeeded in the running
Linux app. No release rebuild was performed.

## Previous Checkpoint: Video Qualities Follow Fetched Formats

Home now lists unique actual video heights in descending order plus Auto,
including 144p, 240p, nonstandard heights, and resolutions above 2160p when
present. There is no fixed maximum. Saved quality preferences resolve to an
available height on each fetch; settings also offer 144p and 240p. Video
selection prioritizes the requested resolution before preferring DASH streams
at that height.

HLS-only audio languages previously bypassed the selected video and used the
entire muxed stream. They now supply audio to the selected video through the
existing stream-copy merge, with height verification enabled. This path fetches
both the selected video and the muxed audio source, so it can transfer more data.

Verified: 75 local tests passed across video/audio quality widgets, selector,
responsive layout, subtitles, YouTube mapping/provider, and local media merging.
Real FFmpeg/FFprobe tests preserved 144p and 240p video when Arabic audio came
from a 720p muxed source. `flutter analyze --no-pub` and scoped `git diff --check`
passed. Hot reload succeeded in the running Linux app; no runtime errors were
reported. No live YouTube download or release rebuild was performed. Next:
fetch video details again in the running app to use its actual quality list.

## Previous Checkpoint: Audio Quality Always Visible

Git history (`c3ed868`) and current source showed the bitrate selector still
existed but was hidden while Auto was enabled. Audio Quality now stays visible
for separate audio tracks. Selecting a bitrate disables Auto; Best Available
or enabling Auto clears the manual bitrate. Changing language resets quality
and displays only that language's bitrates. Unknown bitrates keep the automatic
option visible. Embedded audio retains its existing explanation.

Verified: 28 local tests passed across `audio_quality_picker_test.dart`,
`android_layout_test.dart`, `unit/format_selector_test.dart`, and
`subtitle_picker_test.dart`; analysis found no issues. Hot reload succeeded in
the running Linux app and the runtime error check returned none. No live
download was performed for this UI change. Next: use Audio Quality below the
audio language after fetching video details.

## Previous Checkpoint: Linux Debug Bundles Included Tools

The Linux `flutter run -d linux` build previously allowed a missing
`build/tool-runtime`, producing a debug bundle without `tools/`. It then used
system yt-dlp/FFmpeg/FFprobe and reported Deno unavailable. Linux CMake now
prepares the pinned runtime automatically when any required tool or manifest is
missing, and fails if preparation cannot provide all four tools. The Linux
platform no longer falls back to system executables. Restoring included tools
now reports an error and preserves an active update if the included bundle is
absent. The running debug app must be restarted to load these changes.

Verified on 2026-10-11: `flutter build linux --debug --no-pub` prepared the
runtime from a missing directory and bundled all four executables. The local
`dart tool/smoke_runtime.dart build/linux/x64/debug/bundle` passed all tool
version checks, MP4/MKV cover merges, FFprobe verification, and Deno JavaScript.
The focused Flutter tests passed (25), `flutter analyze --no-pub` found no
issues, and `git diff --check` passed for the edited build/docs files. No live
download or running-app UI recheck was performed after the rebuild. Next: restart
the debug app and use Diagnostics → Check tools to confirm the banner clears.

## Previous Checkpoint: Windows x64 Build Produced

The Windows build was produced and smoke-tested natively on the user's Windows
machine (Windows 10 Pro 22H2, VS Build Tools 2022 17.14 + Win10 SDK 10.0.26100).
A portable release ZIP exists in `dist/`. The app UI has not been launched, and
no Windows live download, Explorer reveal, Arabic audio/subtitle check, clean
machine run, or update install has been performed.

Environment setup performed for this build:

- Flutter upgraded in place `C:\flutter_local\flutter` from 3.41.6 to **3.47.6**
  (Dart 3.13.5); the previous SDK failed pubspec's `^3.12.2` constraint.
- Python 3.13.14 at `%LOCALAPPDATA%\Programs\Python\Python313` was added to the
  front of the user PATH (the Microsoft Store alias had been shadowing it).
- `flutter pub get` under the new SDK changed `pubspec.lock` (4 transitive
  dependencies) and the tool auto-added build/platform excludes to
  `analysis_options.yaml`. These are uncommitted.

### Build Result (2026-10-07)

- `python tool/build_windows.py` completed: prepared `build/tool-runtime-windows`
  from `.tool-cache`, ran all four tool version checks, built the release app,
  and passed the packaged smoke (included tools, MP4/MKV cover merges, FFprobe
  verification, Deno JavaScript, and the Windows process-tree cancellation check
  with a system-only PATH).
- Output: `dist/universal-downloader-windows-x64.zip` (199954308 bytes),
  `dist/runtime-windows-x64.zip` (173320599 bytes), plus JSON/SHA-256 sidecars.
- `build/windows/x64/runner/Release/` contains the app with `tools/` and the
  app-local Visual C++ runtime DLLs beside `universal_downloader.exe`.
- To test now: extract the entire ZIP folder and run `universal_downloader.exe`
  (do not copy the EXE alone), or run the Release folder directly.

### Checks Actually Run on Windows

- `flutter doctor -v`: no issues; Windows desktop enabled, VS detected.
- `flutter analyze --no-pub`: no errors; one new info lint
  (`use_super_parameters` at `lib/core/errors/downloader_exceptions.dart:63`)
  from the newer analyzer.
- `flutter test --no-pub test/unit/windows_platform_test.dart
  test/unit/log_service_test.dart test/unit/filename_sanitizer_test.dart`:
  30 passed.
- `python tool/test_windows_packaging.py`: 4 passed.
- `python tool/build_windows.py`: passed, including its internal smoke checks.

### Remaining Windows Validation

Launch the built app; verify a real YouTube download with Arabic audio and
subtitles, MP4/MKV artwork, cancellation and child cleanup, Explorer Open
location, a path containing spaces/Arabic, Diagnostics tool checks, and
local tool update install/restore. Validate clean-machine startup (Windows
Sandbox, no Python/media tools on PATH). None of the earlier Linux/Android
commit history was pushed; `main` is still 4 commits ahead of `origin/main`.

## Previous Checkpoint: Windows x64 Preparation (Linux session)

Changes are organized into four local commits on main: no-console logging,
Windows platform integration, portable packaging, and documentation. No push
or publication was performed. Commit-only review preserved source contents;
no builds or application tests were rerun while organizing these commits.

- `WindowsDownloadPlatform` implements the existing OS abstraction via shared
  `DesktopDownloadPlatform`; provider/download logic remains shared with Linux.
  Native MethodChannel code resolves LocalAppData and redirected Downloads via
  known folders, and reveals files in Explorer without shell command strings.
- Windows tools resolve beside the app with `.exe` names and no implicit PATH
  fallback. Bundles/updates use the explicit `windows-x64` target and separate
  release assets. Updates reject cross-platform manifests, Windows-unsafe paths,
  case-colliding entries, damaged files, and non-advancing revisions; no chmod
  is invoked for Windows tools. Linux still uses its existing runtime format.
- Windows cancellation uses the system `taskkill /PID /T /F`; native execution
  remains unverified. Filenames avoid Windows device names. Logs keep working
  without an attached console (covered with a failing stdout fixture).
- `tool/build_windows.py` builds a portable complete ZIP. Preparation downloads
  hash-pinned Windows yt-dlp 2026.08.19, Deno 2.9.7, and BtbN FFmpeg/FFprobe
  n8.1.3 (2026-10-05 autobuild). Visual C++ release DLLs are copied from the build
  machine's Visual Studio Redist into the tools package and beside the app.
  End users are intended to extract the folder and launch the EXE with no
  separate tool/runtime installer. CMake refuses an unprepared/inspection-only
  runtime. The build script checks files/hashes and runs smoke checks before ZIPs.
- The old project was reread as a reference. It copies tools through development
  paths and does not connect those paths consistently to the downloader. No old
  binaries or old download implementation were copied into this project.

### Checks Actually Run for Windows Work

- `flutter analyze --no-pub`: passed after final Dart changes.
- Broad local unit/widget tests: 145 passed; subsequent focused Windows/log tests:
  20 passed, including the newly added no-console logging regression.
- `python3 tool/test_windows_packaging.py`: 4 passed. Python scripts compile.
- `python3 tool/prepare_tools.py --platform windows-x64 --skip-execution`: passed.
  Download hashes verified; all four EXEs inspected as PE x64; all 44 staged
  manifest file hashes matched. This inspection runtime has no Visual C++ DLLs
  and explicitly records `runtimeValidated: false`; it is not deployable.
- `python3 tool/prepare_tools.py --platform linux-x64`: passed, all tool version
  commands executed. Current `tool/smoke_runtime.dart` passed against the existing
  Linux release bundle: four tools, real MP4/MKV artwork merges, FFprobe, and Deno.
  No Linux application rebuild or live network download was performed.
- `git diff --check`: passed. No Windows/Wine/MSVC execution on this host.

### Handoff to the Windows Machine

Read `tool/README.md` Windows x64 section. Bring the committed source and
preferably `.tool-cache`; BtbN daily downloads may expire. These commits are
local until explicitly pushed or transferred to the Windows machine.
Do not copy Linux `build/` or `.dart_tool/` as Windows build artifacts.
On Windows install developer prerequisites (Flutter, Visual Studio C++ workload,
Python 3.11+), run `flutter pub get`, the selected Windows tests in the guide,
and `python tool/build_windows.py`. Output is intended at
`dist/universal-downloader-windows-x64.zip`; run the EXE in the entire extracted
folder, not alone. Fix native build/runtime findings there before claiming
Windows support verified. Validate clean-machine startup, actual Arabic audio
and subtitles, cancellation/child cleanup, Explorer reveal, and update/restore.
The build script's runtime smoke includes a Windows-only child cancellation
check with a system-only PATH. No CI deployment or remote Windows setup was requested.

## Previous Android Checkpoint

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
  app executable. Saved custom executable paths remain supported.
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

Universal Downloader is a Flutter Material 3 Linux desktop app with Android preview
and a Windows implementation awaiting native validation. Dart package:
`universal_downloader`; folder: `video_downloader`; version: `1.0.0+1`.

| Area | Responsibility |
| --- | --- |
| `lib/main.dart`, `lib/app/` | AppController startup, providers, settings, checks, queue composition. |
| `lib/platform/` | OS detection and DownloadPlatform; shared desktop services, Linux/Android, Windows implementation awaiting native validation. |
| `lib/providers/` | Provider contracts, factories, injected dependencies, registry, format selection; YouTube and direct HTTP(S). |
| `lib/downloads/` | Queue, task state, retry/concurrency, completed history, temporary files. |
| `lib/core/storage/` | Drift schema, background SQLite connection, metadata/options serialization. |
| `lib/core/process/` | CommandRunner contract; local argument-array execution, output capture, SIGTERM/SIGKILL cancellation. |
| `lib/core/services/` | Media assembly/verification, dependency checks, logging, file reveal. |
| `lib/core/tools/` | Runtime manifests, executable resolution, staged updates, release checks. |
| `lib/settings/`, `lib/core/utils/` | Preferences, filenames, application data paths. |
| `lib/ui/pages/`, `lib/ui/widgets/` | Home, Downloads, Settings and shared controls. |
| `tool/` | Runtime pins, build/packaging, clean-container setup, smoke check. |

Only YouTube and direct HTTP(S) providers are registered. Social-provider files
are stubs; Linux and the Android preview have runtime implementations. Windows
also implements the contract, with native build/run validation still pending.

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
shared_preferences key `settings_v1`. `library.sqlite` holds completed-download
history and the five-minute link cache. Active queue state/theme are not persisted.
Linux output defaults to Videos when present, otherwise Downloads, unless overridden.
Android app data is under files/universal_downloader; completed public downloads
are under Downloads/UniversalDownloader in a unique folder per task.

## Unresolved Source Observations

These pre-existing observations are outside the bundling request:

1. Direct-provider metadata lacks dimensions required by Home's video selector;
   verification also expects both video and audio for audio-only inputs.
2. HLS language mapping keeps the first progressive per language as its audio
   source; downloading this muxed source may transfer unnecessary video data.
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
The Windows build exists; validation of the running app and a live download is
the open Windows work (see Remaining Windows Validation). Android follow-ups
remain separate work.
Use main only and one-line Conventional Commits when commits are requested.
Use the git-commit skill for commit work. Do not publish releases, fix unrelated
observations, or treat follow-up suggestions as standing authorization.
