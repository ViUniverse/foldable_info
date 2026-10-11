import 'dart:ui' as ui;
import 'decode_values.dart';
import 'models.dart';
import 'view_metrics.dart';

FoldableData flutterData(ui.FlutterView view, bool paused) {
  final values = DecodeValues(DataSource.flutter);
  final features = view.displayFeatures;
  final areas = features.map(_decodeArea).toList();
  final folds = features
      .where(_isFold)
      .map((feature) => _decodeFold(feature, values))
      .toList();

  return FoldableData(
    viewId: view.viewId,
    sessionId: 'flutter-${view.viewId}',
    revision: 0,
    viewState: paused ? ViewState.paused : ViewState.ready,
    view: values.ready(viewInfo(view)),
    isFoldable: folds.isEmpty
        ? DataValue.unknown(source: values.source)
        : values.ready(true),
    areas: paused
        ? DataValue.notAvailable(source: values.source)
        : values.ready(areas),
    folds: paused
        ? DataValue.notAvailable(source: values.source)
        : values.ready(folds),
    ios: DataValue.notSupported(),
  );
}

/// Flutter contributes cutouts to native Android data, without duplicate folds.
Iterable<ViewArea> flutterCutouts(ui.FlutterView view) => view.displayFeatures
    .where((feature) => feature.type == ui.DisplayFeatureType.cutout)
    .map(_decodeArea);

bool _isFold(ui.DisplayFeature feature) => switch (feature.type) {
  ui.DisplayFeatureType.fold || ui.DisplayFeatureType.hinge => true,
  _ => false,
};

ViewArea _decodeArea(ui.DisplayFeature feature) => ViewArea(
  type: switch (feature.type) {
    ui.DisplayFeatureType.fold => AreaType.fold,
    ui.DisplayFeatureType.hinge => AreaType.hinge,
    ui.DisplayFeatureType.cutout => AreaType.blocked,
    _ => AreaType.unknown,
  },
  rect: feature.bounds,
  direction: _isFold(feature)
      ? areaDirection(feature.bounds)
      : AreaDirection.unknown,
  cover: switch (feature.type) {
    ui.DisplayFeatureType.hinge => AreaCover.full,
    ui.DisplayFeatureType.fold => AreaCover.none,
    _ => AreaCover.unknown,
  },
  splitsView:
      feature.type == ui.DisplayFeatureType.hinge ||
      (_isFold(feature) &&
          feature.state == ui.DisplayFeatureState.postureHalfOpened),
  source: DataSource.flutter,
  nativeType: feature.type.name,
);

FoldInfo _decodeFold(ui.DisplayFeature feature, DecodeValues values) =>
    FoldInfo(
      openState: switch (feature.state) {
        ui.DisplayFeatureState.postureFlat => values.ready(FoldState.open),
        ui.DisplayFeatureState.postureHalfOpened => values.ready(
          FoldState.partlyOpen,
        ),
        _ => DataValue.unknown(source: values.source),
      },
      direction: areaDirection(feature.bounds),
      nativeState: feature.state.name,
    );
