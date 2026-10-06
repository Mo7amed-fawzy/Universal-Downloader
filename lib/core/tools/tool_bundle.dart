import 'dart:convert';
import 'dart:io';

import 'tool_platform.dart';

class ToolBundle {
  const ToolBundle({
    required this.directory,
    required this.revision,
    required this.files,
    this.target = ToolPlatform.linuxX64,
  });

  static const executables = ['yt-dlp', 'ffmpeg', 'ffprobe', 'deno'];
  final ToolPlatform target;

  final Directory directory;
  final int revision;
  final Map<String, String> files;

  String executable(String name) =>
      '${directory.path}/${target.executableName(name)}';

  static ToolBundle read(
    Directory directory, {
    ToolPlatform target = ToolPlatform.linuxX64,
  }) {
    final json = jsonDecode(
      File('${directory.path}/manifest.json').readAsStringSync(),
    );
    if (json is! Map<String, dynamic> ||
        json['schema'] != 1 ||
        json['platform'] != target.id ||
        json['revision'] is! int ||
        json['files'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported tool bundle manifest');
    }
    final files = <String, String>{};
    final names = <String>{};
    for (final entry in (json['files'] as Map<String, dynamic>).entries) {
      if (!validPath(entry.key) ||
          !names.add(
            target == ToolPlatform.windowsX64
                ? entry.key.toLowerCase()
                : entry.key,
          ) ||
          entry.value is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.value as String)) {
        throw const FormatException('Invalid tool bundle file');
      }
      files[entry.key] = entry.value as String;
    }
    if (!executables.every(
          (name) => files.containsKey(target.executableName(name)),
        ) ||
        !files.containsKey('licenses/THIRD_PARTY_NOTICES.md')) {
      throw const FormatException('Tool bundle is incomplete');
    }
    return ToolBundle(
      directory: directory,
      target: target,
      revision: json['revision'] as int,
      files: files,
    );
  }

  static bool validPath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !RegExp(r'[\\:<>"|?*\x00-\x1f]').hasMatch(path) &&
      !path
          .split('/')
          .any(
            (part) =>
                part.isEmpty ||
                part.endsWith('.') ||
                part.endsWith(' ') ||
                RegExp(
                  r'^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(?:\.|$)',
                  caseSensitive: false,
                ).hasMatch(part),
          );
}
