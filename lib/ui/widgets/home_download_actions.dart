import 'package:flutter/material.dart';

import '../../core/models/audio_output_format.dart';

class HomeDownloadActions extends StatelessWidget {
  const HomeDownloadActions({
    super.key,
    required this.onDownload,
    required this.onDownloadAudio,
    this.downloadLabel = 'Download',
    this.compact = false,
  });

  final VoidCallback? onDownload;
  final ValueChanged<AudioOutputFormat>? onDownloadAudio;
  final String downloadLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: 12,
    runSpacing: 12,
    children: [
      MenuAnchor(
        menuChildren: [
          for (final format in AudioOutputFormat.values)
            MenuItemButton(
              onPressed: onDownloadAudio == null
                  ? null
                  : () => onDownloadAudio!(format),
              child: Text(format.label),
            ),
        ],
        builder: (context, menuController, child) => OutlinedButton.icon(
          onPressed: onDownloadAudio == null ? null : menuController.open,
          icon: const Icon(Icons.audio_file_outlined),
          label: const Text('Download audio'),
          style: compact
              ? null
              : OutlinedButton.styleFrom(minimumSize: const Size(180, 52)),
        ),
      ),
      FilledButton.icon(
        onPressed: onDownload,
        icon: const Icon(Icons.download),
        label: Text(downloadLabel),
        style: compact
            ? null
            : FilledButton.styleFrom(
                minimumSize: const Size(220, 52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ],
  );
}
