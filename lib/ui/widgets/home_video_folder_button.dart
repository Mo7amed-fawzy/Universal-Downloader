import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class HomeVideoFolderButton extends StatelessWidget {
  const HomeVideoFolderButton({
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
    if (!context.mounted || selected == null || selected.isEmpty) return;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: directory.isEmpty ? 'Choose save folder' : directory,
      child: TextButton(
        onPressed: () => _pick(context),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Save folder'),
                  Text(
                    directory.isEmpty ? 'Not selected' : directory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
