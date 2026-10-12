import 'package:flutter/material.dart';

class DownloadedVideoWarning extends StatelessWidget {
  const DownloadedVideoWarning({
    super.key,
    required this.videoCount,
    required this.onViewDownloads,
  });

  final int videoCount;
  final VoidCallback? onViewDownloads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? Colors.amber.shade300
        : const Color(0xFF856000);
    final message = videoCount == 1
        ? 'Already downloaded'
        : '$videoCount videos already downloaded';
    return Semantics(
      liveRegion: true,
      child: Tooltip(
        message: onViewDownloads == null
            ? message
            : '$message — View in Downloads',
        child: InkWell(
          onTap: onViewDownloads,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
