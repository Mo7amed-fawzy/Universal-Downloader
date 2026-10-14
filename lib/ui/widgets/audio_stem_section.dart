import 'package:flutter/material.dart';

import '../pages/home_input.dart';
import 'audio_stem_control.dart';

class AudioStemSection extends StatelessWidget {
  const AudioStemSection({
    super.key,
    required this.input,
    required this.onChanged,
  });

  final HomeInput input;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRemoval =
        !input.keepSpeech || !input.keepMusic || !input.keepEffects;
    final isMuted =
        !input.keepSpeech &&
        !input.keepMusic &&
        !input.keepEffects &&
        input.speechRemovalStrength == 1 &&
        input.musicRemovalStrength == 1 &&
        input.effectsRemovalStrength == 1;
    final needsSeparation =
        (!input.keepSpeech && input.speechRemovalStrength > 0) ||
        (!input.keepMusic && input.musicRemovalStrength > 0) ||
        (!input.keepEffects && input.effectsRemovalStrength > 0);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        'Keep in downloaded video',
        style: theme.textTheme.titleMedium,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose which sounds to keep. Use the sliders to control removal strength.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        AudioStemControl(
          label: 'Speech',
          keep: input.keepSpeech,
          removalStrength: input.speechRemovalStrength,
          onKeepChanged: (value) {
            input.selectKeepSpeech(value);
            onChanged();
          },
          onRemovalStrengthChanged: (value) {
            input.selectSpeechRemovalStrength(value);
            onChanged();
          },
        ),
        AudioStemControl(
          label: 'Music',
          keep: input.keepMusic,
          removalStrength: input.musicRemovalStrength,
          onKeepChanged: (value) {
            input.selectKeepMusic(value);
            onChanged();
          },
          onRemovalStrengthChanged: (value) {
            input.selectMusicRemovalStrength(value);
            onChanged();
          },
        ),
        AudioStemControl(
          label: 'Sound effects',
          keep: input.keepEffects,
          removalStrength: input.effectsRemovalStrength,
          onKeepChanged: (value) {
            input.selectKeepEffects(value);
            onChanged();
          },
          onRemovalStrengthChanged: (value) {
            input.selectEffectsRemovalStrength(value);
            onChanged();
          },
        ),
        if (hasRemoval && needsSeparation)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isMuted
                  ? 'The video will have no audio.'
                  : 'Audio separation needs ELUATE and its Bandit v2 model installed locally.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
