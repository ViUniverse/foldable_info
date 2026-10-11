/// Test doubles. Import separately from the production entrypoint.
library;

import 'dart:ui' as ui;
import 'src/models.dart';
import 'src/errors.dart';
import 'src/replay_feed.dart';
import 'src/service.dart';

/// Injected measurement service with explicit per-view fixtures.
///
/// Use increasing counters in each session and dispose after the test. It does
/// not replace the default static FoldableInfo service.
class FakeFoldableInfo extends FoldableInfo {
  /// Creates fixtures; angle fixtures must refer to a declared view.
  FakeFoldableInfo({
    required Map<int, FoldableData> views,
    Map<int, FoldAngles> angles = const {},
  }) {
    for (final entry in views.entries) {
      if (entry.key != entry.value.viewId ||
          (angles[entry.key] != null &&
              angles[entry.key]!.viewId != entry.key)) {
        throw ArgumentError('Fixture view ID mismatch.');
      }
      _views[entry.key] = _FakeView(
        entry.value,
        angles[entry.key] ??
            FoldAngles(
              viewId: entry.key,
              sessionId: entry.value.sessionId,
              sequence: 0,
              angles: DataValue.loading(),
            ),
      );
    }
    if (angles.keys.any((id) => !views.containsKey(id))) {
      throw ArgumentError('Angle fixture has no declared view.');
    }
  }
  final Map<int, _FakeView> _views = {};
  bool _disposed = false;
  _FakeView _get(int id) {
    if (_disposed) throw StateError('FakeFoldableInfo is disposed.');
    return _views[id] ??
        (throw const FoldableError(
          ErrorCode.noView,
          'No fixture for this view.',
        ));
  }

  @override
  FoldableView forView(ui.FlutterView view) => _get(view.viewId);

  /// Publishes newer layout data or starts a new session.
  void sendData(FoldableData data) => _get(data.viewId).sendData(data);

  /// Publishes newer angle data or starts a new session.
  void sendAngles(FoldAngles sample) => _get(sample.viewId).sendAngles(sample);

  /// Invalidates affected data and emits a stream error.
  void sendError({
    required int viewId,
    required FoldableError error,
    bool angles = false,
  }) {
    final view = _get(viewId);
    if (angles) {
      view.angles.add(
        view.angles.latest.copyWith(
          sequence: view.angles.latest.sequence + 1,
          angles: DataValue.error(error),
          error: error,
        ),
      );
      view.angles.addError(error);
    } else {
      view.layout.add(errorData(view.layout.latest, error));
      view.layout.addError(error);
    }
  }

  /// Closes all fake streams. Calling this again is safe.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final view in _views.values) {
      view.layout.close();
      view.angles.close();
    }
    _views.clear();
  }
}

class _FakeView extends FoldableView {
  _FakeView(FoldableData data, FoldAngles sample)
    : layout = ReplayFeed(data, start: () {}, stop: () {}),
      angles = ReplayFeed(sample, start: () {}, stop: () {});
  final ReplayFeed<FoldableData> layout;
  final ReplayFeed<FoldAngles> angles;
  final Set<String> oldLayout = {}, oldAngles = {};
  @override
  int get viewId => layout.latest.viewId;
  @override
  Stream<FoldableData> watch() => layout.stream;
  @override
  Stream<FoldAngles> watchAngles() => angles.stream;
  @override
  Future<FoldableData> read({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    if (layout.latest.error case final error?) throw error;
    return layout.latest;
  }

  @override
  Future<FoldAngles> readAngles({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    if (angles.latest.error case final error?) throw error;
    return angles.latest;
  }

  void sendData(FoldableData data) {
    final last = layout.latest;
    if (oldLayout.contains(data.sessionId) ||
        (last.sessionId == data.sessionId && data.revision <= last.revision)) {
      throw ArgumentError('Layout counter must advance within its session.');
    }
    if (last.sessionId != data.sessionId) oldLayout.add(last.sessionId);
    layout.add(data);
  }

  void sendAngles(FoldAngles sample) {
    final last = angles.latest;
    if (oldAngles.contains(sample.sessionId) ||
        (last.sessionId == sample.sessionId &&
            sample.sequence <= last.sequence)) {
      throw ArgumentError('Angle counter must advance within its session.');
    }
    if (last.sessionId != sample.sessionId) oldAngles.add(last.sessionId);
    angles.add(sample);
  }
}
