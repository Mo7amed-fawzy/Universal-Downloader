import 'package:flutter/material.dart';

import 'catchit_flight_scene.dart';

class CatchItLaunchAnimation extends StatefulWidget {
  const CatchItLaunchAnimation({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<CatchItLaunchAnimation> createState() => _CatchItLaunchAnimationState();
}

class _CatchItLaunchAnimationState extends State<CatchItLaunchAnimation>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..addStatusListener(_onStatus);
  bool _started = false;
  bool _reportedComplete = false;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _reportedComplete) return;
    _reportedComplete = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      precacheImage(
        const AssetImage('assets/branding/catchit-icon.png'),
        context,
      ).then((_) {
        if (mounted && !_reportedComplete) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CatchItFlightScene(progress: _controller.value),
    ),
  );
}
