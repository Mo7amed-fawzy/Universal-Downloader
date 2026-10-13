import 'package:flutter/material.dart';

class HomeIntro extends StatelessWidget {
  const HomeIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Catch it. Keep it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your favorite videos, ready to go.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
