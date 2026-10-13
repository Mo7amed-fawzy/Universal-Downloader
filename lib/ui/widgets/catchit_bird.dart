import 'package:flutter/material.dart';

class CatchItBird extends StatelessWidget {
  const CatchItBird({super.key, this.wingAngle = 0});

  final double wingAngle;

  @override
  Widget build(BuildContext context) {
    final bird = Image.asset(
      'assets/branding/catchit-icon.png',
      excludeFromSemantics: true,
      filterQuality: FilterQuality.high,
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        ClipPath(clipper: const _BirdClipper(wing: false), child: bird),
        Transform(
          alignment: const Alignment(0.22, 0.32),
          transform: Matrix4.identity()..rotateX(wingAngle),
          child: ClipPath(clipper: const _BirdClipper(wing: true), child: bird),
        ),
      ],
    );
  }
}

class _BirdClipper extends CustomClipper<Path> {
  const _BirdClipper({required this.wing});

  final bool wing;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.64)
      ..lineTo(size.width * 0.613, size.height * 0.664)
      ..lineTo(size.width * 0.20, size.height * 0.388)
      ..lineTo(0, size.height * 0.25)
      ..close();
    if (!wing) {
      path
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size);
    }
    return path;
  }

  @override
  bool shouldReclip(_BirdClipper oldClipper) => oldClipper.wing != wing;
}
