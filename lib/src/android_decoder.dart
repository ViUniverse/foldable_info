import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'decode_values.dart';
import 'flutter_data.dart';
import 'models.dart';
import 'view_metrics.dart';
import 'wire_reader.dart';

typedef _FoldFeature = ({ViewArea area, FoldInfo fold});
typedef _ViewFeatures = ({List<ViewArea> areas, List<FoldInfo> folds});

FoldableData decodeAndroidData(
  Map<Object?, Object?> raw,
  ui.FlutterView view,
  bool paused,
) {
  final values = DecodeValues(DataSource.android);
  final metrics = viewInfo(view);
  final attached = raw['attached'] == true;
  final available = attached && !paused && raw['paused'] != true;
  final geometryMatches = _geometryMatches(raw, metrics);
  final state = _areaState(raw, attached, available, geometryMatches);
  final features = _decodeFeatures(raw, view, state, values);
  final hasFold =
      raw['hasHingeSensor'] == true || raw['hasFoldFeature'] == true;

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
    areas: _featureValues(features.areas, state, values),
    folds: _featureValues(features.folds, state, values),
    ios: DataValue.notSupported(),
    error: values.error,
  );
}

_ViewFeatures _decodeFeatures(
  Map<Object?, Object?> raw,
  ui.FlutterView view,
  DataState state,
  DecodeValues values,
) {
  const empty = (areas: <ViewArea>[], folds: <FoldInfo>[]);
  if (state != DataState.ready) return empty;
  return values.read(() {
        final features = (raw['features'] as List)
            .map((feature) => _decodeFeature(feature, values))
            .toList();
        return (
          areas: <ViewArea>[
            ...features.map((feature) => feature.area),
            ...flutterCutouts(view),
          ],
          folds: features.map((feature) => feature.fold).toList(),
        );
      }, message: 'Invalid Android fold measurements.').value ??
      empty;
}

bool _geometryMatches(Map<Object?, Object?> raw, ViewInfo metrics) {
  final size = wireMap(raw['size']);
  return raw['geometryValid'] == true &&
      (wireNumber(size['width']) - metrics.size.width).abs() < .5 &&
      (wireNumber(size['height']) - metrics.size.height).abs() < .5 &&
      (wireNumber(raw['pixelRatio']) - metrics.pixelRatio).abs() < .001;
}

DataState _areaState(
  Map<Object?, Object?> raw,
  bool attached,
  bool available,
  bool geometryMatches,
) {
  if (!attached) return DataState.loading;
  if (!available) return DataState.notAvailable;
  if (raw['layoutRead'] != true || !geometryMatches) return DataState.loading;
  return DataState.ready;
}

DataValue<List<T>> _featureValues<T>(
  List<T> features,
  DataState state,
  DecodeValues values,
) => switch ((values.error, state)) {
  (final error?, _) => DataValue.error(error, source: values.source),
  (_, DataState.ready) => values.ready(features),
  (_, DataState.loading) => DataValue.loading(source: values.source),
  _ => DataValue.notAvailable(source: values.source),
};

_FoldFeature _decodeFeature(Object? raw, DecodeValues values) {
  final feature = wireMap(raw);
  final id = feature['id'] as String?;
  final direction =
      AreaDirection.values.firstWhereOrNull(
        (direction) => direction.name == feature['direction'],
      ) ??
      AreaDirection.unknown;
  final openState = FoldState.values.firstWhereOrNull(
    (state) => state.name == feature['openState'],
  );
  return (
    area: ViewArea(
      id: id,
      foldId: id,
      type: feature['type'] == 'hinge' ? AreaType.hinge : AreaType.fold,
      rect: wireRect(feature['rect']),
      isActive: true,
      splitsView: feature['splitsView'] as bool,
      direction: direction,
      cover: switch (feature['cover']) {
        'full' => AreaCover.full,
        'none' => AreaCover.none,
        _ => AreaCover.unknown,
      },
      source: values.source,
      nativeType: 'FoldingFeature',
    ),
    fold: FoldInfo(
      id: id,
      direction: direction,
      openState: openState == null
          ? DataValue.unknown(source: values.source)
          : values.ready(openState),
      nativeState: feature['nativeState'] as String?,
    ),
  );
}
