import 'package:flutter/material.dart';

import '../pages/home_video_draft.dart';
import 'format_pickers.dart';
import 'media_info_card.dart';
import 'output_folder_row.dart';

class HomeVideoSettings extends StatelessWidget {
  const HomeVideoSettings({
    super.key,
    required this.draft,
    required this.preferredLanguage,
    required this.onChanged,
    required this.onDownload,
    this.onClearSelection,
  });

  final HomeVideoDraft draft;
  final String preferredLanguage;
  final VoidCallback onChanged;
  final VoidCallback? onDownload;
  final VoidCallback? onClearSelection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaInfoCard(info: draft.info, onClearSelection: onClearSelection),
        const SizedBox(height: 12),
        FormatSelectionCard(
          info: draft.info,
          input: draft.input,
          onChanged: onChanged,
          preferredLanguage: preferredLanguage,
        ),
        const SizedBox(height: 12),
        OutputFolderRow(
          directory: draft.input.outputDirectory,
          onChanged: (directory) {
            draft.input.selectOutputDirectory(directory);
            onChanged();
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(220, 52),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
