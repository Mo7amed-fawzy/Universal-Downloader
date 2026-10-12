import 'dart:io';

class DownloadFileService {
  const DownloadFileService();

  Future<bool?> exists(String? location) async {
    if (location == null || location.isEmpty) return false;
    final uri = Uri.tryParse(location);
    if (uri?.scheme == 'content') return null;
    try {
      final file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(location);
      return await file.exists();
    } on FileSystemException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
