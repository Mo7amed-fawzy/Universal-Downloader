import 'package:flutter/material.dart';

import '../../core/services/dependency_checker.dart';

class ToolDiagnosticRow extends StatelessWidget {
  const ToolDiagnosticRow({super.key, required this.status});

  final DependencyStatus status;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        status.installed ? Icons.check_circle : Icons.error_outline,
        color: status.installed
            ? Colors.green
            : Theme.of(context).colorScheme.error,
      ),
      title: Text('${status.name} · ${status.version ?? 'unavailable'}'),
      subtitle: Text(
        status.path ?? status.installInstructions ?? 'Unavailable',
      ),
    );
  }
}
