import 'dart:io';

import '../../core/utils/path_utils.dart';

class AndroidPaths extends PathUtils {
  const AndroidPaths(this.root);
  final String root;

  @override
  Directory appDataDirectory() => Directory(root);
}
