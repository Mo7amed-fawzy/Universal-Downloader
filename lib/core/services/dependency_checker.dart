import 'dart:io';

import '../process/process_runner.dart';

/// Status of a single external tool required by the application.
class DependencyStatus {
  const DependencyStatus({
    required this.name,
    required this.installed,
    this.version,
    this.path,
    this.installInstructions,
  });

  final String name;
  final bool installed;
  final String? version;
  final String? path;
  final String? installInstructions;

  DependencyStatus copyWith({String? version, String? path}) {
    return DependencyStatus(
      name: name,
      installed: installed,
      version: version ?? this.version,
      path: path ?? this.path,
      installInstructions: installInstructions,
    );
  }
}

/// Detects and versions the external executables the app depends on.
class DependencyChecker {
  DependencyChecker({
    ProcessRunner? runner,
    this.ytDlpPathOverride,
    this.ffmpegPathOverride,
    this.ffprobePathOverride,
    this.denoPathOverride,
  }) : runner = runner ?? const ProcessRunner();

  final ProcessRunner runner;
  String? ytDlpPathOverride;
  String? ffmpegPathOverride;
  String? ffprobePathOverride;
  String? denoPathOverride;

  static const _repairInstructions =
      'Restore the included tools in Advanced → Diagnostics, or reinstall the complete app package.';

  Future<List<DependencyStatus>> checkAll() async {
    return Future.wait([
      _check(
        name: 'yt-dlp',
        overridePath: ytDlpPathOverride,
        versionArgs: const ['--version'],
        installInstructions: _repairInstructions,
        versionPattern: RegExp(r'([\d.]+)'),
      ),
      _check(
        name: 'ffmpeg',
        overridePath: ffmpegPathOverride,
        versionArgs: const ['-version'],
        installInstructions: _repairInstructions,
        versionPattern: RegExp(r'ffmpeg version (\S+)'),
      ),
      _check(
        name: 'ffprobe',
        overridePath: ffprobePathOverride,
        versionArgs: const ['-version'],
        installInstructions: _repairInstructions,
        versionPattern: RegExp(r'ffprobe version (\S+)'),
      ),
      _check(
        name: 'deno',
        overridePath: denoPathOverride,
        versionArgs: const ['--version'],
        installInstructions: _repairInstructions,
        versionPattern: RegExp(r'deno (\S+)'),
      ),
    ]);
  }

  Future<DependencyStatus> _check({
    required String name,
    required String? overridePath,
    required List<String> versionArgs,
    required String installInstructions,
    required RegExp versionPattern,
  }) async {
    var executable = overridePath;

    if (executable == null || executable.isEmpty || !executable.contains('/')) {
      executable = await _resolveFromPath(
        executable == null || executable.isEmpty ? name : executable,
      );
    }

    if (executable == null) {
      return DependencyStatus(
        name: name,
        installed: false,
        installInstructions: installInstructions,
      );
    }

    final version = await _fetchVersion(
      executable,
      versionArgs,
      versionPattern,
    );

    return DependencyStatus(
      name: name,
      installed: version != null,
      installInstructions: version == null ? installInstructions : null,
      path: executable,
      version: version,
    );
  }

  Future<String?> _resolveFromPath(String name) async {
    for (final directory in (Platform.environment['PATH'] ?? '').split(':')) {
      if (directory.isEmpty) continue;
      final file = File('$directory/$name');
      if (await file.exists()) return file.absolute.path;
    }
    return null;
  }

  Future<String?> _fetchVersion(
    String executable,
    List<String> args,
    RegExp pattern,
  ) async {
    try {
      final result = await runner.run(executable: executable, arguments: args);
      if (!result.success) return null;
      final firstLine = result.stdout.split('\n').first;
      final match = pattern.firstMatch(firstLine);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }
}
