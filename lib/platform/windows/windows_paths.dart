import 'dart:io';

import '../../core/utils/path_utils.dart';

class WindowsPaths extends PathUtils {
  const WindowsPaths(this.localAppData);

  final String localAppData;

  @override
  Directory appDataDirectory() =>
      Directory('$localAppData/UniversalDownloader');
}
