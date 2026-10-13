import 'package:flutter/material.dart';

import '../pages/home_video_entry.dart';

class HomeDownloadCheckbox extends StatelessWidget {
  const HomeDownloadCheckbox({
    super.key,
    required this.entry,
    required this.onChanged,
  });

  final HomeVideoEntry entry;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final title = entry.draft?.info.title ?? entry.link;
    return Tooltip(
      message: 'Include in download',
      child: Checkbox(
        value: entry.selectedForDownload,
        semanticLabel: 'Include $title in download',
        onChanged: (selected) {
          entry.selectForDownload(selected ?? false);
          onChanged();
        },
      ),
    );
  }
}
