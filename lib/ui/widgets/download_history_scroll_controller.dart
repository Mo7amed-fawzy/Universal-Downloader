import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class DownloadHistoryScrollController extends ScrollController {
  DownloadHistoryScrollController({required this.trailingSliverKey})
    : super(keepScrollOffset: false);

  final GlobalKey trailingSliverKey;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _DownloadHistoryScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    trailingSliverKey: trailingSliverKey,
  );
}

class _DownloadHistoryScrollPosition extends ScrollPositionWithSingleContext {
  _DownloadHistoryScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.trailingSliverKey,
  }) : super(keepScrollOffset: false);

  final GlobalKey trailingSliverKey;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final sliver = trailingSliverKey.currentContext?.findRenderObject();
    if (sliver is RenderSliver && sliver.geometry != null) {
      maxScrollExtent = math.max(
        minScrollExtent,
        sliver.geometry!.scrollExtent - viewportDimension,
      );
      if (!hasContentDimensions ||
          minScrollExtent != this.minScrollExtent ||
          maxScrollExtent != this.maxScrollExtent) {
        final corrected = pixels.clamp(minScrollExtent, maxScrollExtent);
        if (corrected != pixels) {
          correctPixels(corrected);
          return false;
        }
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
