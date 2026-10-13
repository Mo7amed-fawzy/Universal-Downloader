import 'package:flutter/material.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/catchit-icon.png',
          width: 44,
          height: 44,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'CatchIt',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.8,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
