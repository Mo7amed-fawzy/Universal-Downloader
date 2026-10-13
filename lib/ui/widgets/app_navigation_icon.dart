import 'package:flutter/material.dart';

class AppNavigationIcon extends StatelessWidget {
  const AppNavigationIcon({
    super.key,
    required this.icon,
    required this.indicatorScale,
  });

  final IconData icon;
  final double indicatorScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigationTheme = NavigationBarTheme.of(context);
    final colors = theme.colorScheme;
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            width: 64,
            height: 32,
            child: Transform.scale(
              scale: indicatorScale,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color:
                      navigationTheme.indicatorColor ??
                      colors.secondaryContainer,
                  shape:
                      navigationTheme.indicatorShape ?? const StadiumBorder(),
                ),
              ),
            ),
          ),
          Icon(
            icon,
            color: Color.lerp(
              colors.onSurfaceVariant,
              colors.onSecondaryContainer,
              indicatorScale,
            ),
          ),
        ],
      ),
    );
  }
}
