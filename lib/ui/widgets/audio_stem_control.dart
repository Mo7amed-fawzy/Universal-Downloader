import 'package:flutter/material.dart';

class AudioStemControl extends StatelessWidget {
  const AudioStemControl({
    super.key,
    required this.label,
    required this.keep,
    required this.removalStrength,
    required this.onKeepChanged,
    required this.onRemovalStrengthChanged,
  });

  final String label;
  final bool keep;
  final double removalStrength;
  final ValueChanged<bool> onKeepChanged;
  final ValueChanged<double> onRemovalStrengthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (removalStrength * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: keep,
          checkboxShape: const CircleBorder(),
          activeColor: theme.colorScheme.onSurface,
          checkColor: theme.colorScheme.surface,
          side: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            width: 1.2,
          ),
          onChanged: (value) => onKeepChanged(value ?? true),
        ),
        if (!keep)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Removal strength: $percent%'),
                Slider(
                  value: removalStrength,
                  label: '$percent%',
                  onChanged: onRemovalStrengthChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
