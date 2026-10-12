import 'package:flutter/material.dart';

import '../pages/home_video_draft.dart';

class HomeVideoCard extends StatelessWidget {
  const HomeVideoCard({
    super.key,
    required this.draft,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
  });

  final HomeVideoDraft draft;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = draft.info.thumbnail;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: draft.info.title,
                    child: Text(
                      draft.info.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${draft.info.title}',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Semantics(
            selected: selected,
            label: draft.info.title,
            child: InkWell(
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExcludeSemantics(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: thumbnail == null
                              ? const Icon(Icons.movie_outlined, size: 36)
                              : Image.network(
                                  thumbnail.toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.movie_outlined,
                                        size: 36,
                                      ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${draft.qualityLabel} · ${draft.isCustom ? 'Custom' : 'Auto'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selected ? 'Selected' : 'View settings',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Icon(
                          selected ? Icons.check_circle_outline : Icons.tune,
                        ),
                      ],
                    ),
                    if (draft.errorMessage != null)
                      Text(
                        draft.errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
