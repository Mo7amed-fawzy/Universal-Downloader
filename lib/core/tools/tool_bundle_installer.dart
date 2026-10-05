import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../process/process_runner.dart';
import '../process/cancel_token.dart';
import 'tool_bundle.dart';
import 'tool_paths.dart';

class ToolBundleInstaller {
  const ToolBundleInstaller({
    required this.paths,
    this.runner = const ProcessRunner(),
  });

  final ToolPaths paths;
  final ProcessRunner runner;

  Future<void> install(File zip, String expectedHash, int revision) async {
    if ((await sha256.bind(zip.openRead()).first).toString() != expectedHash) {
      throw const FormatException('Tool update checksum mismatch');
    }
    await paths.updatesDirectory.create(recursive: true);
    final staging = await paths.updatesDirectory.createTemp('.install-');
    try {
      final input = InputFileStream(zip.path);
      try {
        final archive = ZipDecoder().decodeStream(input);
        var totalSize = 0;
        for (final entry in archive) {
          totalSize += entry.size;
          if (!ToolBundle.validPath(entry.name) ||
              entry.isSymbolicLink ||
              !entry.isFile ||
              totalSize > 1500 * 1024 * 1024) {
            throw const FormatException('Unsafe tool update archive');
          }
          final file = File('${staging.path}/${entry.name}');
          await file.parent.create(recursive: true);
          final output = OutputFileStream(file.path);
          try {
            entry.writeContent(output);
          } finally {
            await output.close();
          }
        }
      } finally {
        await input.close();
      }
      final bundle = ToolBundle.read(staging);
      if (bundle.revision != revision ||
          revision <= (paths.selected?.revision ?? 0)) {
        throw const FormatException('Tool update is incompatible or outdated');
      }
      final actualFiles = await staging
          .list(recursive: true)
          .where((e) => e is File)
          .length;
      if (actualFiles != bundle.files.length + 1) {
        throw const FormatException('Unexpected files in tool update');
      }
      for (final entry in bundle.files.entries) {
        final hash = await sha256
            .bind(File('${staging.path}/${entry.key}').openRead())
            .first;
        if (hash.toString() != entry.value) {
          throw const FormatException('Damaged tool update');
        }
      }
      for (final name in ToolBundle.executables) {
        final path = bundle.executable(name);
        final mode = await runner.run(
          executable: '/bin/chmod',
          arguments: ['755', path],
        );
        if (!mode.success) {
          throw const FileSystemException('Could not prepare tool executable');
        }
        final cancellation = CancelToken();
        final timer = Timer(const Duration(seconds: 30), cancellation.cancel);
        try {
          final check = await runner.run(
            executable: path,
            arguments: [name.startsWith('ff') ? '-version' : '--version'],
            environment: const {'DENO_NO_UPDATE_CHECK': '1'},
            cancelToken: cancellation,
          );
          if (!check.success) {
            throw FileSystemException('Tool validation failed: $name');
          }
        } finally {
          timer.cancel();
        }
      }
      final name = 'bundle-$revision-${expectedHash.substring(0, 12)}';
      final destination = Directory('${paths.updatesDirectory.path}/$name');
      if (await destination.exists()) await destination.delete(recursive: true);
      await staging.rename(destination.path);
      final pointer = File('${paths.activeFile.path}.pending');
      await pointer.writeAsString(name, flush: true);
      await pointer.rename(paths.activeFile.path);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
}
