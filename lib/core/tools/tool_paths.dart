import 'dart:io';

import '../utils/path_utils.dart';
import 'tool_bundle.dart';

class ToolPaths {
  ToolPaths({Directory? bundledDirectory, Directory? updatesDirectory})
    : bundledDirectory =
          bundledDirectory ??
          Directory('${File(Platform.resolvedExecutable).parent.path}/tools'),
      updatesDirectory =
          updatesDirectory ??
          Directory('${const PathUtils().appDataDirectory().path}/tools');

  final Directory bundledDirectory;
  final Directory updatesDirectory;

  File get activeFile => File('${updatesDirectory.path}/active');

  ToolBundle? get bundled => _read(bundledDirectory);

  ToolBundle? get selected {
    final included = bundled;
    try {
      final name = activeFile.readAsStringSync().trim();
      if (!RegExp(r'^bundle-[0-9]+-[a-f0-9]{12}$').hasMatch(name)) {
        return included;
      }
      final updated = _read(Directory('${updatesDirectory.path}/$name'));
      if (updated != null && updated.revision >= (included?.revision ?? 0)) {
        return updated;
      }
    } on FileSystemException catch (_) {}
    return included;
  }

  String resolve(String name, {String override = ''}) {
    if (override.trim().isNotEmpty) return override.trim();
    final bundle = selected;
    if (bundle != null) return bundle.executable(name);
    if (File('${bundledDirectory.path}/manifest.json').existsSync()) {
      return '${bundledDirectory.path}/$name';
    }
    return name;
  }

  Future<void> useIncluded() async {
    if (await activeFile.exists()) await activeFile.delete();
  }

  ToolBundle? _read(Directory directory) {
    try {
      final bundle = ToolBundle.read(directory);
      if (!ToolBundle.executables.every(
        (name) => File(bundle.executable(name)).existsSync(),
      )) {
        return null;
      }
      return bundle;
    } on FileSystemException catch (_) {
      return null;
    } on FormatException catch (_) {
      return null;
    }
  }
}
