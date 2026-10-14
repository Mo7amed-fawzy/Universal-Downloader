import 'package:flutter/material.dart';

import '../../core/models/audio_output_format.dart';
import '../pages/home_video_draft.dart';
import 'home_download_actions.dart';
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
    required this.onDownloadAudio,
    this.onClearSelection,
  });

  final HomeVideoDraft draft;
  final String preferredLanguage;
  final VoidCallback onChanged;
  final VoidCallback? onDownload;
  final ValueChanged<AudioOutputFormat>? onDownloadAudio;
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
          child: HomeDownloadActions(
            onDownload: onDownload,
            onDownloadAudio: onDownloadAudio,
          ),
        ),
      ],
    );
  }
}
