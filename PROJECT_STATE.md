# Universal Downloader: Project State

Last updated: 2026-10-04 (Africa/Cairo).

## Current Checkpoint

Added a README **How to Use** section covering launch, URL entry, Fetch Info,
quality/audio/container selection, output folder, task controls, and settings.
The section embeds five screenshots in `docs/screenshots/`: `home.png`,
`video-details.jpg`, `download-options.png`, `downloads.png`, and `settings.png`.
Home was captured from the running Linux app; the user supplied the four
additional screenshots. Their filenames were corrected and standardized,
including removal of spaces and a stray backslash. Image contents were retained.

Verification for this documentation task: `flutter build linux --debug --no-pub`
succeeded; the resulting app was opened and its Home screen visually inspected.
All five images were visually inspected and their relative Markdown links
checked. The user's Downloads screenshot shows completed and active tasks;
no additional live download or test-suite run was performed by the agent for
this documentation update. Application source was not changed.

## Repository History

Repository: `https://github.com/Mo7amed-fawzy/Universal-Downloader.git`.
Use `main` as the only branch. The user requested focused commits instead of
the broad initial application commit. The replacement history separates build
setup, media infrastructure, download queue/contracts, YouTube support, direct
URLs, settings, UI/composition, tests, and documentation into nine commits.
The original published tip before this split was `a8ae650`.

The user approved applying these nine commits to `main` on 2026-10-04.
The original history is backed up in
`/tmp/universal-downloader-history-OfzozV/original-history.bundle`.
The replacement uses an explicit force-with-lease against the original remote
tip to avoid overwriting concurrent work. Use `git status -sb` and
`git ls-remote --symref origin HEAD 'refs/heads/*'` to check synchronization.

All tracked file paths, modes, and blob hashes were compared with the original
snapshot; only this handoff differs. Application behavior was not changed, so
the existing analysis and 53 passing local tests remain the validation baseline.
No additional application tests were run for the history-only split.

Ignore rules exclude extractor
`*.dump` files and local credential files, in addition to existing build/cache
and editor exclusions. No new feature or bug fix is in progress.

## Previous Live Download Checkpoint

The previous request was completed: opened the Linux app and used its UI to
download `https://youtu.be/JQMx58kw_Wo?si=aq90lvVPGRtXLfFI` with Best Available
video and Arabic audio. The app showed `Completed` on 2026-09-23 and was left
open on Downloads at that time; its current running state was not rechecked.

Verified output:
`/home/abdin_02/Videos/Automate interactive Flutter tests with marionette_mcp _ Mateusz Wojtczak.mp4`

- App selected video `313` (2160p) and Arabic audio `140-0` (129 kbps).
- App downloaded both streams, merged with stream copy, passed its verification,
  and cleaned the task's temporary directory.
- Independent ffprobe: 3840×2160 VP9 video, AAC audio at 128002 bps,
  duration 564.563 seconds, size 468953748 bytes.
- Audio language was identified as Arabic by extraction/UI selection; the final
  file's audio language tag is `und`. Spoken audio was not independently audited.
- A temporary Flutter Driver entry point/dependency enabled UI control. The entry
  point was removed and original pubspec files restored after completion.
  Application behavior/source was not changed. No test suite was rerun for this
  download-only task; a debug Linux build and the live UI download succeeded.

The September inspection started without Git history or an earlier handoff.
The October initial history captures the existing application; it does not
reconstruct individual development steps before Git was initialized.

## What the App Does

Universal Downloader is a Linux desktop media downloader built with Flutter
Material 3. A user pastes a URL, fetches metadata, chooses video quality and
audio language/bitrate, chooses an output folder, and queues a download.
YouTube downloads use yt-dlp; separate video/audio streams are merged with
ffmpeg stream copy and checked with ffprobe.

- Actual registered providers: YouTube and direct HTTP(S) media URLs.
- Facebook, Instagram, TikTok, and X have inactive stubs in
  `lib/providers/future_providers.dart`. Reddit/Vimeo are README plans only.
- Home, Downloads, and Settings screens share a navigation rail and theme toggle.
- Quality choices: best available, 2160p, 1440p, 1080p, 720p, 480p, and 360p.
- Audio preferences default to Arabic (`ar`), automatic best bitrate, and an
  empty fallback language. See the UI fallback caveat below.
- Container preference: automatic, MP4, or MKV. Separate streams are copied
  without re-encoding; combined streams are moved into the output location.
- The in-memory queue defaults to two concurrent downloads. Task controls
  include cancel, retry failed tasks, remove, and open output location.
- Settings persist through shared_preferences under `settings_v1`; queue
  history and the theme toggle are not persisted by the current code.
- External executable paths, extra yt-dlp arguments, output directory, and
  debug logging are configurable.

The README understates direct-provider implementation and does not describe
the newer HLS path. Source code is the authority for current behavior.

## Code Map

| Area | Entry points and responsibilities |
| --- | --- |
| Startup | `lib/main.dart` creates `AppController` before `runApp`. |
| Composition | `lib/app/app_controller.dart` wires providers, settings, dependency checks, logging, and manager. `app.dart` exposes it using provider/ChangeNotifier. |
| UI | `lib/ui/pages/home_page.dart`, `downloads_page.dart`, `settings_page.dart`; shared controls in `lib/ui/widgets/`. |
| Provider contract | `lib/providers/downloader_provider.dart` and `provider_registry.dart`. |
| Selection | `lib/providers/format_selector.dart` ranks real format metadata; common models live in `lib/core/models/`. |
| YouTube | `lib/providers/youtube/youtube_extractor.dart`, `youtube_format_mapper.dart`, `youtube_provider.dart`. |
| Direct URLs | `lib/providers/direct/direct_media_provider.dart` uses HTTP HEAD metadata and GET streaming. |
| Downloads | `lib/downloads/download_manager.dart`, `download_queue.dart`, `download_task.dart`, `download_repository.dart`. |
| Processes | `lib/core/process/process_runner.dart` uses argv, stdout/stderr capture, and SIGTERM then SIGKILL cancellation. |
| Media | `lib/core/services/media_assembler.dart` selects a container, merges, and verifies streams, size, language metadata, and height. |
| Local data | `lib/core/utils/path_utils.dart`, `lib/core/services/log_service.dart`, `lib/settings/`. |

## Latest Apparent Development Focus

Inference from source timestamps, not confirmed conversation history:
the newest source files are `youtube_provider.dart` and `youtube_extractor.dart`
(2026-08-20), following mapper/audio-model and verification/test changes.
The apparent focus was multilingual YouTube audio, HLS discovery, download
client compatibility, and language verification.

Current implementation details worth preserving:

- Metadata and DASH audio use `ios,web_embedded,default` player clients.
  DASH video uses `web_embedded,default`; HLS uses `tv_embedded`.
- yt-dlp requests `--remote-components ejs:github`. Treat compatibility as
  dependent on the installed yt-dlp and current YouTube behavior.
- Metadata extraction uses JSON plus a secondary `yt-dlp -F` text parse for
  language-tagged m3u8 formats. Failure of the secondary pass is nonfatal.
- Languages absent from DASH audio get synthetic `m3u8-...` audio entries
  whose `progressiveFormatId` identifies a combined video/audio stream.
- Choosing one of these entries downloads that combined stream directly.
  Otherwise, separate streams are downloaded and merged as needed.
- Failed stream downloads attempt metadata refresh and format-ID remapping
  by height or language, then retry with the remapped format.
- Verification tolerates missing language tags, `und`, and `eng`; this is
  metadata tolerance, not proof of the spoken language.
- Failed tasks generally preserve temporary artifacts; cancellation cleans
  their task directory, and successful verification triggers cleanup.

## Verified Baseline

SDK version recorded on 2026-09-23; analysis and both local test commands below
were rerun successfully on 2026-10-04 before the initial commits:

| Command | Result |
| --- | --- |
| `flutter --version` | Flutter 3.44.6 stable, Dart 3.12.2. |
| `flutter analyze --no-pub` | Passed, no issues found. |
| `flutter test --no-pub test/unit test/widget_test.dart --reporter expanded` | 48 tests passed. |
| `flutter test --no-pub test/integration/media_pipeline_test.dart --name 'MediaAssembler\|cancellation' --reporter expanded` | 5 tests passed, including real local ffmpeg/ffprobe merge and verification. |

yt-dlp, ffmpeg, and ffprobe were found on PATH. The earlier inspection did not
run live YouTube checks. The subsequent live UI download and debug build are
recorded in Previous Live Download Checkpoint above. No new live download,
desktop UI walkthrough, or release build was run for the October Git task.
Existing `build/` output and root-level YouTube `*.dump` files are prior
artifacts, not evidence that current downloads work. Their payloads were not
needed or inspected for this handoff.

Test coverage includes selection, filename/path handling, provider resolution,
YouTube mapping/HLS parsing, a StatusChip widget, local merging, and cancellation
tokens. It does not establish full queue behavior or complete UI workflows.

## Open Issues Not Fixed in This Inspection

These are source observations to reproduce and test before fixing; they are
not failures found by the passing test commands above.

1. `DownloadManager.retry()` calls `_pump()` and then `_execute()` directly.
   A free slot can execute the same task twice; a full queue can bypass its
   concurrency limit. Start with `lib/downloads/download_manager.dart`.
2. Direct-provider metadata has no width/height, but Home uses
   `FormatSelector.selectBestVideo()`, which rejects formats without dimensions.
   Consequently, the normal UI path cannot select those direct downloads.
   Also, verification requires both video and audio even for recognized
   audio-only extensions.
3. HLS language entries keep the first progressive per language after grouping
   by resolution. The provider then ignores the selected DASH video and passes
   no expected height to verification. Selected quality is not enforced on
   this path (`youtube_format_mapper.dart`, `youtube_provider.dart`).
4. Home chooses the first available language when the preferred language is
   absent, before applying the configured fallback during download selection.
   Do not assume the empty fallback setting prevents a language change.
5. DownloadsPage watches AppController, while queue mutations notify the
   separate DownloadManager. Individual tiles listen to their tasks, but
   list removals and aggregate counts may not refresh until another rebuild.
6. Language verification permits `eng` even when Arabic is expected, and does
   not generally normalize two-letter versus three-letter ISO language codes.
   Existing tests cover `und` tolerance and an Arabic/French mismatch only.

## Commands and Local Data

Run commands from the project root. SDK constraint is `^3.12.2`; package name
is `universal_downloader`, version `1.0.0+1`.

```sh
flutter pub get
flutter run -d linux
flutter build linux --release
./build/linux/x64/release/bundle/universal_downloader
```

For a local baseline, use the analysis and two selected test commands above.
`flutter test` also runs live network tests in `test/integration/`, including
Arabic audio extraction; tests skip for missing tools, not missing network.
The Arabic tests depend on current formats of a particular public video.

Data root: `$XDG_DATA_HOME/universal_downloader`, or
`~/.local/share/universal_downloader` when XDG_DATA_HOME is unset.
Logs: `logs/universal_downloader.log`; task artifacts:
`temp/download_task_<taskId>/`. Output defaults to `~/Videos` if present,
otherwise `~/Downloads`, unless settings select a different directory.
Other platform folders exist, but the source relies on desktop processes,
`dart:io`, Linux paths, `which`, and `xdg-open`.

## Next Session

Read this checkpoint and follow the user's next requested task. Use `main` as
the sole branch for now, per the user's instruction, and use one-line
Conventional Commit subjects. The previous 4K/Arabic download is complete,
and no feature request is pending. The open
issues above remain source observations; do not fix them without relevant scope.

## Technique and Official References

OpenAI calls the technique **durable project memory**: storing project context,
decisions, plans, and status in Markdown that the agent can revisit.
This file is the project handoff; `AGENTS.md` supplies the startup instruction
to read it and keep it current. It preserves written context, not a full chat
history, and depends on future sessions opening this project and updating it.

- [OpenAI: Run long horizon tasks with Codex](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex)
- [OpenAI: Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
