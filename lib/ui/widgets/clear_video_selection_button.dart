import 'package:flutter/material.dart';

class ClearVideoSelectionButton extends StatelessWidget {
  const ClearVideoSelectionButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message:
          'Close these settings. The video and your choices stay in the list.',
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurfaceVariant,
          minimumSize: const Size(48, 48),
        ),
        icon: Icon(Icons.close_rounded, color: colors.error, size: 20),
        label: const Text('Clear selection'),
      ),
    );
  }
}
