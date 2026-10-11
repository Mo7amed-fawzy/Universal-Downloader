import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/ui/widgets/link_cache_settings_card.dart';

void main() {
  testWidgets(
    'clear action has a label, disables during work and reports completion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var clears = 0;
      var clearing = false;
      String? message;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return LinkCacheSettingsCard(
                  clearing: clearing,
                  message: message,
                  onClear: () => setState(() {
                    clears++;
                    clearing = true;
                  }),
                );
              },
            ),
          ),
        ),
      );
      expect(
        find.textContaining('downloaded files and history'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear link cache'));
      await tester.pump();
      expect(clears, 1);
      expect(find.byTooltip('Clear link cache'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      rebuild(() {
        clearing = false;
        message = 'Link cache cleared.';
      });
      await tester.pumpAndSettle();
      expect(find.text('Link cache cleared.'), findsOneWidget);
      expect(find.byTooltip('Clear link cache'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
