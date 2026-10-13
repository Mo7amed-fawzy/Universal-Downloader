import 'package:flutter/material.dart';

class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.fontSize});

  final double? fontSize;

  static TextStyle styleOf(BuildContext context, {double? fontSize}) {
    final theme = Theme.of(context);
    return theme.textTheme.titleLarge!.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.8,
      color: theme.brightness == Brightness.dark
          ? theme.colorScheme.onSurface
          : theme.colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) => Text(
    'CatchIt',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: styleOf(context, fontSize: fontSize),
  );
}
