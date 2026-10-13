import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/ui/pages/home_video_entry.dart';
import 'package:universal_downloader/ui/widgets/home_playlist_video_tile.dart';

void main() {
  testWidgets('selected playlist background stays inside the scrolling list', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final capture = GlobalKey();
    final entries = List.generate(6, (index) => HomeVideoEntry('Video $index'));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            secondaryContainer: Color(0xFF334455),
          ),
        ),
        home: RepaintBoundary(
          key: capture,
          child: Material(
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 100),
                SizedBox(
                  height: 128,
                  child: ListView.builder(
                    controller: scroll,
                    itemCount: entries.length,
                    itemBuilder: (context, index) => HomePlaylistVideoTile(
                      entry: entries[index],
                      index: index + 1,
                      selected: index == 0,
                      onSelect: () {},
                      onSelectionChanged: () {},
                      onRetry: () {},
                      onRemove: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rowHeight = tester
        .getSize(find.byType(HomePlaylistVideoTile).first)
        .height;
    scroll.jumpTo(rowHeight);
    await tester.pumpAndSettle();
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final color = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = ((100 - rowHeight / 2).floor() * image.width + 4) * 4;
      final color = pixels!.buffer.asUint8List(offset, 4).toList();
      image.dispose();
      return color;
    });
    expect(color, [255, 255, 255, 255]);
  });
}
