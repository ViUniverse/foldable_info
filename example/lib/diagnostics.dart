import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:foldable_info/foldable_info.dart';

/// Complete layout evidence for a bug report; no hardware identifiers or user data.
String snapshotJson(FoldableData data) {
  List<double> rect(Rect r) => [r.left, r.top, r.width, r.height];
  List<double>? insets(EdgeInsets? e) =>
      e == null ? null : [e.left, e.top, e.right, e.bottom];
  final view = data.view.value;
  final ios = data.ios.value;
  return const JsonEncoder.withIndent('  ').convert({
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
    'sessionId': data.sessionId,
    'revision': data.revision,
    'viewId': data.viewId,
    'viewState': data.viewState.name,
    'units': 'logicalPixels',
    'frameIncludesMarginsOnIos': true,
    'view': {
      'state': data.view.state.name,
      'size': view == null ? null : [view.size.width, view.size.height],
      'pixelRatio': view?.pixelRatio,
      'padding': insets(view?.padding),
      'keyboardInsets': insets(view?.insets),
      'gestureInsets': insets(view?.gestureInsets),
    },
    'isFoldable': {
      'state': data.isFoldable.state.name,
      'value': data.isFoldable.value,
    },
    'areasState': data.areas.state.name,
    'areasReadAt': data.areas.readAt?.toIso8601String(),
    'areas': data.areas.value
        ?.map(
          (a) => {
            'id': a.id,
            'type': a.type.name,
            'nativeType': a.nativeType,
            'source': a.source.name,
            'rectXYWH': rect(a.rect),
            'marginsLTRB': insets(a.extraSpace),
            'active': a.isActive,
            'splitsView': a.splitsView,
            'cover': a.cover.name,
            'direction': a.direction.name,
            'foldId': a.foldId,
          },
        )
        .toList(),
    'foldsState': data.folds.state.name,
    'folds': data.folds.value
        ?.map(
          (f) => {
            'id': f.id,
            'state': f.openState.state.name,
            'posture': f.openState.value?.name,
            'nativeState': f.nativeState,
          },
        )
        .toList(),
    'iosState': data.ios.state.name,
    'ios': ios == null
        ? null
        : {
            'barSide': ios.barSide.value?.name,
            'barSideState': ios.barSide.state.name,
            'widthClass': ios.widthClass.value?.name,
            'heightClass': ios.heightClass.value?.name,
            'safeArea': insets(ios.safeArea.value),
          },
  });
}
