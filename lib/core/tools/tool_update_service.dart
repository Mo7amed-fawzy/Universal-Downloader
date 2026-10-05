import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'tool_bundle_installer.dart';
import 'tool_paths.dart';

class ToolUpdateService {
  const ToolUpdateService(this.paths);

  final ToolPaths paths;

  static final releaseApi = Uri.parse(
    'https://api.github.com/repos/Mo7amed-fawzy/Universal-Downloader/releases/latest',
  );

  Future<String> update({required void Function(String) onStatus}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    Directory? temporary;
    try {
      onStatus('Checking for updates…');
      final request = await client.getUrl(releaseApi);
      request.headers.set('User-Agent', 'UniversalDownloader');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode == 404) {
        await response.drain<void>();
        return 'No tool updates have been published yet. Included tools are ready to use.';
      }
      if (response.statusCode != 200) {
        throw HttpException('Update check failed (${response.statusCode}).');
      }
      final release = jsonDecode(
        await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 30)),
      );
      if (release is! Map<String, dynamic> || release['assets'] is! List) {
        throw const FormatException('Invalid update release');
      }
      final assets = (release['assets'] as List)
          .whereType<Map<String, dynamic>>();
      Uri? metadataUrl;
      Uri? archiveUrl;
      for (final asset in assets) {
        if (asset['name'] == 'runtime-linux-x64.json') {
          metadataUrl = _assetUrl(asset);
        }
        if (asset['name'] == 'runtime-linux-x64.zip') {
          archiveUrl = _assetUrl(asset);
        }
      }
      if (metadataUrl == null || archiveUrl == null) {
        return 'No tool update is available for Linux x64.';
      }
      await paths.updatesDirectory.create(recursive: true);
      temporary = await paths.updatesDirectory.createTemp('.download-');
      final metadataFile = File('${temporary.path}/release.json');
      await _download(client, metadataUrl, metadataFile, limit: 65536);
      final metadata = jsonDecode(await metadataFile.readAsString());
      if (metadata is! Map<String, dynamic> ||
          metadata['schema'] != 1 ||
          metadata['platform'] != 'linux-x64' ||
          metadata['revision'] is! int ||
          metadata['sha256'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(metadata['sha256'] as String)) {
        throw const FormatException('Invalid tool update metadata');
      }
      final revision = metadata['revision'] as int;
      if (revision <= (paths.selected?.revision ?? 0)) {
        return 'Your included tools are up to date.';
      }
      final archive = File('${temporary.path}/runtime.zip');
      onStatus('Downloading tool update…');
      await _download(client, archiveUrl, archive, limit: 600 * 1024 * 1024);
      onStatus('Verifying and installing…');
      final bundledPath = paths.bundledDirectory.path;
      final updatesPath = paths.updatesDirectory.path;
      final hash = metadata['sha256'] as String;
      await Isolate.run(
        () => ToolBundleInstaller(
          paths: ToolPaths(
            bundledDirectory: Directory(bundledPath),
            updatesDirectory: Directory(updatesPath),
          ),
        ).install(archive, hash, revision),
      );
      return 'Tools updated successfully.';
    } finally {
      client.close(force: true);
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  Uri _assetUrl(Map<String, dynamic> asset) {
    final url = asset['browser_download_url'];
    if (url is! String ||
        !url.startsWith(
          'https://github.com/Mo7amed-fawzy/Universal-Downloader/releases/download/',
        )) {
      throw const FormatException('Unexpected tool update source');
    }
    return Uri.parse(url);
  }

  Future<void> _download(
    HttpClient client,
    Uri url,
    File file, {
    required int limit,
  }) async {
    final request = await client.getUrl(url);
    request.headers.set('User-Agent', 'UniversalDownloader');
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Tool download failed (${response.statusCode}).');
    }
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
        if (received > limit) {
          throw const FormatException('Tool download exceeds size limit');
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}
