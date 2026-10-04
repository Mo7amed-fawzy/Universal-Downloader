/// Formatting helpers for human-friendly display of bytes, durations and
/// speeds. Purely presentational, no logic.
class FormatUtils {
  const FormatUtils._();

  static String bytes(int? bytes, {String fallback = 'unknown'}) {
    if (bytes == null || bytes < 0) return fallback;
    if (bytes < 1024) return '$bytes B';
    const units = ['KiB', 'MiB', 'GiB', 'TiB'];
    var value = bytes.toDouble();
    var unit = -1;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  static String bytesPerSecond(int? bytesPerSecond) {
    if (bytesPerSecond == null || bytesPerSecond < 0) return '--';
    return '${bytes(bytesPerSecond)}/s';
  }

  static String duration(Duration? d) {
    if (d == null) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      return '$hh:$m:$s';
    }
    return '$m:$s';
  }

  static String bitrate(int? kbps) {
    if (kbps == null || kbps <= 0) return '--';
    return '${kbps.round()} kbps';
  }
}
