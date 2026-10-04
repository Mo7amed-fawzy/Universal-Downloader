/// Sanitizes untrusted titles into safe filename fragments for Linux.
class FilenameSanitizer {
  const FilenameSanitizer();

  /// Characters that are illegal or dangerous in a Linux filename.
  static const _forbidden = '/';

  /// Controls characters that should be stripped.
  static bool _isControl(int code) => code < 32 || code == 127;

  /// Characters that are risky or cause UI trouble and should be replaced.
  static const _replaced = r'\\:*?"<>|';

  /// Sanitizes [input] so it can be safely used as a filename on Linux.
  ///
  /// * Removes path separators and NUL bytes (path traversal protection).
  /// * Strips control characters.
  /// * Replaces shell/Windows metacharacters with an underscore.
  /// * Collapses whitespace and trims leading dots and spaces.
  /// * Falls back to a placeholder when the result is empty or `.`/`..`.
  String sanitize(String input) {
    if (input.isEmpty) return _fallback;

    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final rune = input.codeUnitAt(i);
      if (_isControl(rune)) continue;
      if (_forbidden.contains(input[i])) {
        buffer.write('_');
      } else if (_replaced.contains(input[i])) {
        buffer.write('_');
      } else {
        buffer.write(input[i]);
      }
    }

    var result = buffer.toString();

    // Collapse runs of whitespace into a single space.
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Guard against traversal and hidden-dot names.
    result = result.replaceAll(RegExp(r'^\.+'), '');
    result = result.replaceAll(RegExp(r'\.+$'), '');

    if (result.isEmpty || result == '.' || result == '..') {
      return _fallback;
    }

    // Cap length to something sane for a filename.
    const maxLength = 180;
    if (result.length > maxLength) {
      result = result.substring(0, maxLength).trimRight();
    }

    return result;
  }

  static const String _fallback = 'download';

  /// Sanitizes and returns a title-safe fragment for logging/preview.
  String preview(String input) => sanitize(input);
}
