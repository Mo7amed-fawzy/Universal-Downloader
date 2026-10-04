import '../../downloads/download_progress.dart';

/// Parses yt-dlp `[download] ...` progress lines (emitted with `--newline`).
class YtDlpProgressParser {
  const YtDlpProgressParser();

  static final _percent = RegExp(r'\[download\]\s+(\d+(?:\.\d+)?)%');
  static final _ofSize = RegExp(
    r'\[download\]\s+\d+(?:\.\d+)?%\s+of\s+(?:~\s*)?([\d.]+)\s*([a-zA-Z/]+)',
  );
  static final _speed = RegExp(
    r'\bat\s+([\d.]+)\s*([A-Za-z]+/s)',
  );
  static final _eta = RegExp(r'\bETA\s+(\d{1,2}:\d{2}(?::\d{2})?)');
  static final _destination = RegExp(r'\[download\]\s+Destination:\s+(.+)');

  bool isDownloadLine(String line) => line.contains('[download]');

  /// Parses a single line into a [DownloadProgress], or null when the line
  /// carries no progress information.
  DownloadProgress? parse(String line) {
    if (!isDownloadLine(line)) return null;

    final destMatch = _destination.firstMatch(line);
    if (destMatch != null) {
      return DownloadProgress(statusLabel: destMatch.group(1));
    }

    final percentMatch = _percent.firstMatch(line);
    if (percentMatch == null) {
      // e.g. "[download] Downloading item 1 of 3"
      return DownloadProgress(statusLabel: line.replaceFirst('[download]', '').trim());
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

    return DownloadProgress(
      percent: percent,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      speedBytesPerSecond: speed,
      eta: eta,
    );
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
      return Duration(
        hours: parts[0]!,
        minutes: parts[1]!,
        seconds: parts[2]!,
      );
    }
    if (parts.length == 2) {
      return Duration(minutes: parts[0]!, seconds: parts[1]!);
    }
    return null;
  }
}
