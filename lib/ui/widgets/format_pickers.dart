import 'package:flutter/material.dart';

import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/utils/language_names.dart';
import '../../providers/format_selector.dart';
import '../components/status_chip.dart';
import '../pages/home_input.dart';
import 'subtitle_picker.dart';
import 'audio_quality_dropdown.dart';
import 'audio_stem_section.dart';

/// Provider-agnostic format selection controls: video quality, audio language
/// + bitrate, and container preference.
class FormatSelectionCard extends StatelessWidget {
  const FormatSelectionCard({
    super.key,
    required this.info,
    required this.input,
    required this.onChanged,
    required this.preferredLanguage,
  });

  final MediaInfo info;
  final HomeInput input;
  final VoidCallback onChanged;

  final String preferredLanguage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = info.audioLanguages;
    final hasAudio = languages.isNotEmpty;
    final heights = const FormatSelector().availableVideoHeights(
      info.videoFormats,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Video Quality', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey((info, input.videoHeight)),
              isExpanded: true,
              initialValue: input.videoHeight ?? 0,
              items: [
                const DropdownMenuItem(
                  value: 0,
                  child: Text('Auto / Best Available'),
                ),
                for (final height in heights)
                  DropdownMenuItem(value: height, child: Text('${height}p')),
              ],
              onChanged: (v) {
                if (v == null) return;
                input.selectVideoHeight(v == 0 ? null : v);
                onChanged();
              },
            ),
            const Divider(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('Audio', style: theme.textTheme.titleMedium),
                if (hasAudio)
                  StatusChip(
                    label: preferredHasAudio
                        ? '${LanguageNames.nameFor(preferredLanguage)} audio detected'
                        : 'Using ${LanguageNames.nameFor(input.audioLanguage ?? preferredLanguage)} instead',
                    icon: preferredHasAudio
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: preferredHasAudio
                        ? Colors.green
                        : theme.colorScheme.tertiary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasAudio)
              Text(
                'This media has no separate audio tracks; its embedded audio '
                'will be used.',
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: input.audioLanguage,
                decoration: const InputDecoration(labelText: 'Language'),
                items: [
                  for (final lang in languages)
                    DropdownMenuItem<String?>(
                      value: lang,
                      child: Text(_languageLabel(lang, theme)),
                    ),
                ],
                onChanged: (v) {
                  input.selectAudioLanguage(v);
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Auto = Best ${LanguageNames.nameFor(input.audioLanguage ?? preferredLanguage)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Switch(
                    value: input.autoBestAudio,
                    onChanged: (v) {
                      input.selectAutoBestAudio(v);
                      onChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AudioQualityDropdown(
                info: info,
                language: input.audioLanguage,
                selected: input.autoBestAudio ? null : input.audioBitrate,
                onChanged: (v) {
                  input.selectAudioBitrate(v);
                  onChanged();
                },
              ),
            ],
            const Divider(height: 32),
            SubtitlePicker(
              tracks: info.subtitleTracks,
              input: input,
              onChanged: onChanged,
            ),
            const Divider(height: 32),
            AudioStemSection(input: input, onChanged: onChanged),
            const Divider(height: 32),
            Text('Container', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<ContainerPreference>(
              initialValue: input.containerPreference,
              items: ContainerPreference.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                input.selectContainer(v);
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool get preferredHasAudio => info.hasAudioForLanguage(preferredLanguage);

  String _languageLabel(String code, ThemeData theme) {
    final base = code.split('-').first.toLowerCase();
    final prefBase = preferredLanguage.split('-').first.toLowerCase();
    final isPreferred = base == prefBase;
    return '${LanguageNames.nameFor(code)} '
        '${isPreferred ? ' (preferred)' : ''}';
  }
}
