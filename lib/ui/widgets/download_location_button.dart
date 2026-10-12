import 'package:flutter/material.dart';

import '../../core/services/file_location_service.dart';
import 'error_dialog.dart';

class DownloadLocationButton extends StatelessWidget {
  const DownloadLocationButton({
    super.key,
    required this.outputPath,
    this.locationService = const FileLocationService(),
    this.openDownload,
  });

  final String? outputPath;
  final FileLocationService locationService;
  final Future<void> Function(String)? openDownload;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: Theme.of(context).platform == TargetPlatform.android
          ? 'Open video'
          : 'Open location',
      icon: const Icon(Icons.folder_open),
      onPressed: outputPath == null ? null : () => _openLocation(context),
    );
  }

  Future<void> _openLocation(BuildContext context) async {
    try {
      await (openDownload ?? locationService.open)(outputPath!);
    } catch (error) {
      if (!context.mounted) return;
      await showErrorDialog(
        context,
        message: 'Could not open the download location.',
        details: error.toString(),
      );
    }
  }
}
