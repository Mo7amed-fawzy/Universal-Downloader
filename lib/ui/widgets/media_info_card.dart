import 'package:flutter/material.dart';

import '../../core/models/media_info.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/language_names.dart';
import '../components/status_chip.dart';
import 'clear_video_selection_button.dart';

/// Shows fetched media metadata: thumbnail, title, uploader, duration and the
/// list of available audio languages.
class MediaInfoCard extends StatelessWidget {
  const MediaInfoCard({super.key, required this.info, this.onClearSelection});

  final MediaInfo info;
  final VoidCallback? onClearSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = info.audioLanguages
        .map((l) => LanguageNames.nameFor(l))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;
            final clearSelection = onClearSelection == null
                ? null
                : ClearVideoSelectionButton(onPressed: onClearSelection!);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact && clearSelection != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: clearSelection,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _Thumbnail(info: info),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusChip(
                                label: info.providerName,
                                icon: Icons.language,
                                color: theme.colorScheme.primary,
                              ),
                              if (info.duration != null)
                                StatusChip(
                                  label: FormatUtils.duration(info.duration),
                                  icon: Icons.schedule,
                                  color: theme.colorScheme.secondary,
                                ),
                              if (info.uploader != null &&
                                  info.uploader!.isNotEmpty)
                                StatusChip(
                                  label: info.uploader!,
                                  icon: Icons.person_outline,
                                  color: theme.colorScheme.tertiary,
                                ),
                            ],
                          ),
                          if (languages.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Audio languages: ${languages.join(', ')}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!compact && clearSelection != null) ...[
                      const SizedBox(width: 8),
                      clearSelection,
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.info});

  final MediaInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uri = info.thumbnail;
    final compact = MediaQuery.sizeOf(context).width < 600;
    if (uri == null) {
      return Container(
        width: compact ? 88 : 220,
        height: compact ? 50 : 124,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.movie_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return SizedBox(
      width: compact ? 88 : 220,
      height: compact ? 50 : 124,
      child: Image.network(
        uri.toString(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
