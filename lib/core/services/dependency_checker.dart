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
  }) : runner = runner ?? const ProcessRunner();

  final ProcessRunner runner;
  final String? ytDlpPathOverride;
  final String? ffmpegPathOverride;
  final String? ffprobePathOverride;

  static const _ytDlpInstall = 'Install with: pipx install yt-dlp  '
      '(or: pip install -U yt-dlp).';
  static const _ffmpegInstall = 'Install with your package manager, e.g.:\n'
      '  sudo apt install ffmpeg  (Debian/Ubuntu)\n'
      '  sudo dnf install ffmpeg   (Fedora)\n'
      '  sudo pacman -S ffmpeg     (Arch).';

  Future<List<DependencyStatus>> checkAll() async {
    return Future.wait([
      _check(
        name: 'yt-dlp',
        overridePath: ytDlpPathOverride,
        versionArgs: const ['--version'],
        installInstructions: _ytDlpInstall,
        versionPattern: RegExp(r'([\d.]+)'),
      ),
      _check(
        name: 'ffmpeg',
        overridePath: ffmpegPathOverride,
        versionArgs: const ['-version'],
        installInstructions: _ffmpegInstall,
        versionPattern: RegExp(r'ffmpeg version (\S+)'),
      ),
      _check(
        name: 'ffprobe',
        overridePath: ffprobePathOverride,
        versionArgs: const ['-version'],
        installInstructions: _ffmpegInstall,
        versionPattern: RegExp(r'ffprobe version (\S+)'),
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

    if (executable == null || !File(executable).existsSync()) {
      executable = await _resolveFromPath(name);
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
      installed: true,
      path: executable,
      version: version,
    );
  }

  Future<String?> _resolveFromPath(String name) async {
    try {
      final result = await runner.run(executable: 'which', arguments: [name]);
      if (result.success && result.stdout.trim().isNotEmpty) {
        return result.stdout.trim().split('\n').first;
      }
    } catch (_) {
      // fall through
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
