import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'models.dart';
import 'service.dart' show viewInfo;

Map<Object?, Object?> wireMap(Object? value) =>
    Map<Object?, Object?>.from(value as Map);
void checkWire(Map<Object?, Object?> raw, int viewId) {
  if (raw['version'] != 1) {
    throw const FoldableError(
      ErrorCode.badVersion,
      'Unsupported native data version.',
    );
  }
  if (raw['viewId'] != viewId) {
    throw const FoldableError(
      ErrorCode.noView,
      'Native data belongs to another view.',
    );
  }
  if (raw['sessionId'] is! String || (raw['sessionId'] as String).isEmpty) {
    throw const FoldableError(
      ErrorCode.badData,
      'Missing measurement session.',
    );
  }
  final counter = raw['revision'] ?? raw['sequence'];
  if (counter is! int || counter < 0) {
    throw const FoldableError(
      ErrorCode.badData,
      'Invalid measurement counter.',
    );
  }
}

double _number(Object? n) {
  final v = (n as num).toDouble();
  if (!v.isFinite) {
    throw const FoldableError(ErrorCode.badData, 'Non-finite native number.');
  }
  return v;
}

Rect _rect(Object? raw) {
  final m = wireMap(raw);
  return Rect.fromLTWH(
    _number(m['x']),
    _number(m['y']),
    _number(m['width']),
    _number(m['height']),
  );
}

EdgeInsets _insets(Object? raw) {
  final m = wireMap(raw);
  return EdgeInsets.fromLTRB(
    _number(m['left']),
    _number(m['top']),
    _number(m['right']),
    _number(m['bottom']),
  );
}

AreaDirection _direction(Rect r) => r.width == r.height
    ? AreaDirection.unknown
    : (r.width > r.height
          ? AreaDirection.leftToRight
          : AreaDirection.topToBottom);

FoldableData decodeData(
  Map<Object?, Object?> raw,
  ui.FlutterView view,
  bool paused,
) {
  final now = DateTime.now().toUtc();
  DataValue<T> ready<T>(T value) =>
      DataValue.ready(value, source: DataSource.ios, readAt: now);
  FoldableError? failure;
  DataValue<T> group<T>(T Function() read) {
    try {
      return ready(read());
    } catch (_) {
      failure ??= const FoldableError(
        ErrorCode.badData,
        'Invalid native measurement group.',
      );
      return DataValue.error(failure!, source: DataSource.ios);
    }
  }

  bool boolean(Object? value) => value as bool;
  final metrics = viewInfo(view);
  final attached = boolean(raw['attached']);
  final available = attached && !paused && !boolean(raw['paused']);
  final geometry = group(() {
    final size = wireMap(raw['size']);
    return boolean(raw['geometryValid']) &&
        (_number(size['width']) - metrics.size.width).abs() < .5 &&
        (_number(size['height']) - metrics.size.height).abs() < .5;
  });
  final DataValue<List<ViewArea>> areas;
  if (!attached) {
    areas = DataValue.loading(source: DataSource.ios);
  } else if (!available) {
    areas = DataValue.notAvailable(source: DataSource.ios);
  } else if (geometry.error != null) {
    areas = DataValue.error(geometry.error!, source: DataSource.ios);
  } else if (geometry.value != true) {
    areas = DataValue.loading(source: DataSource.ios);
  } else if (!boolean(raw['regionsSupported'])) {
    areas = DataValue.notSupported(source: DataSource.ios);
  } else {
    areas = group(
      () => [
        for (final item in raw['areas'] as List)
          (() {
            final m = wireMap(item), r = _rect(wireMap(item)['rect']);
            final division = m['nativeType'] == 'division';
            final type = division
                ? AreaType.fold
                : m['nativeType'] == 'occlusion'
                ? AreaType.blocked
                : AreaType.unknown;
            return ViewArea(
              id: m['id'] as String?,
              type: type,
              rect: r,
              extraSpace: _insets(m['extraSpace']),
              isActive: boolean(m['active']),
              direction: division ? _direction(r) : AreaDirection.unknown,
              cover: AreaCover.unknown,
              source: DataSource.ios,
              nativeType: m['nativeType'] as String?,
            );
          })(),
      ],
    );
  }
  final state = raw['hingeState'];
  final reportedFold = state != null;
  final foldState = switch (state) {
    1 => FoldState.closed,
    2 => FoldState.partlyOpen,
    3 => FoldState.open,
    _ => null,
  };
  final DataValue<List<FoldInfo>> folds;
  if (!attached) {
    folds = DataValue.loading(source: DataSource.ios);
  } else if (!available) {
    folds = DataValue.notAvailable(source: DataSource.ios);
  } else if (!boolean(raw['hingeSupported'])) {
    folds = DataValue.notSupported(source: DataSource.ios);
  } else if (reportedFold) {
    folds = ready([
      FoldInfo(
        openState: foldState == null
            ? DataValue.unknown(source: DataSource.ios)
            : ready(foldState),
        direction: AreaDirection.unknown,
        nativeState: state.toString(),
      ),
    ]);
  } else {
    folds = boolean(raw['hingeRead'])
        ? DataValue.notAvailable(source: DataSource.ios)
        : DataValue.loading(source: DataSource.ios);
  }
  final DataValue<IosInfo> ios;
  if (!attached) {
    ios = DataValue.loading(source: DataSource.ios);
  } else if (!available || geometry.value != true) {
    ios = DataValue.notAvailable(source: DataSource.ios);
  } else {
    ios = group(() {
      final m = wireMap(raw['ios']);
      DataValue<IosSize> sizeClass(Object? n) => switch (n) {
        0 => ready(IosSize.notSet),
        1 => ready(IosSize.compact),
        2 => ready(IosSize.regular),
        _ => DataValue.unknown(source: DataSource.ios),
      };
      final side = switch (m['barSide']) {
        0 => BarSide.none,
        1 => BarSide.start,
        2 => BarSide.end,
        _ => null,
      };
      return IosInfo(
        widthClass: sizeClass(m['widthClass']),
        heightClass: sizeClass(m['heightClass']),
        barSide: !boolean(m['barSupported'])
            ? DataValue.notSupported(source: DataSource.ios)
            : side == null
            ? DataValue.unknown(source: DataSource.ios)
            : ready(side),
        safeArea: ready(_insets(m['safeArea'])),
      );
    });
  }
  return FoldableData(
    viewId: view.viewId,
    sessionId: raw['sessionId'] as String,
    revision: raw['revision'] as int,
    viewState: !attached
        ? ViewState.loading
        : !available
        ? ViewState.paused
        : ViewState.ready,
    view: DataValue.ready(metrics, source: DataSource.flutter, readAt: now),
    isFoldable:
        reportedFold ||
            (areas.value?.any((a) => a.type == AreaType.fold) ?? false)
        ? ready(true)
        : DataValue.unknown(source: DataSource.ios),
    areas: areas,
    folds: folds,
    ios: ios,
    error: failure,
  );
}

FoldAngles decodeAngles(Map<Object?, Object?> raw, bool paused) {
  final DataValue<List<FoldAngle>> value;
  if (paused || raw['paused'] == true || raw['attached'] != true) {
    value = DataValue.notAvailable(source: DataSource.ios);
  } else {
    value = switch (raw['state']) {
      'ready' => DataValue.ready(
        [FoldAngle(degrees: _number(raw['degrees']))],
        source: DataSource.ios,
        readAt: DateTime.now().toUtc(),
      ),
      'loading' => DataValue.loading(source: DataSource.ios),
      'notSupported' => DataValue.notSupported(source: DataSource.ios),
      'notAvailable' => DataValue.notAvailable(source: DataSource.ios),
      _ => DataValue.unknown(source: DataSource.ios),
    };
  }
  return FoldAngles(
    viewId: raw['viewId'] as int,
    sessionId: raw['sessionId'] as String,
    sequence: raw['sequence'] as int,
    angles: value,
  );
}

FoldableData flutterData(ui.FlutterView view, bool paused) {
  final now = DateTime.now().toUtc();
  DataValue<T> ready<T>(T value) =>
      DataValue.ready(value, source: DataSource.flutter, readAt: now);
  final areas = <ViewArea>[], folds = <FoldInfo>[];
  for (final f in view.displayFeatures) {
    final type = switch (f.type) {
      ui.DisplayFeatureType.fold => AreaType.fold,
      ui.DisplayFeatureType.hinge => AreaType.hinge,
      ui.DisplayFeatureType.cutout => AreaType.blocked,
      _ => AreaType.unknown,
    };
    final fold = type == AreaType.fold || type == AreaType.hinge;
    final state = switch (f.state) {
      ui.DisplayFeatureState.postureFlat => FoldState.open,
      ui.DisplayFeatureState.postureHalfOpened => FoldState.partlyOpen,
      _ => null,
    };
    areas.add(
      ViewArea(
        type: type,
        rect: f.bounds,
        direction: fold ? _direction(f.bounds) : AreaDirection.unknown,
        cover: type == AreaType.hinge
            ? AreaCover.full
            : type == AreaType.fold
            ? AreaCover.none
            : AreaCover.unknown,
        splitsView:
            type == AreaType.hinge || (fold && state == FoldState.partlyOpen),
        source: DataSource.flutter,
        nativeType: f.type.name,
      ),
    );
    if (fold) {
      folds.add(
        FoldInfo(
          openState: state == null
              ? DataValue.unknown(source: DataSource.flutter)
              : ready(state),
          direction: _direction(f.bounds),
          nativeState: f.state.name,
        ),
      );
    }
  }
  return FoldableData(
    viewId: view.viewId,
    sessionId: 'flutter-${view.viewId}',
    revision: 0,
    viewState: paused ? ViewState.paused : ViewState.ready,
    view: ready(viewInfo(view)),
    isFoldable: folds.isEmpty
        ? DataValue.unknown(source: DataSource.flutter)
        : ready(true),
    areas: paused
        ? DataValue.notAvailable(source: DataSource.flutter)
        : ready(areas),
    folds: paused
        ? DataValue.notAvailable(source: DataSource.flutter)
        : ready(folds),
    ios: DataValue.notSupported(),
  );
}

/// Equality for layout changes, excluding observation times and counters.
InfoModel semanticData(FoldableData data) => _Semantic(
  _semantic([
        data.viewState,
        data.view,
        data.isFoldable,
        data.areas,
        data.folds,
        data.ios,
        data.error,
      ])
      as List<Object?>,
);
Object? _semantic(Object? v) {
  if (v is DataValue) return [v.state, _semantic(v.value), v.source, v.error];
  if (v is InfoModel) return v.fields.map(_semantic).toList();
  if (v is List) return v.map(_semantic).toList();
  return v;
}

class _Semantic extends InfoModel {
  const _Semantic(this.fields);
  @override
  final List<Object?> fields;
}
