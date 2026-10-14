import 'dart:io';

import 'package:flutter/services.dart';

import '../errors/downloader_exceptions.dart';
import '../models/download_options.dart';
import '../process/cancel_token.dart';
import '../process/command_runner.dart';
import '../process/process_runner.dart';
import '../../downloads/download_progress.dart';

class AudioStemProcessor {
  AudioStemProcessor({CommandRunner? runner})
    : _runner = runner ?? const ProcessRunner();

  final CommandRunner _runner;

  String get _python =>
      Platform.environment['UNIVERSAL_DOWNLOADER_PYTHON'] ?? 'python3';

  Future<void> ensureAvailable(CancelToken cancelToken) async {
    try {
      final result = await _runner.run(
        executable: _python,
        arguments: [
          '-c',
          'import eluate, numpy, soundfile; from pathlib import Path; import sys; '
              'sys.exit(0 if (Path.home() / ".eluate/models/checkpoint-multi.ckpt").is_file() '
              'else "Run eluate setup to install the Bandit v2 model")',
        ],
        cancelToken: cancelToken,
      );
      if (!result.success) {
        throw DownloadFailedException(
          'Audio separation needs ELUATE. Install it, then run eluate setup.',
          details: result.stderr,
        );
      }
    } on ProcessException catch (error) {
      throw DownloadFailedException(
        'Python and ELUATE are required for audio separation.',
        details: error.toString(),
      );
    }
  }

  Future<File> process({
    required File source,
    required Directory workspace,
    required String ffmpegPath,
    required DownloadOptions options,
    required void Function(DownloadProgress) onProgress,
    required CancelToken cancelToken,
  }) async {
    final script = File('${workspace.path}/audio_stems.py');
    await script.writeAsString(
      await rootBundle.loadString('assets/audio_stems.py'),
    );
    final ffmpegDirectory = File(ffmpegPath).parent.path;
    final environment = {
      'PATH': '$ffmpegDirectory:${Platform.environment['PATH'] ?? ''}',
    };
    try {
      final result = await _runner.run(
        executable: _python,
        arguments: [
          '-u',
          script.path,
          source.path,
          workspace.path,
          ffmpegPath,
          options.speechLevel.toString(),
          options.musicLevel.toString(),
          options.effectsLevel.toString(),
        ],
        environment: environment,
        cancelToken: cancelToken,
        onLine: (line, isStdout) {
          if (!isStdout) return;
          final parts = line.split('\t');
          if (parts.length != 3 || parts.first != 'PROGRESS') return;
          final percent = double.tryParse(parts[1]);
          if (percent == null) return;
          final label = switch (parts[2]) {
            'extract' => 'Extracting audio',
            'load_model' => 'Loading Bandit v2',
            'separate' => 'Separating speech, music and effects',
            'mix' => 'Mixing selected sounds',
            'encode' => 'Encoding selected audio',
            _ => 'Processing audio',
          };
          onProgress(DownloadProgress(percent: percent, statusLabel: label));
        },
      );
      if (!result.success) {
        throw DownloadFailedException(
          'Audio separation failed. Check that the Bandit v2 model is installed with eluate setup.',
          details: result.stderr,
        );
      }
    } on ProcessException catch (error) {
      throw DownloadFailedException(
        'Audio separation could not start.',
        details: error.toString(),
      );
    }
    cancelToken.throwIfCancelled();
    final selected = File('${workspace.path}/selected.m4a');
    if (!selected.existsSync() || selected.lengthSync() == 0) {
      throw DownloadFailedException(
        'Audio separation produced no selected audio.',
      );
    }
    return selected;
  }
}
