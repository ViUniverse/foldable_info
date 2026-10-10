import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'models.dart';
import 'service.dart' show viewInfo;

/// Converts measured view areas into a widget's local coordinates.
abstract final class FoldableSpace {
  /// Converts and clips [data]'s areas after [target] has finished layout.
  ///
  /// Returns [LocalState.badTransform] for unsupported transforms and
  /// [LocalState.oldData] when size/pixel ratio have changed. Data or a target
  /// from another [view] throws [ArgumentError]. iOS margins are already in the
  /// area frame and must not be added again.
  static LocalAreas toBox({
    required FoldableData data,
    required RenderBox target,
    required ui.FlutterView view,
  }) {
    if (data.viewId != view.viewId) {
      throw ArgumentError('Data and FlutterView do not match.');
    }
    LocalAreas result(LocalState state, {List<ViewArea> areas = const []}) =>
        LocalAreas(
          state: state,
          size: target.hasSize ? target.size : null,
          areas: areas,
          sessionId: data.sessionId,
          revision: data.revision,
        );
    if (!target.attached || !target.hasSize) return result(LocalState.loading);
    RenderObject root = target;
    while (root.parent != null) {
      root = root.parent!;
    }
    if (root is! RenderView || !identical(root.flutterView, view)) {
      throw ArgumentError('Target belongs to another FlutterView.');
    }
    if (data.viewState == ViewState.paused ||
        data.viewState == ViewState.removed) {
      return result(LocalState.notAvailable);
    }
    final current = viewInfo(view), measured = data.view.value;
    if (measured == null ||
        measured.size != current.size ||
        measured.pixelRatio != current.pixelRatio) {
      return result(LocalState.oldData);
    }
    if (!data.areas.isReady) {
      return result(
        data.areas.state == DataState.loading
            ? LocalState.loading
            : LocalState.notAvailable,
      );
    }
    final matrix = target.getTransformTo(root), m = matrix.storage;
    // Permit only translation and positive axis-aligned scale. Reject
    // rotation, skew, reflection, perspective and transforms involving Z.
    final zeros = [1, 2, 3, 4, 6, 7, 8, 9, 11, 14];
    if (!m.every((v) => v.isFinite) ||
        zeros.any((i) => m[i].abs() > 1e-9) ||
        (m[10] - 1).abs() > 1e-9 ||
        (m[15] - 1).abs() > 1e-9 ||
        m[0] <= 0 ||
        m[5] <= 0) {
      return result(LocalState.badTransform);
    }
    final sx = m[0], sy = m[5], dx = m[12], dy = m[13];
    final box = Offset.zero & target.size, areas = <ViewArea>[];
    for (final a in data.areas.value!) {
      final r = a.rect;
      final local = Rect.fromLTRB(
        (r.left - dx) / sx,
        (r.top - dy) / sy,
        (r.right - dx) / sx,
        (r.bottom - dy) / sy,
      );
      final Rect clipped;
      if (local.width == 0 && local.height > 0) {
        if (local.left <= 0 ||
            local.left >= box.right ||
            local.bottom <= 0 ||
            local.top >= box.bottom) {
          continue;
        }
        clipped = Rect.fromLTRB(
          local.left,
          local.top.clamp(0, box.bottom),
          local.right,
          local.bottom.clamp(0, box.bottom),
        );
      } else if (local.height == 0 && local.width > 0) {
        if (local.top <= 0 ||
            local.top >= box.bottom ||
            local.right <= 0 ||
            local.left >= box.right) {
          continue;
        }
        clipped = Rect.fromLTRB(
          local.left.clamp(0, box.right),
          local.top,
          local.right.clamp(0, box.right),
          local.bottom,
        );
      } else {
        clipped = local.intersect(box);
        if (clipped.isEmpty) continue;
      }
      final e = a.extraSpace;
      areas.add(
        a.copyWith(
          rect: clipped,
          extraSpace: e == null
              ? null
              : EdgeInsets.fromLTRB(
                  e.left / sx,
                  e.top / sy,
                  e.right / sx,
                  e.bottom / sy,
                ),
        ),
      );
    }
    return result(LocalState.ready, areas: areas);
  }
}
