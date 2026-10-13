import 'package:flutter/material.dart';

import '../pages/home_playlist_entry.dart';
import '../pages/home_video_draft.dart';
import '../pages/home_video_entry.dart';
import 'home_playlist_video_tile.dart';
import 'home_download_selection.dart';
import 'output_folder_row.dart';

class HomePlaylistCard extends StatelessWidget {
  const HomePlaylistCard({
    super.key,
    required this.playlist,
    required this.entries,
    required this.selected,
    required this.onSelect,
    required this.onSelectionChanged,
    required this.onRetryVideo,
    required this.onRemoveVideo,
    required this.onRetry,
    required this.onRemove,
    required this.onToggleCollapsed,
    required this.onDownload,
    required this.outputDirectory,
    required this.onOutputDirectoryChanged,
  });

  final VoidCallback onSelectionChanged;
  final HomePlaylistEntry playlist;
  final List<HomeVideoEntry> entries;
  final HomeVideoDraft? selected;
  final ValueChanged<HomeVideoDraft> onSelect;
  final ValueChanged<HomeVideoEntry> onRetryVideo;
  final ValueChanged<HomeVideoEntry> onRemoveVideo;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onDownload;
  final String outputDirectory;
  final ValueChanged<String> onOutputDirectoryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = entries.where((entry) => entry.draft != null).length;
    final selectedReady = entries
        .where((entry) => entry.draft != null && entry.selectedForDownload)
        .length;
    final failed = entries
        .where(
          (entry) =>
              entry.errorMessage != null || entry.draft?.errorMessage != null,
        )
        .length;
    final preparing = entries.any((entry) => entry.waiting || entry.fetching);
    final prepared = entries
        .where((entry) => entry.draft != null || entry.errorMessage != null)
        .length;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.playlist_play,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUTUBE PLAYLIST',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        playlist.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove playlist',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                playlist.fetching
                    ? 'Reading the complete playlist…'
                    : '${entries.length} videos · $ready ready${failed > 0 ? ' · $failed need attention' : ''}'
                          '${playlist.queuedCount > 0 ? ' · ${playlist.queuedCount} queued' : ''}',
              ),
            ),
            if (playlist.fetching || preparing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: playlist.fetching || entries.isEmpty
                    ? null
                    : prepared / entries.length,
              ),
            ],
            if (playlist.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                playlist.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry playlist'),
                ),
              ),
            ],
            if (playlist.unavailableCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${playlist.unavailableCount} unavailable entries could not be added.',
                ),
              ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              HomeDownloadSelection(
                entries: entries,
                onChanged: onSelectionChanged,
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onToggleCollapsed,
                    icon: Icon(
                      playlist.collapsed
                          ? Icons.expand_more
                          : Icons.expand_less,
                    ),
                    label: Text(
                      playlist.collapsed ? 'Show videos' : 'Hide videos',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: preparing || selectedReady == 0
                        ? null
                        : onDownload,
                    icon: const Icon(Icons.download),
                    label: Text('Download playlist ($selectedReady)'),
                  ),
                ],
              ),
              if (!playlist.collapsed) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: entries.length < 3 ? entries.length * 128.0 : 320,
                  child: ListView.builder(
                    primary: false,
                    itemCount: entries.length,
                    itemBuilder: (context, index) => HomePlaylistVideoTile(
                      key: ObjectKey(entries[index]),
                      entry: entries[index],
                      index: index + 1,
                      selected:
                          selected != null && selected == entries[index].draft,
                      onSelect: () => onSelect(entries[index].draft!),
                      onSelectionChanged: onSelectionChanged,
                      onRetry: () => onRetryVideo(entries[index]),
                      onRemove: () => onRemoveVideo(entries[index]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Check the videos to download. Click a video to change quality, audio, subtitles or save location. Each video downloads as a separate file.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutputFolderRow(
              label: 'Playlist folder',
              directory: outputDirectory,
              onChanged: onOutputDirectoryChanged,
            ),
          ],
        ),
      ),
    );
  }
}
