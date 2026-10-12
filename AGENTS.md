# Project Context for Codex

This project is Universal Downloader, a Flutter Linux desktop application that
uses yt-dlp, ffmpeg, and ffprobe. The Dart package is `universal_downloader`;
the enclosing folder is named `video_downloader`.

## Continuity Between Chats

- At the start of a project task, read `PROJECT_STATE.md` for the current
  checkpoint, architecture, verification results, and unresolved work.
- Treat that file as a dated handoff. Check relevant source before relying on
  it; do not assume previous conversation history is available.
- After substantive work, update its current checkpoint, changed behavior,
  checks actually run, remaining issues, and next step. Keep it concise and
  replace stale status instead of accumulating a chat transcript.
- Separate verified facts, source observations, and suggestions. Do not claim
  a build or live download succeeded unless it was actually checked.
- Follow the user's current request. Suggested follow-ups in the handoff are
  context, not standing authorization to implement unrelated changes.

## Project Conventions

- Keep provider-specific extraction in `lib/providers/`, queue orchestration
  in `lib/downloads/`, and process/merge/verification code in `lib/core/`.
- Linux desktop is the current target; other platform folders do not establish
  working support. External tools run locally through argument arrays.
- Preserve multilingual audio selection and stream-copy merging when changing
  downloads. Validate language and quality behavior with relevant tests.
- Use the validation commands in `PROJECT_STATE.md` as appropriate. The full
  test suite includes live YouTube requests; distinguish local and network checks.
