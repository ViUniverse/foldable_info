/// Rejects out-of-order snapshots and callbacks from a retired observation.
class NativeSession {
  String? _current;
  int _counter = -1;
  final Set<String> _retired = {};

  bool isRetired(String session) => _retired.contains(session);

  bool accept(String session, int counter) {
    if (isRetired(session)) return false;
    if (session == _current && counter < _counter) return false;

    if (_current case final previous? when previous != session) {
      _retired.add(previous);
    }
    _current = session;
    _counter = counter;
    return true;
  }
}
