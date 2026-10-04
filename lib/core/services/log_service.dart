import 'dart:io';

import '../utils/path_utils.dart';

/// Structured logger writing `[LEVEL] message` lines to stdout and to a
/// rotating log file in the application data directory.
class LogService {
  LogService({PathUtils? paths, this.debugEnabled = false})
      : _paths = paths ?? const PathUtils();

  final PathUtils _paths;
  bool debugEnabled;
  final List<String> _buffer = [];
  static const _maxBufferedLines = 2000;
  File? _file;

  void info(String message) => _write('INFO', message);
  void warn(String message) => _write('WARN', message);
  void error(String message) => _write('ERROR', message);
  void debug(String message) {
    if (debugEnabled) _write('DEBUG', message);
  }

  void _write(String level, String message) {
    final line = '[${DateTime.now().toIso8601String()}] '
        '[${level.padRight(5)}] $message';
    stdout.writeln(line);
    _buffer.add(line);
    if (_buffer.length > _maxBufferedLines) {
      _buffer.removeRange(0, _buffer.length - _maxBufferedLines);
    }
    _appendToFile(line);
  }

  void _appendToFile(String line) {
    try {
      final file = _file ??= _openLogFile();
      file.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {
      // Logging must never crash the app.
    }
  }

  File _openLogFile() {
    final dir = _paths.logDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/universal_downloader.log');
  }

  /// Full buffered log (including current session).
  String get sessionLog => _buffer.join('\n');

  /// Content of the persisted log file.
  String readPersistedLog() {
    try {
      final file = _file ?? _openLogFile();
      if (!file.existsSync()) return '';
      return file.readAsStringSync();
    } catch (_) {
      return '';
    }
  }
}
