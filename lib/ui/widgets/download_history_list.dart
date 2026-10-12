import 'dart:async';

import 'package:flutter/material.dart';

import '../../downloads/download_task.dart';
import 'download_history_entry.dart';
import 'download_history_scroll_controller.dart';

class DownloadHistoryList extends StatefulWidget {
  const DownloadHistoryList({
    super.key,
    required this.tasks,
    this.initialTaskId,
  });

  final List<DownloadTask> tasks;
  final String? initialTaskId;

  @override
  State<DownloadHistoryList> createState() => _DownloadHistoryListState();
}

class _DownloadHistoryListState extends State<DownloadHistoryList>
    with SingleTickerProviderStateMixin {
  final _targetSliverKey = GlobalKey();
  late final _scrollController = DownloadHistoryScrollController(
    trailingSliverKey: _targetSliverKey,
  );
  late final _highlight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Animation<double>? _routeAnimation;
  Timer? _highlightTimer;
  bool _highlightStarted = false;
  bool _highlightVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = ModalRoute.of(context)?.animation;
    _routeAnimation?.addStatusListener(_onRouteStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (_routeAnimation == null || _routeAnimation!.isCompleted)) {
        _showHighlight();
      }
    });
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _showHighlight();
  }

  void _showHighlight() {
    if (_highlightStarted || widget.initialTaskId == null) return;
    _highlightStarted = true;
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightVisible = false);
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _highlight.value = 1;
    } else {
      _highlight.forward();
    }
  }

  @override
  void didUpdateWidget(covariant DownloadHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTaskId != widget.initialTaskId) {
      _highlightTimer?.cancel();
      _highlightStarted = false;
      _highlightVisible = true;
      _highlight.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
        _showHighlight();
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _highlight.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetIndex = widget.tasks.indexWhere(
      (task) => task.id == widget.initialTaskId,
    );
    final split = targetIndex < 0 ? 0 : targetIndex;
    return CustomScrollView(
      controller: _scrollController,
      center: _targetSliverKey,
      semanticChildCount: widget.tasks.length,
      slivers: [
        if (split > 0)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList.builder(
              itemCount: split,
              itemBuilder: (context, index) {
                final taskIndex = split - index - 1;
                final task = widget.tasks[taskIndex];
                return IndexedSemantics(
                  index: taskIndex,
                  child: DownloadHistoryEntry(
                    key: ValueKey(task.id),
                    task: task,
                    highlightAnimation: _highlight,
                  ),
                );
              },
              addSemanticIndexes: false,
            ),
          ),
        SliverPadding(
          key: _targetSliverKey,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          sliver: SliverList.builder(
            itemCount: widget.tasks.length - split,
            itemBuilder: (context, index) {
              final taskIndex = split + index;
              final task = widget.tasks[taskIndex];
              return IndexedSemantics(
                index: taskIndex,
                child: DownloadHistoryEntry(
                  key: ValueKey(task.id),
                  task: task,
                  highlighted:
                      _highlightVisible && task.id == widget.initialTaskId,
                  highlightAnimation: _highlight,
                ),
              );
            },
            addSemanticIndexes: false,
          ),
        ),
      ],
    );
  }
}
