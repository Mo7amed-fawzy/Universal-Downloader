import 'package:flutter/material.dart';

class HomeContentLayout extends StatelessWidget {
  const HomeContentLayout({
    super.key,
    required this.centerVertically,
    required this.child,
  });

  final bool centerVertically;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const padding = EdgeInsets.all(24);
      final minimumHeight = centerVertically && constraints.hasBoundedHeight
          ? (constraints.maxHeight - padding.vertical).clamp(
              0.0,
              double.infinity,
            )
          : 0.0;
      return SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minimumHeight),
          child: Align(
            alignment: centerVertically
                ? const Alignment(0, -0.18)
                : Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
