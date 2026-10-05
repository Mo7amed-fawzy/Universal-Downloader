import 'package:flutter/material.dart';

class AdvancedSettingsSection extends StatelessWidget {
  const AdvancedSettingsSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Advanced'),
        childrenPadding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}
