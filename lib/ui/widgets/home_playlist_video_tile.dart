import 'package:flutter/material.dart';

import '../pages/home_video_entry.dart';
import 'home_download_checkbox.dart';
import 'home_video_thumbnail.dart';

class HomePlaylistVideoTile extends StatelessWidget {
  const HomePlaylistVideoTile({
    super.key,
    required this.entry,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onSelectionChanged,
    required this.onRetry,
    required this.onRemove,
  });

  final HomeVideoEntry entry;
  final int index;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onSelectionChanged;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final draft = entry.draft;
    final error = entry.errorMessage ?? draft?.errorMessage;
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        selectedColor: Theme.of(context).colorScheme.onPrimaryContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: HomeVideoThumbnail(url: draft?.info.thumbnail),
        title: Text(
          '$index. ${draft?.info.title ?? entry.link}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          error ??
              (draft != null
                  ? '${draft.qualityLabel} · ${selected ? 'Editing settings' : 'View settings'}'
                  : entry.fetching
                  ? 'Fetching video information…'
                  : 'Waiting for video information…'),
          style: error == null
              ? null
              : TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        onTap: draft == null ? null : onSelect,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.fetching)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (entry.errorMessage != null)
              IconButton(
                tooltip: 'Retry video',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
              ),
            HomeDownloadCheckbox(entry: entry, onChanged: onSelectionChanged),
            IconButton(
              tooltip: 'Remove video from playlist',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
