import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/download_tile.dart';

/// Full download queue with per-task state, progress and actions.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return ListenableBuilder(
      listenable: controller.manager,
      builder: (context, _) {
        final tasks = controller.manager.tasks;

        return AppScaffold(
          selectedIndex: 1,
          body: tasks.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Downloads',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        Text(
                          '${controller.manager.activeCount} active',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (tasks.any((t) => t.state.isTerminal))
                          TextButton.icon(
                            onPressed: () => _clearTerminal(controller),
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text('Clear finished'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final task in tasks) ...[
                      DownloadTile(task: task),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        );
      },
    );
  }

  void _clearTerminal(AppController controller) {
    final terminal = controller.manager.tasks
        .where((t) => t.state.isTerminal)
        .map((t) => t.id)
        .toList();
    for (final id in terminal) {
      controller.manager.remove(id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_for_offline_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('No downloads yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Paste a URL on the Home page to get started.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
