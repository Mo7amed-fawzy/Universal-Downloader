import 'package:flutter/material.dart';

import '../pages/home_input.dart';

class SubtitleFileSwitch extends StatelessWidget {
  const SubtitleFileSwitch({
    super.key,
    required this.input,
    required this.onChanged,
  });

  final HomeInput input;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Add separate subtitle file'),
      value: input.downloadSubtitleFile,
      onChanged: input.subtitle == null
          ? null
          : (value) {
              input.selectDownloadSubtitleFile(value);
              onChanged();
            },
    );
  }
}
