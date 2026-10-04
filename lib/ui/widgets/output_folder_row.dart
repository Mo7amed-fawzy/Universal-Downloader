import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

/// Output directory picker with a native Linux directory dialog.
class OutputFolderRow extends StatelessWidget {
  const OutputFolderRow({
    super.key,
    required this.directory,
    required this.onChanged,
  });

  final String directory;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final selected = await getDirectoryPath(
      initialDirectory: directory.isEmpty ? null : directory,
    );
    if (selected != null && selected.isNotEmpty) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Output Folder', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    directory.isEmpty ? 'Not selected' : directory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _pick(context),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }
}
