import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'models.dart';
import 'view_metrics.dart';

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
    final current = viewInfo(view);
    final measured = data.view.value;
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
    final transform = _readBoxTransform(target.getTransformTo(root).storage);
    if (transform == null) return result(LocalState.badTransform);
    final boxBounds = Offset.zero & target.size;
    final areas = data.areas.value!
        .map((area) => _toLocalArea(area, transform, boxBounds))
        .nonNulls
        .toList();
    return result(LocalState.ready, areas: areas);
  }
}

typedef _BoxTransform = ({
  double scaleX,
  double scaleY,
  double offsetX,
  double offsetY,
});

_BoxTransform? _readBoxTransform(List<double> matrix) {
  // Matrix4 uses column-major storage. Only translation and positive 2D scale
  // can preserve axis-aligned area frames without changing their meaning.
  const zeroIndices = [1, 2, 3, 4, 6, 7, 8, 9, 11, 14];
  const tolerance = 1e-9;
  final valid =
      matrix.every((value) => value.isFinite) &&
      zeroIndices.every((index) => matrix[index].abs() <= tolerance) &&
      (matrix[10] - 1).abs() <= tolerance &&
      (matrix[15] - 1).abs() <= tolerance &&
      matrix[0] > 0 &&
      matrix[5] > 0;
  if (!valid) return null;
  return (
    scaleX: matrix[0],
    scaleY: matrix[5],
    offsetX: matrix[12],
    offsetY: matrix[13],
  );
}

ViewArea? _toLocalArea(ViewArea area, _BoxTransform transform, Rect boxBounds) {
  final localRect = Rect.fromLTRB(
    (area.rect.left - transform.offsetX) / transform.scaleX,
    (area.rect.top - transform.offsetY) / transform.scaleY,
    (area.rect.right - transform.offsetX) / transform.scaleX,
    (area.rect.bottom - transform.offsetY) / transform.scaleY,
  );
  final clipped = _clipArea(localRect, boxBounds);
  if (clipped == null) return null;
  return area.copyWith(
    rect: clipped,
    extraSpace: switch (area.extraSpace) {
      final spacing? => EdgeInsets.fromLTRB(
        spacing.left / transform.scaleX,
        spacing.top / transform.scaleY,
        spacing.right / transform.scaleX,
        spacing.bottom / transform.scaleY,
      ),
      null => null,
    },
  );
}

Rect? _clipArea(Rect area, Rect boxBounds) {
  // Rect.intersect drops empty rectangles. A zero-width/height fold is a useful
  // dividing line, so clip those two cases before ordinary rectangles.
  if (area.width == 0 && area.height > 0) {
    if (area.left <= 0 ||
        area.left >= boxBounds.right ||
        area.bottom <= 0 ||
        area.top >= boxBounds.bottom) {
      return null;
    }
    return Rect.fromLTRB(
      area.left,
      area.top.clamp(0, boxBounds.bottom),
      area.right,
      area.bottom.clamp(0, boxBounds.bottom),
    );
  }
  if (area.height == 0 && area.width > 0) {
    if (area.top <= 0 ||
        area.top >= boxBounds.bottom ||
        area.right <= 0 ||
        area.left >= boxBounds.right) {
      return null;
    }
    return Rect.fromLTRB(
      area.left.clamp(0, boxBounds.right),
      area.top,
      area.right.clamp(0, boxBounds.right),
      area.bottom,
    );
  }
  final clipped = area.intersect(boxBounds);
  return clipped.isEmpty ? null : clipped;
}
