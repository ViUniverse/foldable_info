import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'errors.dart';
import 'flutter_data.dart';
import 'foldable_view.dart';
import 'layout_comparison.dart';
import 'models.dart';
import 'native_session.dart';
import 'replay_feed.dart';
import 'view_metrics.dart';
import 'wire.dart';

class NativeView extends FoldableView with WidgetsBindingObserver {
  NativeView(this.view, this.onRemoved) {
    layout = ReplayFeed(
      initialData(view),
      start: _startLayout,
      stop: _stopLayout,
    );
    angles = ReplayFeed(
      initialAngles(view),
      start: _startAngles,
      stop: _stopAngles,
    );
  }
  final ui.FlutterView view;
  final VoidCallback onRemoved;
  static const _methods = MethodChannel('foldable_info/methods');
  static const _layoutChannel = EventChannel('foldable_info/layout');
  static const _angleChannel = EventChannel('foldable_info/angles');
  bool get _usesNativeBridge =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };
  late final ReplayFeed<FoldableData> layout;
  late final ReplayFeed<FoldAngles> angles;
  StreamSubscription<Object?>? _layoutSub;
  StreamSubscription<Object?>? _angleSub;
  bool _observing = false;
  bool _paused = false;
  bool _removed = false;
  int _layoutSubscriptionId = 0;
  int _angleSubscriptionId = 0;
  Map<Object?, Object?>? _raw;
  final NativeSession _layoutSession = NativeSession();
  final NativeSession _angleSession = NativeSession();
  @override
  int get viewId => view.viewId;
  @override
  Stream<FoldableData> watch() => layout.stream;
  @override
  Stream<FoldAngles> watchAngles() => angles.stream;
  void _observe() {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  void _unobserve() {
    if (_observing && !layout.hasListeners && !angles.hasListeners) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  bool _prepareObservation(void Function(FoldableError) onError) {
    if (_usesNativeBridge && viewId != 0) {
      onError(
        const FoldableError(
          ErrorCode.noView,
          'This native engine supports only its attached view (view 0).',
        ),
      );
      return false;
    }
    _observe();
    return true;
  }

  void _startLayout() {
    if (!_prepareObservation(_failLayout)) return;
    if (!_usesNativeBridge) {
      _publishFallback();
      return;
    }
    final subscriptionId = ++_layoutSubscriptionId;
    _layoutSub = _listenNative(
      _layoutChannel,
      isCurrent: () => subscriptionId == _layoutSubscriptionId,
      onData: _acceptLayout,
      onError: _failLayout,
    );
  }

  void _startAngles() {
    if (!_prepareObservation(_failAngles)) return;
    if (!_usesNativeBridge) {
      angles.add(
        initialAngles(view).copyWith(angles: DataValue.notSupported()),
      );
      return;
    }
    final subscriptionId = ++_angleSubscriptionId;
    _angleSub = _listenNative(
      _angleChannel,
      isCurrent: () => subscriptionId == _angleSubscriptionId,
      onData: _acceptAngles,
      onError: _failAngles,
    );
  }

  StreamSubscription<Object?> _listenNative(
    EventChannel channel, {
    required bool Function() isCurrent,
    required void Function(Map<Object?, Object?>) onData,
    required void Function(FoldableError) onError,
  }) => channel
      .receiveBroadcastStream({'viewId': viewId})
      .listen(
        (event) {
          if (!isCurrent()) return;
          try {
            onData(wireMap(event));
          } catch (error) {
            onError(asFoldError(error));
          }
        },
        onError: (Object error) {
          if (isCurrent()) onError(asFoldError(error));
        },
      );

  void _stopLayout() {
    _layoutSubscriptionId++;
    unawaited(_layoutSub?.cancel());
    _layoutSub = null;
    _unobserve();
  }

  void _stopAngles() {
    _angleSubscriptionId++;
    unawaited(_angleSub?.cancel());
    _angleSub = null;
    _unobserve();
  }

  void _failLayout(FoldableError error) {
    layout.add(errorData(layout.latest, error));
    layout.addError(error);
  }

  void _failAngles(FoldableError error) {
    angles.add(
      angles.latest.copyWith(angles: DataValue.error(error), error: error),
    );
    angles.addError(error);
  }

  void _acceptLayout(Map<Object?, Object?> raw) {
    checkWire(raw, viewId);
    final session = raw['sessionId'] as String;
    final revision = raw['revision'] as int;
    if (!_layoutSession.accept(session, revision)) return;
    _raw = raw;
    final next = decodeData(raw, view, _paused);
    final last = layout.latest;
    // Ignore readAt and native observation counters in layout comparisons.
    final same = sameLayout(last, next);
    final layoutRevision = switch ((last.sessionId == session, same)) {
      (false, _) => 1,
      (true, true) => last.revision,
      (true, false) => last.revision + 1,
    };
    final value = next.copyWith(revision: layoutRevision);
    layout.latest = value;
    if (!same) layout.add(value);
  }

  void _acceptAngles(Map<Object?, Object?> raw) {
    checkWire(raw, viewId);
    final session = raw['sessionId'] as String;
    final sequence = raw['sequence'] as int;
    if (_layoutSession.isRetired(session)) return;
    if (!_angleSession.accept(session, sequence)) return;
    angles.add(decodeAngles(raw, _paused));
  }

  Future<Map<Object?, Object?>> _call(String name, Duration timeout) async {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    try {
      return wireMap(
        await _methods
            .invokeMethod<Object?>(name, {
              'viewId': viewId,
              'timeoutMillis': timeout.inMilliseconds,
            })
            .timeout(timeout),
      );
    } catch (e) {
      throw asFoldError(e);
    }
  }

  @override
  Future<FoldableData> read({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    if (_removed) return layout.latest;
    if (!_usesNativeBridge) {
      _publishFallback();
      return layout.latest;
    }
    if (viewId != 0) {
      throw const FoldableError(
        ErrorCode.noView,
        'Unsupported native view ID.',
      );
    }
    final raw = await _call('read', timeout);
    try {
      _acceptLayout(raw);
      return layout.latest;
    } catch (e) {
      throw asFoldError(e);
    }
  }

  @override
  Future<FoldAngles> readAngles({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    if (_removed) return angles.latest;
    if (!_usesNativeBridge) {
      return initialAngles(view).copyWith(angles: DataValue.notSupported());
    }
    try {
      if (viewId != 0) {
        throw const FoldableError(
          ErrorCode.noView,
          'Unsupported native view ID.',
        );
      }
      _acceptAngles(await _call('readAngles', timeout));
      return angles.latest;
    } catch (e) {
      throw asFoldError(e);
    }
  }

  void _publishFallback() {
    final next = flutterData(view, _paused);
    final last = layout.latest;
    final same = sameLayout(last, next);
    final value = next.copyWith(revision: last.revision + (same ? 0 : 1));
    layout.latest = value;
    if (!same) layout.add(value);
  }

  @override
  void didChangeMetrics() {
    scheduleMicrotask(() {
      if (!WidgetsBinding.instance.platformDispatcher.views.contains(view)) {
        _removed = true;
        layout.add(
          layout.latest.copyWith(
            viewState: ViewState.removed,
            areas: DataValue.notAvailable(),
            folds: DataValue.notAvailable(),
            ios: DataValue.notAvailable(),
          ),
        );
        angles.add(angles.latest.copyWith(angles: DataValue.notAvailable()));
        layout.close();
        angles.close();
        onRemoved();
        return;
      }
      if (_raw != null) {
        _acceptLayout(_raw!);
      } else if (!_usesNativeBridge) {
        _publishFallback();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (_raw != null) {
      _acceptLayout(_raw!);
    } else if (!_usesNativeBridge) {
      _publishFallback();
    }
    if (_paused) {
      angles.add(angles.latest.copyWith(angles: DataValue.notAvailable()));
    }
  }
}
