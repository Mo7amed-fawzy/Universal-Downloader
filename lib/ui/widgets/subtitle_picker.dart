import 'package:flutter/material.dart';

import '../../core/models/subtitle_track.dart';
import '../pages/home_input.dart';
import 'subtitle_file_switch.dart';

class SubtitlePicker extends StatelessWidget {
  const SubtitlePicker({
    super.key,
    required this.tracks,
    required this.input,
    required this.onChanged,
  });

  final List<SubtitleTrack> tracks;
  final HomeInput input;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(input.subtitle?.id ?? ''),
          initialValue: input.subtitle?.id ?? '',
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Subtitles',
            prefixIcon: const Icon(Icons.subtitles_outlined),
            helperText: tracks.isEmpty ? 'No subtitles available' : null,
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('None')),
            for (final track in tracks)
              DropdownMenuItem(
                value: track.id,
                child: Text(track.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: tracks.isEmpty
              ? null
              : (id) {
                  input.selectSubtitle(
                    id == null || id.isEmpty
                        ? null
                        : tracks.firstWhere((track) => track.id == id),
                  );
                  onChanged();
                },
        ),
        const SizedBox(height: 8),
        SubtitleFileSwitch(input: input, onChanged: onChanged),
      ],
    );
  }
}
