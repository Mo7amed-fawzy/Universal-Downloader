import 'package:flutter/material.dart';

import '../../core/models/audio_format.dart';
import '../../core/models/download_options.dart';
import '../../core/models/media_info.dart';
import '../../core/utils/language_names.dart';
import '../../providers/format_selector.dart';
import '../components/status_chip.dart';

/// Provider-agnostic format selection controls: video quality, audio language
/// + bitrate, and container preference.
class FormatSelectionCard extends StatelessWidget {
  const FormatSelectionCard({
    super.key,
    required this.info,
    required this.videoQuality,
    required this.onVideoQualityChanged,
    required this.audioLanguage,
    required this.onAudioLanguageChanged,
    required this.autoBestAudio,
    required this.onAutoBestAudioChanged,
    required this.audioBitrate,
    required this.onAudioBitrateChanged,
    required this.preferredLanguage,
    required this.containerPreference,
    required this.onContainerPreferenceChanged,
  });

  final MediaInfo info;
  final VideoQuality videoQuality;
  final ValueChanged<VideoQuality> onVideoQualityChanged;

  final String? audioLanguage;
  final ValueChanged<String?> onAudioLanguageChanged;
  final bool autoBestAudio;
  final ValueChanged<bool> onAutoBestAudioChanged;
  final int? audioBitrate;
  final ValueChanged<int?> onAudioBitrateChanged;

  final String preferredLanguage;
  final ContainerPreference containerPreference;
  final ValueChanged<ContainerPreference> onContainerPreferenceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = info.audioLanguages;
    final hasAudio = languages.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Video Quality', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<VideoQuality>(
              initialValue: videoQuality,
              items: VideoQuality.values
                  .map(
                    (q) => DropdownMenuItem(
                      value: q,
                      child: Text(
                        q == VideoQuality.best
                            ? 'Auto / Best Available'
                            : q.label,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onVideoQualityChanged(v);
              },
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(child: Text('Audio', style: theme.textTheme.titleMedium)),
                if (hasAudio)
                  StatusChip(
                    label: preferredHasAudio
                        ? '${LanguageNames.nameFor(preferredLanguage)} audio detected'
                        : 'Using ${LanguageNames.nameFor(audioLanguage ?? preferredLanguage)} instead',
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
                initialValue: audioLanguage,
                decoration: const InputDecoration(labelText: 'Language'),
                items: [
                  for (final lang in languages)
                    DropdownMenuItem<String?>(
                      value: lang,
                      child: Text(_languageLabel(lang, theme)),
                    ),
                ],
                onChanged: (v) => onAudioLanguageChanged(v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Auto = Best ${LanguageNames.nameFor(audioLanguage ?? preferredLanguage)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Switch(
                    value: autoBestAudio,
                    onChanged: onAutoBestAudioChanged,
                  ),
                ],
              ),
              if (!autoBestAudio) ...[
                const SizedBox(height: 8),
                _AudioBitrateDropdown(
                  info: info,
                  language: audioLanguage,
                  selected: audioBitrate,
                  onChanged: onAudioBitrateChanged,
                ),
              ],
            ],
            const Divider(height: 32),
            Text('Container', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<ContainerPreference>(
              initialValue: containerPreference,
              items: ContainerPreference.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onContainerPreferenceChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool get preferredHasAudio =>
      info.hasAudioForLanguage(preferredLanguage);

  String _languageLabel(String code, ThemeData theme) {
    final base = code.split('-').first.toLowerCase();
    final prefBase = preferredLanguage.split('-').first.toLowerCase();
    final isPreferred = base == prefBase;
    return '${LanguageNames.nameFor(code)} '
        '${isPreferred ? ' (preferred)' : ''}';
  }
}

class _AudioBitrateDropdown extends StatelessWidget {
  const _AudioBitrateDropdown({
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
    const selector = FormatSelector();
    final formats = language == null
        ? const <AudioFormat>[]
        : selector.audioForLanguage(info.audioFormats, language!);
    final bitrates = formats
        .map((f) => f.bitrate)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (bitrates.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<int?>(
      initialValue: selected,
      decoration: const InputDecoration(labelText: 'Quality'),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Best Available'),
        ),
        for (final bitrate in bitrates)
          DropdownMenuItem<int?>(
            value: bitrate,
            child: Text('$bitrate kbps'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
