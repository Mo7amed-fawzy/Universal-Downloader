import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../downloads/download_task.dart';
import 'download_tile.dart';

class DownloadHistoryEntry extends StatelessWidget {
  const DownloadHistoryEntry({
    super.key,
    required this.task,
    required this.highlightAnimation,
    this.highlighted = false,
  });

  final DownloadTask task;
  final Animation<double> highlightAnimation;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tile = DownloadTile(task: task);
    if (!highlighted) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: tile);
    }
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? Colors.amber.shade300
        : const Color(0xFF856000);
    return Semantics(
      selected: true,
      liveRegion: true,
      child: AnimatedBuilder(
        animation: highlightAnimation,
        child: tile,
        builder: (context, child) {
          final value = highlightAnimation.value;
          final reveal = (value * 4).clamp(0.0, 1.0);
          final pulse = math.sin(value * math.pi * 4).abs() * (1 - value);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Opacity(
                  opacity: reveal,
                  child: Transform.translate(
                    offset: Offset(0, -6 * (1 - reveal)),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Downloaded before',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: pulse * 0.3),
                        blurRadius: 16 * pulse,
                        spreadRadius: 3 * pulse,
                      ),
                    ],
                  ),
                  child: child,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
