import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'models.dart';

ViewInfo viewInfo(ui.FlutterView view) {
  final pixelRatio = view.devicePixelRatio;
  EdgeInsets edges(ui.ViewPadding p) => EdgeInsets.fromLTRB(
    p.left / pixelRatio,
    p.top / pixelRatio,
    p.right / pixelRatio,
    p.bottom / pixelRatio,
  );
  return ViewInfo(
    size: view.physicalSize / pixelRatio,
    pixelRatio: pixelRatio,
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
