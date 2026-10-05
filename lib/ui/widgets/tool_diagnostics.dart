import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import 'tool_diagnostic_row.dart';

class ToolDiagnostics extends StatelessWidget {
  const ToolDiagnostics({
    super.key,
    required this.controller,
    this.onRestoreIncluded,
  });

  final AppController controller;
  final VoidCallback? onRestoreIncluded;

  @override
  Widget build(BuildContext context) {
    final busy = controller.updatingTools || controller.checkingDependencies;
    return ExpansionTile(
      title: const Text('Diagnostics'),
      children: [
        const Text(
          'Media tools are included with the app. Updates are verified before installation.',
        ),
        for (final status in controller.dependencies)
          ToolDiagnosticRow(status: status),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : controller.refreshDependencies,
              icon: const Icon(Icons.refresh),
              label: const Text('Check tools'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : () => controller.updateTools(),
              icon: const Icon(Icons.system_update_alt),
              label: Text(
                controller.updatingTools ? 'Updating…' : 'Update tools',
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : onRestoreIncluded ??
                        () => controller.updateTools(restoreIncluded: true),
              child: const Text('Use included tools'),
            ),
          ],
        ),
        if (controller.updatingTools)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        if (controller.toolUpdateMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(controller.toolUpdateMessage!),
          ),
      ],
    );
  }
}
