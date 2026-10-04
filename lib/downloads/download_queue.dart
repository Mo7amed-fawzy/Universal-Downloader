import 'download_task.dart';
import 'download_task_state.dart';

/// Ordered collection of download tasks with a concurrency limit.
///
/// The queue itself has no process knowledge; the [DownloadManager] pulls
/// tasks from it and runs their pipelines.
class DownloadQueue {
  DownloadQueue({this.maxConcurrent = 2});

  final int maxConcurrent;
  final List<DownloadTask> _tasks = [];

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  void add(DownloadTask task) => _tasks.add(task);

  bool remove(String id) {
    final before = _tasks.length;
    _tasks.removeWhere((t) => t.id == id);
    return _tasks.length != before;
  }

  DownloadTask? byId(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Tasks waiting to be started, in insertion order.
  List<DownloadTask> get pending =>
      _tasks.where((t) => t.state == DownloadTaskState.queued).toList();

  /// Tasks currently being processed (all non-terminal, non-waiting states).
  List<DownloadTask> get running => _tasks
      .where((t) => t.state.isActive && t.state != DownloadTaskState.queued)
      .toList();

  int get activeCount => running.length;
}
