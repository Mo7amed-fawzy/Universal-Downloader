import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:universal_downloader/ui/components/status_chip.dart';

void main() {
  testWidgets('StatusChip renders label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(
            label: 'YouTube',
            icon: Icons.language,
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.text('YouTube'), findsOneWidget);
  });
}
