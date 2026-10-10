import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'models.dart';
import 'wire.dart';

/// Reads fold/view measurements without owning application layout or state.
///
/// Static calls use the engine's implicit view. Use [forView] for an explicit
/// view or an injected test service. No BuildContext or provider is required.
abstract class FoldableInfo {
  /// The measurement service for this Flutter engine.
  static final FoldableInfo instance = _NativeInfo();

  /// Reads the engine's implicit view. No provider or context is needed.
  static Future<FoldableData> read({
    Duration timeout = const Duration(seconds: 5),
  }) async => _defaultView().read(timeout: timeout);

  /// Watches layout data for the engine's implicit view.
  static Stream<FoldableData> watch() => _defaultView().watch();

  /// Reads angles for the engine's implicit view.
  static Future<FoldAngles> readAngles({
    Duration timeout = const Duration(seconds: 5),
  }) async => _defaultView().readAngles(timeout: timeout);

  /// Watches angles separately from layout data.
  static Stream<FoldAngles> watchAngles() => _defaultView().watchAngles();

  static FoldableView _defaultView() {
    final view = WidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView;
    if (view == null) {
      throw const FoldableError(
        ErrorCode.noView,
        'No default Flutter view. Use FoldableInfo.instance.forView(view).',
      );
    }
    return instance.forView(view);
  }

  /// Returns the shared handle for [view]. No subscription starts yet.
  /// iOS supports only its registrar view; other native view IDs report noView.
  FoldableView forView(ui.FlutterView view);
}

/// A measurement handle associated with one Flutter view.
///
/// Cancel your subscriptions, not the shared handle. Native observation stops
/// when no active stream subscriptions or one-shot reads remain.
abstract class FoldableView {
  /// Opaque, engine-local identifier of the measured view.
  int get viewId;

  /// Reads layout data once; native failures throw FoldableError.
  Future<FoldableData> read({Duration timeout = const Duration(seconds: 5)});

  /// Shared replay stream. Cancel only your own subscription.
  Stream<FoldableData> watch();

  /// Reads hinge angles once, separately from layout data.
  Future<FoldAngles> readAngles({
    Duration timeout = const Duration(seconds: 5),
  });

  /// Shared angle stream; listen only while an angle effect is active.
  Stream<FoldAngles> watchAngles();
}

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

class _NativeInfo extends FoldableInfo {
  final Map<ui.FlutterView, _NativeView> _views = {};
  @override
  FoldableView forView(ui.FlutterView view) => _views.putIfAbsent(
    view,
    () => _NativeView(view, () => _views.remove(view)),
  );
}

ViewInfo viewInfo(ui.FlutterView view) {
  final d = view.devicePixelRatio;
  EdgeInsets edges(ui.ViewPadding p) =>
      EdgeInsets.fromLTRB(p.left / d, p.top / d, p.right / d, p.bottom / d);
  return ViewInfo(
    size: view.physicalSize / d,
    pixelRatio: d,
    padding: edges(view.viewPadding),
    insets: edges(view.viewInsets),
    gestureInsets: edges(view.systemGestureInsets),
  );
}

FoldableData initialData(ui.FlutterView view) => FoldableData(
  viewId: view.viewId,
  sessionId: 'loading-${view.viewId}',
  revision: 0,
  viewState: ViewState.loading,
  view: DataValue.ready(
    viewInfo(view),
    source: DataSource.flutter,
    readAt: DateTime.now().toUtc(),
  ),
  isFoldable: DataValue.loading(),
  areas: DataValue.loading(),
  folds: DataValue.loading(),
  ios: DataValue.loading(),
);
FoldAngles initialAngles(ui.FlutterView view) => FoldAngles(
  viewId: view.viewId,
  sessionId: 'loading-${view.viewId}',
  sequence: 0,
  angles: DataValue.loading(),
);
FoldableError asFoldError(Object error) {
  if (error is FoldableError) return error;
  if (error is TimeoutException) {
    return const FoldableError(ErrorCode.timeout, 'Native read timed out.');
  }
  if (error is MissingPluginException) {
    return const FoldableError(
      ErrorCode.noPlugin,
      'foldable_info is not registered in this engine.',
    );
  }
  if (error is PlatformException) {
    final code =
        ErrorCode.values.where((v) => v.name == error.code).firstOrNull ??
        ErrorCode.nativeError;
    return FoldableError(code, error.message ?? 'Native operation failed.');
  }
  return const FoldableError(ErrorCode.badData, 'Invalid native data.');
}

FoldableData errorData(FoldableData last, FoldableError error) => last.copyWith(
  revision: last.revision + 1,
  error: error,
  areas: DataValue.error(error),
  folds: DataValue.error(error),
  ios: DataValue.error(error),
  isFoldable: DataValue.error(error),
);

class _NativeView extends FoldableView with WidgetsBindingObserver {
  _NativeView(this.view, this.onRemoved) {
    layout = ReplayFeed(
      initialData(view),
      start: () => _start(false),
      stop: () => _stop(false),
    );
    angles = ReplayFeed(
      initialAngles(view),
      start: () => _start(true),
      stop: () => _stop(true),
    );
  }
  final ui.FlutterView view;
  final VoidCallback onRemoved;
  static const _methods = MethodChannel('foldable_info/methods');
  static const _layoutChannel = EventChannel('foldable_info/layout');
  static const _angleChannel = EventChannel('foldable_info/angles');
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  late final ReplayFeed<FoldableData> layout;
  late final ReplayFeed<FoldAngles> angles;
  StreamSubscription<Object?>? _layoutSub, _angleSub;
  bool _observing = false, _paused = false, _removed = false;
  int _layoutEpoch = 0, _angleEpoch = 0;
  Map<Object?, Object?>? _raw;
  String? _nativeSession;
  int _nativeRevision = -1;
  int _angleSequence = -1;
  String? _angleSession;
  final Set<String> _oldSessions = {};
  final Set<String> _oldAngleSessions = {};
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

  void _start(bool angle) {
    if (_ios && viewId != 0) {
      _fail(
        angle,
        const FoldableError(
          ErrorCode.noView,
          'This iOS engine supports only its registrar view (view 0).',
        ),
      );
      return;
    }
    _observe();
    if (!_ios) {
      if (angle) {
        angles.add(
          initialAngles(view).copyWith(angles: DataValue.notSupported()),
        );
      } else {
        _publishFallback();
      }
      return;
    }
    if (angle) {
      final epoch = ++_angleEpoch;
      _angleSub = _angleChannel
          .receiveBroadcastStream({'viewId': viewId})
          .listen(
            (event) {
              if (epoch == _angleEpoch) {
                try {
                  _acceptAngles(wireMap(event));
                } catch (e) {
                  _fail(true, asFoldError(e));
                }
              }
            },
            onError: (Object e) {
              if (epoch == _angleEpoch) _fail(true, asFoldError(e));
            },
          );
    } else {
      final epoch = ++_layoutEpoch;
      _layoutSub = _layoutChannel
          .receiveBroadcastStream({'viewId': viewId})
          .listen(
            (event) {
              if (epoch == _layoutEpoch) {
                try {
                  _accept(wireMap(event));
                } catch (e) {
                  _fail(false, asFoldError(e));
                }
              }
            },
            onError: (Object e) {
              if (epoch == _layoutEpoch) _fail(false, asFoldError(e));
            },
          );
    }
  }

  void _stop(bool angle) {
    if (angle) {
      _angleEpoch++;
      _angleSub?.cancel();
      _angleSub = null;
    } else {
      _layoutEpoch++;
      _layoutSub?.cancel();
      _layoutSub = null;
    }
    _unobserve();
  }

  void _fail(bool angle, FoldableError error) {
    if (angle) {
      angles.add(
        angles.latest.copyWith(angles: DataValue.error(error), error: error),
      );
      angles.addError(error);
    } else {
      layout.add(errorData(layout.latest, error));
      layout.addError(error);
    }
  }

  void _accept(Map<Object?, Object?> raw) {
    checkWire(raw, viewId);
    final session = raw['sessionId'] as String;
    final revision = raw['revision'] as int;
    if (_oldSessions.contains(session)) return;
    if (_nativeSession == session && revision < _nativeRevision) return;
    if (_nativeSession != null && _nativeSession != session) {
      _oldSessions.add(_nativeSession!);
    }
    _nativeSession = session;
    _nativeRevision = revision;
    _raw = raw;
    final next = decodeData(raw, view, _paused);
    final last = layout.latest;
    // Ignore readAt and native observation counters in layout comparisons.
    final same =
        last.sessionId == next.sessionId &&
        semanticData(last) == semanticData(next);
    final value = next.copyWith(
      revision: last.sessionId == session ? last.revision + (same ? 0 : 1) : 1,
    );
    layout.latest = value;
    if (!same) layout.add(value);
  }

  void _acceptAngles(Map<Object?, Object?> raw) {
    checkWire(raw, viewId);
    final session = raw['sessionId'] as String;
    final sequence = raw['sequence'] as int;
    if (_oldSessions.contains(session) ||
        _oldAngleSessions.contains(session) ||
        (session == _angleSession && sequence < _angleSequence)) {
      return;
    }
    if (_angleSession != null && _angleSession != session) {
      _oldAngleSessions.add(_angleSession!);
    }
    _angleSession = session;
    _angleSequence = sequence;
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
    if (!_ios) {
      _publishFallback();
      return layout.latest;
    }
    if (viewId != 0) {
      throw const FoldableError(ErrorCode.noView, 'Unsupported iOS view ID.');
    }
    final raw = await _call('read', timeout);
    try {
      _accept(raw);
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
    if (!_ios) {
      return initialAngles(view).copyWith(angles: DataValue.notSupported());
    }
    try {
      if (viewId != 0) {
        throw const FoldableError(ErrorCode.noView, 'Unsupported iOS view ID.');
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
    final same =
        last.sessionId == next.sessionId &&
        semanticData(last) == semanticData(next);
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
        _accept(_raw!);
      } else if (!_ios) {
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
      _accept(_raw!);
    } else if (!_ios) {
      _publishFallback();
    }
    if (_paused) {
      angles.add(angles.latest.copyWith(angles: DataValue.notAvailable()));
    }
  }
}
