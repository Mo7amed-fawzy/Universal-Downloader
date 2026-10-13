import 'package:flutter/material.dart';

import '../pages/home_video_entry.dart';

class HomeDownloadSelection extends StatelessWidget {
  const HomeDownloadSelection({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  final List<HomeVideoEntry> entries;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final count = entries.where((entry) => entry.selectedForDownload).length;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      tristate: true,
      value: count == 0
          ? false
          : count == entries.length
          ? true
          : null,
      title: const Text('Select all'),
      subtitle: Text('$count of ${entries.length} selected'),
      onChanged: entries.isEmpty
          ? null
          : (_) {
              for (final entry in entries) {
                entry.selectForDownload(count != entries.length);
              }
              onChanged();
            },
    );
  }
}
