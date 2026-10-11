import 'package:flutter/material.dart';

import '../../core/models/media_info.dart';
import '../../providers/format_selector.dart';

class AudioQualityDropdown extends StatelessWidget {
  const AudioQualityDropdown({
    super.key,
    required this.info,
    required this.language,
    required this.selected,
    required this.onChanged,
  });

  final MediaInfo info;
  final String? language;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bitrates = language == null
        ? const <int>[]
        : const FormatSelector().availableAudioBitrates(
            info.audioFormats,
            language!,
          );

    return DropdownButtonFormField<int?>(
      key: ValueKey((info, language, selected)),
      isExpanded: true,
      initialValue: bitrates.contains(selected) ? selected : null,
      hint: const Text('Best Available'),
      decoration: InputDecoration(
        labelText: 'Audio Quality',
        helperMaxLines: 3,
        helperText: bitrates.isEmpty
            ? 'The source does not report a bitrate for this audio track.'
            : 'Available bitrates for the selected audio language.',
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Best Available'),
        ),
        for (final bitrate in bitrates)
          DropdownMenuItem<int?>(value: bitrate, child: Text('$bitrate kbps')),
      ],
      onChanged: onChanged,
    );
  }
}
