import 'dart:ui' as ui;
import 'decode_values.dart';
import 'models.dart';
import 'view_metrics.dart';
import 'wire_reader.dart';

FoldableData decodeIosData(
  Map<Object?, Object?> raw,
  ui.FlutterView view,
  bool paused,
) {
  final values = DecodeValues(DataSource.ios);
  final metrics = viewInfo(view);
  final attached = raw['attached'] as bool;
  final available = attached && !paused && !(raw['paused'] as bool);
  final geometry = values.read(() => _geometryMatches(raw, metrics));
  final areas = _decodeAreas(raw, attached, available, geometry, values);
  final folds = _decodeFolds(raw, attached, available, values);
  final ios = _decodeIos(raw, attached, available, geometry, values);
  final hasFold =
      raw['hingeState'] != null ||
      (areas.value?.any((area) => area.type == AreaType.fold) ?? false);

  return FoldableData(
    viewId: view.viewId,
    sessionId: raw['sessionId'] as String,
    revision: raw['revision'] as int,
    viewState: nativeViewState(attached: attached, available: available),
    view: DataValue.ready(
      metrics,
      source: DataSource.flutter,
      readAt: values.readAt,
    ),
    isFoldable: hasFold
        ? values.ready(true)
        : DataValue.unknown(source: values.source),
    areas: areas,
    folds: folds,
    ios: ios,
    error: values.error,
  );
}

bool _geometryMatches(Map<Object?, Object?> raw, ViewInfo metrics) {
  final size = wireMap(raw['size']);
  return (raw['geometryValid'] as bool) &&
      (wireNumber(size['width']) - metrics.size.width).abs() < .5 &&
      (wireNumber(size['height']) - metrics.size.height).abs() < .5;
}

DataValue<List<ViewArea>> _decodeAreas(
  Map<Object?, Object?> raw,
  bool attached,
  bool available,
  DataValue<bool> geometry,
  DecodeValues values,
) {
  if (!attached) return DataValue.loading(source: values.source);
  if (!available) return DataValue.notAvailable(source: values.source);
  if (geometry.error case final error?) {
    return DataValue.error(error, source: values.source);
  }
  if (geometry.value != true) return DataValue.loading(source: values.source);
  if (!(raw['regionsSupported'] as bool)) {
    return DataValue.notSupported(source: values.source);
  }
  return values.read(() => (raw['areas'] as List).map(_decodeArea).toList());
}

ViewArea _decodeArea(Object? raw) {
  final area = wireMap(raw);
  final rect = wireRect(area['rect']);
  final type = switch (area['nativeType']) {
    'division' => AreaType.fold,
    'occlusion' => AreaType.blocked,
    _ => AreaType.unknown,
  };
  return ViewArea(
    id: area['id'] as String?,
    type: type,
    rect: rect,
    extraSpace: wireInsets(area['extraSpace']),
    isActive: area['active'] as bool,
    direction: type == AreaType.fold
        ? areaDirection(rect)
        : AreaDirection.unknown,
    cover: AreaCover.unknown,
    source: DataSource.ios,
    nativeType: area['nativeType'] as String?,
  );
}

DataValue<List<FoldInfo>> _decodeFolds(
  Map<Object?, Object?> raw,
  bool attached,
  bool available,
  DecodeValues values,
) {
  if (!attached) return DataValue.loading(source: values.source);
  if (!available) return DataValue.notAvailable(source: values.source);
  if (!(raw['hingeSupported'] as bool)) {
    return DataValue.notSupported(source: values.source);
  }
  final nativeState = raw['hingeState'];
  if (nativeState == null) {
    return (raw['hingeRead'] as bool)
        ? DataValue.notAvailable(source: values.source)
        : DataValue.loading(source: values.source);
  }
  final openState = switch (nativeState) {
    1 => values.ready(FoldState.closed),
    2 => values.ready(FoldState.partlyOpen),
    3 => values.ready(FoldState.open),
    _ => DataValue<FoldState>.unknown(source: values.source),
  };
  return values.ready([
    FoldInfo(
      openState: openState,
      direction: AreaDirection.unknown,
      nativeState: nativeState.toString(),
    ),
  ]);
}

DataValue<IosInfo> _decodeIos(
  Map<Object?, Object?> raw,
  bool attached,
  bool available,
  DataValue<bool> geometry,
  DecodeValues values,
) {
  if (!attached) return DataValue.loading(source: values.source);
  if (!available || geometry.value != true) {
    return DataValue.notAvailable(source: values.source);
  }
  return values.read(() {
    final traits = wireMap(raw['ios']);
    return IosInfo(
      widthClass: _decodeSizeClass(traits['widthClass'], values),
      heightClass: _decodeSizeClass(traits['heightClass'], values),
      barSide: _decodeBarSide(traits, values),
      safeArea: values.ready(wireInsets(traits['safeArea'])),
    );
  });
}

DataValue<IosSize> _decodeSizeClass(Object? value, DecodeValues values) =>
    switch (value) {
      0 => values.ready(IosSize.notSet),
      1 => values.ready(IosSize.compact),
      2 => values.ready(IosSize.regular),
      _ => DataValue.unknown(source: values.source),
    };

DataValue<BarSide> _decodeBarSide(
  Map<Object?, Object?> traits,
  DecodeValues values,
) {
  if (!(traits['barSupported'] as bool)) {
    return DataValue.notSupported(source: values.source);
  }
  return switch (traits['barSide']) {
    0 => values.ready(BarSide.none),
    1 => values.ready(BarSide.start),
    2 => values.ready(BarSide.end),
    _ => DataValue.unknown(source: values.source),
  };
}
