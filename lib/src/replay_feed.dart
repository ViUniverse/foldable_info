import 'dart:async';

/// A shared replay stream. Each subscriber owns only its own cancellation.
class ReplayFeed<T> {
  ReplayFeed(this.latest, {required this.start, required this.stop});
  T latest;
  final void Function() start;
  final void Function() stop;
  final Set<MultiStreamController<T>> _listeners = {};
  bool _closed = false;
  late final Stream<T> stream = Stream<T>.multi((sink) {
    sink.add(latest);
    if (_closed) {
      sink.close();
      return;
    }
    final first = _listeners.isEmpty;
    _listeners.add(sink);
    sink.onCancel = () {
      _listeners.remove(sink);
      if (_listeners.isEmpty) stop();
    };
    if (first) start();
  }, isBroadcast: true);
  bool get hasListeners => _listeners.isNotEmpty;
  void add(T value) {
    latest = value;
    for (final sink in _listeners.toList()) {
      sink.add(value);
    }
  }

  void addError(Object error) {
    for (final sink in _listeners.toList()) {
      sink.addError(error);
    }
  }

  void close() {
    _closed = true;
    for (final sink in _listeners.toList()) {
      sink.close();
    }
    _listeners.clear();
    stop();
  }
}
