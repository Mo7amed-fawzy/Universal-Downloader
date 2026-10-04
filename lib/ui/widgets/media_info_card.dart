import 'package:flutter/material.dart';

import '../../core/models/media_info.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/language_names.dart';
import '../components/status_chip.dart';

/// Shows fetched media metadata: thumbnail, title, uploader, duration and the
/// list of available audio languages.
class MediaInfoCard extends StatelessWidget {
  const MediaInfoCard({super.key, required this.info});

  final MediaInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = info.audioLanguages
        .map((l) => LanguageNames.nameFor(l))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
                      if (info.uploader != null && info.uploader!.isNotEmpty)
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
          ],
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
    if (uri == null) {
      return Container(
        width: 220,
        height: 124,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.movie_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return SizedBox(
      width: 220,
      height: 124,
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
