import 'dart:convert';
import 'dart:io';

class ToolBundle {
  const ToolBundle({
    required this.directory,
    required this.revision,
    required this.files,
  });

  static const executables = ['yt-dlp', 'ffmpeg', 'ffprobe', 'deno'];
  static const platform = 'linux-x64';

  final Directory directory;
  final int revision;
  final Map<String, String> files;

  String executable(String name) => '${directory.path}/$name';

  static ToolBundle read(Directory directory) {
    final json = jsonDecode(
      File('${directory.path}/manifest.json').readAsStringSync(),
    );
    if (json is! Map<String, dynamic> ||
        json['schema'] != 1 ||
        json['platform'] != platform ||
        json['revision'] is! int ||
        json['files'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported tool bundle manifest');
    }
    final files = <String, String>{};
    for (final entry in (json['files'] as Map<String, dynamic>).entries) {
      if (!validPath(entry.key) ||
          entry.value is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.value as String)) {
        throw const FormatException('Invalid tool bundle file');
      }
      files[entry.key] = entry.value as String;
    }
    if (!executables.every(files.containsKey) ||
        !files.containsKey('licenses/THIRD_PARTY_NOTICES.md')) {
      throw const FormatException('Tool bundle is incomplete');
    }
    return ToolBundle(
      directory: directory,
      revision: json['revision'] as int,
      files: files,
    );
  }

  static bool validPath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('\\') &&
      !path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..');
}
