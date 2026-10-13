import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_wordmark.dart';
import 'catchit_bird.dart';

class CatchItFlightScene extends StatelessWidget {
  const CatchItFlightScene({super.key, required this.progress});

  final double progress;

  double _phase(
    double start,
    double end, [
    Curve curve = Curves.easeInOutCubic,
  ]) => curve.transform(((progress - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'CatchIt',
    image: true,
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = (width / 600).clamp(0.65, 1.0);
          final birdSize = 88 * scale;
          final fontSize = 42 * scale;
          final text = TextPainter(
            text: TextSpan(
              text: 'CatchIt',
              style: AppWordmark.styleOf(context, fontSize: fontSize),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final wordWidth = text.width + 4;
          text.dispose();
          final gap = 8 * scale;
          final logoWidth = birdSize + gap + wordWidth;
          final restingX = (width - logoWidth) / 2;
          final left = math.max(16.0, width * 0.14 - birdSize / 2);
          final right = math.min(width * 0.78, width - birdSize - 24);
          final outbound = _phase(0.04, 0.36);
          final returning = _phase(0.46, 0.79);
          final landing = _phase(0.77, 0.88);
          final x = progress < 0.46
              ? left + (right - left) * outbound
              : right + (restingX - right) * returning;
          final flight = (1 - _phase(0.76, 0.88)) * _phase(0, 0.07);
          final flap = (math.sin(progress * math.pi * 34) + 1) * flight;
          final y = constraints.maxHeight / 2 - birdSize / 2;
          final bob = math.sin(progress * math.pi * 17) * 3 * scale * flight;
          final turn = math.pi * _phase(0.36, 0.46) + math.pi * landing;
          final reveal = _phase(0.46, 0.65, Curves.easeOutCubic);
          final wordX = x + birdSize + gap + (1 - reveal) * 36 * scale;
          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: wordX,
                  top: y,
                  width: wordWidth,
                  height: birdSize,
                  child: Opacity(
                    opacity: reveal,
                    child: Transform.rotate(
                      angle: (1 - landing) * -0.045 * reveal,
                      alignment: Alignment.centerLeft,
                      child: MediaQuery.withNoTextScaling(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppWordmark(fontSize: fontSize),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: x,
                  top: y + bob - math.sin(outbound * math.pi) * 16 * scale,
                  width: birdSize,
                  height: birdSize,
                  child: Opacity(
                    opacity: _phase(0, 0.05),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(turn)
                        ..rotateZ(
                          math.sin(progress * math.pi * 4) * 0.06 * flight,
                        ),
                      child: CatchItBird(wingAngle: flap),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
