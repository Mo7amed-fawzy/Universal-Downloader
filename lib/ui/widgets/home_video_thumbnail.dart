import 'package:flutter/material.dart';

class HomeVideoThumbnail extends StatelessWidget {
  const HomeVideoThumbnail({super.key, required this.url});

  final Uri? url;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 80,
          height: 45,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: url == null
                ? const Icon(Icons.movie_outlined)
                : Image.network(
                    url.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.movie_outlined),
                  ),
          ),
        ),
      ),
    );
  }
}
