import '../../downloads/download_progress.dart';

/// Parses yt-dlp `[download] ...` progress lines (emitted with `--newline`).
class YtDlpProgressParser {
  const YtDlpProgressParser();

  static const _structuredPrefix = '[download] ud-progress:';
  static const progressTemplate =
      'download:$_structuredPrefix%(progress.status)s|'
      '%(progress.downloaded_bytes)s|%(progress.total_bytes)s|'
      '%(progress.total_bytes_estimate)s|%(progress.speed)s|'
      '%(progress.eta)s|%(progress.fragment_index)s|%(progress.fragment_count)s';

  static final _percent = RegExp(r'\[download\]\s+(\d+(?:\.\d+)?)%');
  static final _ofSize = RegExp(
    r'\[download\]\s+\d+(?:\.\d+)?%\s+of\s+(?:~\s*)?([\d.]+)\s*([a-zA-Z/]+)',
  );
  static final _speed = RegExp(r'\bat\s+([\d.]+)\s*([A-Za-z]+/s)');
  static final _eta = RegExp(r'\bETA\s+(\d{1,2}:\d{2}(?::\d{2})?)');
  static final _destination = RegExp(r'\[download\]\s+Destination:\s+(.+)');
  static final _fragments = RegExp(r'\(frag\s+(\d+)/(\d+)\)');

  bool isDownloadLine(String line) => line.contains('[download]');

  /// Parses a single line into a [DownloadProgress], or null when the line
  /// carries no progress information.
  DownloadProgress? parse(String line) {
    if (!isDownloadLine(line)) return null;
    final structuredIndex = line.indexOf(_structuredPrefix);
    if (structuredIndex >= 0) {
      return _parseStructured(
        line.substring(structuredIndex + _structuredPrefix.length),
      );
    }

    final destMatch = _destination.firstMatch(line);
    if (destMatch != null) {
      return DownloadProgress(statusLabel: destMatch.group(1));
    }

    final percentMatch = _percent.firstMatch(line);
    if (percentMatch == null) {
      // e.g. "[download] Downloading item 1 of 3"
      return DownloadProgress(
        statusLabel: line.replaceFirst('[download]', '').trim(),
      );
    }

    final percent = double.tryParse(percentMatch.group(1)!) ?? 0;

    final ofMatch = _ofSize.firstMatch(line);
    int? totalBytes;
    if (ofMatch != null) {
      totalBytes = _parseSize(ofMatch.group(1)!, ofMatch.group(2)!);
    }

    int? speed;
    final speedMatch = _speed.firstMatch(line);
    if (speedMatch != null) {
      speed = _parseSize(speedMatch.group(1)!, speedMatch.group(2)!);
    }

    Duration? eta;
    final etaMatch = _eta.firstMatch(line);
    if (etaMatch != null) {
      eta = _parseTime(etaMatch.group(1)!);
    }

    final downloadedBytes = totalBytes == null
        ? null
        : (totalBytes * (percent / 100)).round();
    final fragments = _fragments.firstMatch(line);
    final fragmentPercent = fragments == null
        ? null
        : _fragmentPercent(
            int.tryParse(fragments.group(1)!),
            int.tryParse(fragments.group(2)!),
          );
    final estimated = line.contains('~');
    final finished = !estimated && percent >= 100 && line.contains(' in ');

    return DownloadProgress(
      percent: finished
          ? 100
          : fragmentPercent ?? (estimated ? null : percent.clamp(0.0, 99.0)),
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      speedBytesPerSecond: speed,
      eta: eta,
    );
  }

  DownloadProgress? _parseStructured(String payload) {
    final fields = payload.trim().split('|');
    if (fields.length != 8 ||
        (fields[0] != 'downloading' && fields[0] != 'finished')) {
      return null;
    }
    final downloaded = _nonNegativeNumber(fields[1]);
    final total = _nonNegativeNumber(fields[2]);
    final estimate = _nonNegativeNumber(fields[3]);
    final speed = _nonNegativeNumber(fields[4]);
    final eta = _nonNegativeNumber(fields[5]);
    final fragmentPercent = _fragmentPercent(
      int.tryParse(fields[6]),
      int.tryParse(fields[7]),
    );
    return DownloadProgress(
      percent: fields[0] == 'finished'
          ? 100
          : fragmentPercent ??
                (downloaded != null && total != null && total > 0
                    ? (downloaded / total * 100).clamp(0.0, 99.0)
                    : null),
      downloadedBytes: downloaded?.round(),
      totalBytes: (total ?? estimate)?.round(),
      speedBytesPerSecond: speed?.round(),
      eta: eta == null ? null : Duration(seconds: eta.round()),
    );
  }

  static double? _fragmentPercent(int? index, int? count) {
    if (index == null || count == null || index < 0 || count <= 0) return null;
    return (index / count * 100).clamp(0.0, 99.0);
  }

  static double? _nonNegativeNumber(String value) {
    final number = double.tryParse(value);
    return number != null && number.isFinite && number >= 0 ? number : null;
  }

  static int? _parseSize(String value, String unit) {
    final number = double.tryParse(value);
    if (number == null) return null;
    final u = unit.toLowerCase();
    double multiplier = 1;
    if (u.startsWith('k')) multiplier = 1024;
    if (u.startsWith('m')) multiplier = 1024 * 1024;
    if (u.startsWith('g')) multiplier = 1024 * 1024 * 1024;
    if (u.startsWith('t')) multiplier = 1024 * 1024 * 1024 * 1024;
    return (number * multiplier).round();
  }

  static Duration? _parseTime(String value) {
    final parts = value.split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null)) return null;
    if (parts.length == 3) {
      return Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!);
    }
    if (parts.length == 2) {
      return Duration(minutes: parts[0]!, seconds: parts[1]!);
    }
    return null;
  }
}
