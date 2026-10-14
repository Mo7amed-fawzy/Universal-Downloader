import 'package:flutter/material.dart';

import '../pages/home_video_draft.dart';
import '../pages/home_video_entry.dart';
import 'home_video_fetch_card.dart';
import 'home_video_card.dart';
import 'home_download_selection.dart';
import 'output_folder_row.dart';

class HomeVideoList extends StatefulWidget {
  const HomeVideoList({
    super.key,
    required this.entries,
    required this.outputDirectory,
    required this.onOutputDirectoryChanged,
    required this.onVideoDirectoryChanged,
    required this.onSelectionChanged,
    required this.onRetry,
    required this.selected,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onSelect,
    required this.onRemove,
  });

  final List<HomeVideoEntry> entries;
  final String outputDirectory;
  final ValueChanged<String> onOutputDirectoryChanged;
  final void Function(HomeVideoDraft, String) onVideoDirectoryChanged;
  final VoidCallback onSelectionChanged;
  final ValueChanged<HomeVideoEntry> onRetry;
  final HomeVideoDraft? selected;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<HomeVideoDraft> onSelect;
  final ValueChanged<HomeVideoEntry> onRemove;

  @override
  State<HomeVideoList> createState() => _HomeVideoListState();
}

class _HomeVideoListState extends State<HomeVideoList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              'Your videos (${widget.entries.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton.icon(
              onPressed: widget.onToggleCollapsed,
              icon: Icon(
                widget.collapsed ? Icons.expand_more : Icons.expand_less,
              ),
              label: Text(widget.collapsed ? 'Expand' : 'Collapse'),
            ),
          ],
        ),
        HomeDownloadSelection(
          entries: widget.entries,
          onChanged: widget.onSelectionChanged,
        ),
        if (!widget.collapsed) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.clamp(0.0, 220.0);
              return Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < widget.entries.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(width: 12),
                          SizedBox(
                            width: width,
                            child: widget.entries[index].draft != null
                                ? HomeVideoCard(
                                    key: ValueKey(
                                      widget.entries[index].draft!.id,
                                    ),
                                    entry: widget.entries[index],
                                    onOutputDirectoryChanged: (directory) =>
                                        widget.onVideoDirectoryChanged(
                                          widget.entries[index].draft!,
                                          directory,
                                        ),
                                    onSelectionChanged:
                                        widget.onSelectionChanged,
                                    selected:
                                        widget.selected ==
                                        widget.entries[index].draft,
                                    onSelect: () => widget.onSelect(
                                      widget.entries[index].draft!,
                                    ),
                                    onRemove: () =>
                                        widget.onRemove(widget.entries[index]),
                                  )
                                : HomeVideoFetchCard(
                                    key: ObjectKey(widget.entries[index]),
                                    entry: widget.entries[index],
                                    onSelectionChanged:
                                        widget.onSelectionChanged,
                                    onRemove: () =>
                                        widget.onRemove(widget.entries[index]),
                                    onRetry: () =>
                                        widget.onRetry(widget.entries[index]),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        OutputFolderRow(
          directory: widget.outputDirectory,
          label: 'Folder for all videos',
          onChanged: widget.onOutputDirectoryChanged,
        ),
      ],
    );
  }
}
