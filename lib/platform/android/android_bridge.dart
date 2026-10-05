import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/process/cancel_token.dart';

class AndroidBridge {
  AndroidBridge({MethodChannel? channel})
    : channel = channel ?? const MethodChannel('universal_downloader/android') {
    this.channel.setMethodCallHandler(_handleEvent);
  }

  final MethodChannel channel;
  final _listeners = <String, void Function(String, bool)>{};
  int _sequence = 0;

  Future<void> _handleEvent(MethodCall call) async {
    if (call.method != 'line') return;
    final event = call.arguments;
    if (event is! Map) return;
    final id = event['id'];
    final line = event['line'];
    final stdout = event['stdout'];
    if (id is String && line is String && stdout is bool) {
      _listeners[id]?.call(line, stdout);
    }
  }

  Future<Map<Object?, Object?>> initialize() async {
    final result = await channel.invokeMapMethod<Object?, Object?>(
      'initialize',
    );
    if (result == null) throw StateError('Android runtime returned no paths.');
    return result;
  }

  Future<T?> execute<T>(
    String method,
    Map<String, Object?> arguments, {
    CancelToken? cancelToken,
    void Function(String, bool)? onLine,
  }) async {
    cancelToken?.throwIfCancelled();
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    if (onLine != null) _listeners[id] = onLine;
    StreamSubscription<void>? cancellation;
    try {
      final operation = channel.invokeMethod<T>(method, {
        ...arguments,
        'id': id,
      });
      cancellation = cancelToken?.whenCancelled.asStream().listen((_) {
        unawaited(
          channel
              .invokeMethod<void>('cancel', {'id': id})
              .catchError((Object _) {}),
        );
      });
      return await operation;
    } on PlatformException {
      cancelToken?.throwIfCancelled();
      rethrow;
    } finally {
      await cancellation?.cancel();
      _listeners.remove(id);
    }
  }

  Future<void> open(String location) =>
      channel.invokeMethod<void>('open', {'uri': location});
}
