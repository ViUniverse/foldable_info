import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'foldable_view.dart';
import 'models.dart';
import 'native_view.dart';

export 'foldable_view.dart' show FoldableView;

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
  /// Native Android/iOS support only their engine view; other IDs report noView.
  FoldableView forView(ui.FlutterView view);
}

class _NativeInfo extends FoldableInfo {
  final Map<ui.FlutterView, NativeView> _views = {};
  @override
  FoldableView forView(ui.FlutterView view) => _views.putIfAbsent(
    view,
    () => NativeView(view, () => _views.remove(view)),
  );
}
