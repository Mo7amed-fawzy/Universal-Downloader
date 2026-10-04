import 'dart:convert';

import '../../core/errors/downloader_exceptions.dart';
import '../../core/process/cancel_token.dart';
import '../../core/process/process_runner.dart';

/// Runs yt-dlp to extract structured JSON metadata for a URL.
///
/// Uses the `web_embedded` player client (with the `default` client as a
/// fallback) together with the EJS remote components provider, which is what
/// exposes multi-language audio tracks and reliable format metadata.
class YoutubeExtractor {
  YoutubeExtractor({
    required String ytDlpPath,
    ProcessRunner? runner,
    List<String> extraArgs = const [],
  })  : _ytDlpPath = ytDlpPath, // ignore: prefer_initializing_formals
        _runner = runner ?? const ProcessRunner(),
        _extraArgs = extraArgs; // ignore: prefer_initializing_formals

  final String _ytDlpPath;
  final ProcessRunner _runner;
  final List<String> _extraArgs;

  /// Remote components requested from GitHub for EJS patching.
  static const String remoteComponents = 'ejs:github';

  /// Player clients for extraction: `ios` exposes the most multi-language
  /// audio tracks but can cause 403 errors on some video downloads.
  static const String extractionExtractorArgs =
      'youtube:player_client=ios,web_embedded,default';

  /// Player clients for m3u8/HLS progressive stream access.
  static const String hlsExtractorArgs =
      'youtube:player_client=tv_embedded';

  /// Player clients for downloading video (no ios — causes 403).
  static const String downloadExtractorArgs =
      'youtube:player_client=web_embedded,default';

  /// Base argument list for metadata extraction (includes `ios`).
  static List<String> extractionBaseArgs() {
    return const [
      '--no-warnings',
      '--no-playlist',
      '--no-color',
      '--remote-components',
      remoteComponents,
      '--extractor-args',
      extractionExtractorArgs,
    ];
  }

  /// Base argument list for downloading DASH video streams.
  /// Omits `ios` which causes HTTP 403 on some video data.
  static List<String> downloadBaseArgs() {
    return const [
      '--no-warnings',
      '--no-playlist',
      '--no-color',
      '--remote-components',
      remoteComponents,
      '--extractor-args',
      downloadExtractorArgs,
    ];
  }

  /// Base argument list for downloading DASH audio streams.
  /// Includes `ios` to access multi-language audio tracks (e.g. 251-2).
  static List<String> downloadAudioBaseArgs() {
    return [...extractionBaseArgs()];
  }

  /// Base argument list for downloading HLS/m3u8 progressive streams.
  static List<String> hlsDownloadBaseArgs() {
    return const [
      '--no-warnings',
      '--no-playlist',
      '--no-color',
      '--remote-components',
      remoteComponents,
      '--extractor-args',
      hlsExtractorArgs,
    ];
  }

  /// Extraction base args including user-configured extras.
  List<String> fullExtractionBaseArgs() =>
      [...extractionBaseArgs(), ..._extraArgs];

  /// Parses `yt-dlp -F` text output to discover m3u8 progressive streams
  /// and their language tags.
  ///
  /// `--dump-single-json` never includes m3u8/HLS formats — they are only
  /// fetched during format listing or actual download.  This method fills
  /// that gap by parsing the human-readable table from `-F`.
  Future<List<M3u8Progressive>> listM3u8Progressives(
    Uri url, {
    CancelToken? cancelToken,
  }) async {
    // Use `tv_embedded` which triggers YouTube to download m3u8 manifests
    // and expose multi-language progressive streams.  Other clients
    // (web_embedded, ios, etc.) often report UNPLAYABLE or skip m3u8
    // entirely, leaving only DASH audio tracks.
    final args = [
      '--no-warnings',
      '--no-playlist',
      '--no-color',
      '--remote-components',
      remoteComponents,
      '--extractor-args',
      'youtube:player_client=tv_embedded',
      ..._extraArgs,
      '-F',
      url.toString(),
    ];

    final result = await _runner.run(
      executable: _ytDlpPath,
      arguments: args,
      cancelToken: cancelToken,
    );

    if (!result.success) return const [];

    return parseFOutput(result.stdout);
  }

  /// Regex matching a line from `yt-dlp -F` that contains an m3u8 stream.
  ///
  /// Example line:
  /// `93-18 mp4   640x360     24    │ ~  3.83MiB 218k m3u8  │ avc1.4D401E      mp4a.40.2           [ar]`
  static final _m3u8LineRe = RegExp(
    r'^(\S+)\s+(\S+)\s+(\d+x\d+|\S+)\s+(\d+)' // id ext resolution fps
    r'.*?m3u8' // protocol contains m3u8
    r'.*?\[(\w{2}(?:-\w+)?)\]', // language tag [xx] or [xx-XX]
  );

  /// Regex matching audio-only m3u8 lines (no resolution).
  static final _m3u8AudioLineRe = RegExp(
    r'^(\S+)\s+(\S+)\s+audio\s+only'
    r'.*?m3u8'
    r'.*?\[(\w{2}(?:-\w+)?)\]',
  );

  /// Visible for testing only.
  static List<M3u8Progressive> parseFOutput(String stdout) {
    final results = <M3u8Progressive>[];
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('ID') || trimmed.startsWith('-')) {
        continue;
      }

      // Try progressive (has resolution) first.
      var match = _m3u8LineRe.firstMatch(trimmed);
      if (match != null) {
        final formatId = match.group(1)!;
        final ext = match.group(2)!;
        final resolution = match.group(3)!;
        final lang = match.group(5)!;
        final wh = resolution.split('x');
        final width = int.tryParse(wh.first);
        final height = wh.length > 1 ? int.tryParse(wh[1]) : null;
        results.add(M3u8Progressive(
          formatId: formatId,
          ext: ext,
          width: width,
          height: height,
          language: lang,
        ));
        continue;
      }

      // Then try audio-only m3u8 (rare but possible).
      match = _m3u8AudioLineRe.firstMatch(trimmed);
      if (match != null) {
        final formatId = match.group(1)!;
        final ext = match.group(2)!;
        final lang = match.group(3)!;
        results.add(M3u8Progressive(
          formatId: formatId,
          ext: ext,
          width: null,
          height: null,
          language: lang,
        ));
      }
    }
    return results;
  }

  /// Returns the raw yt-dlp info JSON as a [Map].
  Future<Map<String, dynamic>> extractJson(
    Uri url, {
    CancelToken? cancelToken,
  }) async {
    final args = [
      ...fullExtractionBaseArgs(),
      '--dump-single-json',
      '--skip-download',
      url.toString(),
    ];

    final result = await _runner.run(
      executable: _ytDlpPath,
      arguments: args,
      cancelToken: cancelToken,
    );

    if (!result.success) {
      throw FormatExtractionException(
        'Could not extract media information for this URL.',
        details: _cleanError(result.stderr),
      );
    }

    try {
      final decoded = jsonDecode(result.stdout);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected JSON shape');
      }
      return decoded;
    } on FormatException catch (e) {
      throw FormatExtractionException(
        'Failed to parse extractor output.',
        details: '${e.toString()}\n${_cleanError(result.stderr)}',
      );
    }
  }

  static String _cleanError(String stderr) {
    final lines = stderr
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.startsWith('  '))
        .toList();
    return lines.isEmpty ? stderr : lines.join('\n');
  }
}

/// A progressive m3u8 stream discovered via `-F`.
class M3u8Progressive {
  const M3u8Progressive({
    required this.formatId,
    required this.ext,
    required this.language,
    this.width,
    this.height,
  });

  final String formatId;
  final String ext;
  final String language;
  final int? width;
  final int? height;
}
