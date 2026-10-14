import 'package:flutter/material.dart';

class DownloadAudioTitle extends StatelessWidget {
  const DownloadAudioTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExcludeSemantics(
            child: Icon(Icons.graphic_eq_rounded, size: 20, color: accent),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
