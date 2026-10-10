import 'package:flutter/widgets.dart';

/// Availability of one measured value.
enum DataState {
  /// A measured value is available, including an empty list.
  ready,

  /// Waiting for a valid measurement.
  loading,

  /// The API exists, but no current value is available.
  notAvailable,

  /// The platform or API cannot supply this value.
  notSupported,

  /// Available evidence cannot answer this question.
  unknown,

  /// Reading or decoding failed.
  error,
}

/// Origin of a measurement; not a claim about device capabilities.
enum DataSource {
  /// Flutter view metrics or display features.
  flutter,

  /// Public UIKit APIs.
  ios,

  /// Reserved for a future native Android bridge.
  android,

  /// A value calculated from other measurements.
  calculated,

  /// No known source is available.
  unknown,
}

/// State of the Flutter view being observed.
enum ViewState {
  /// The view is waiting to attach or receive initial data.
  loading,

  /// The view is attached and available.
  ready,

  /// Current native measurements are unavailable while paused.
  paused,

  /// The view has been removed; observation ends.
  removed,
}

/// Meaning of a measured area.
enum AreaType {
  /// A division or fold line, which need not cover content.
  fold,

  /// A hinge gap between display panels.
  hinge,

  /// An area reserved by hardware or system UI.
  blocked,

  /// The native area type is not recognized.
  unknown,
}

/// Direction in which a fold line runs.
enum AreaDirection {
  /// A horizontal fold line.
  leftToRight,

  /// A vertical fold line.
  topToBottom,

  /// The direction is not reported or cannot be determined.
  unknown,
}

/// Whether an area hides content; unknown is distinct from none.
enum AreaCover {
  /// The fold line does not hide content.
  none,

  /// Content in this area is hidden.
  full,

  /// Coverage is not reported.
  unknown,
}

/// Fold status supplied by the OS, not inferred from angle thresholds.
enum FoldState {
  /// The OS reports a closed fold.
  closed,

  /// The OS reports an intermediate fold state.
  partlyOpen,

  /// The OS reports a fully open fold.
  open,
}

/// UIKit size class; these are not package-defined breakpoints.
enum IosSize {
  /// UIKit compact size class.
  compact,

  /// UIKit regular size class.
  regular,

  /// UIKit unspecified size class.
  notSet,
}

/// Logical edge where iOS prefers a vertical bar.
enum BarSide {
  /// Leading edge; resolve using Directionality.
  start,

  /// Trailing edge; resolve using Directionality.
  end,

  /// No preferred vertical edge.
  none,
}

/// Result of converting view areas into a widget box.
enum LocalState {
  /// Local areas are available, including an empty list.
  ready,

  /// The target or native area data is not laid out/ready yet.
  loading,

  /// The view or area data is currently unavailable.
  notAvailable,

  /// The transform includes unsupported rotation, skew or perspective.
  badTransform,

  /// The measured view size or pixel ratio no longer matches.
  oldData,
}

/// Stable categories for native read and stream failures.
enum ErrorCode {
  /// There is no supported view for this request.
  noView,

  /// The native plugin is not registered in this engine.
  noPlugin,

  /// A native operation failed.
  nativeError,

  /// The native payload is invalid.
  badData,

  /// A read did not finish before its deadline.
  timeout,

  /// The native wire version is not supported.
  badVersion,
}

const _keep = Object();

bool _equal(Object? a, Object? b) {
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => _equal(a[i], b[i])).every((v) => v);
  }
  return a == b;
}

int _hash(Object? v) => v is List ? Object.hashAll(v.map(_hash)) : v.hashCode;

/// Value equality shared by immutable measurement models.
@immutable
abstract class InfoModel {
  /// Creates this measurement value.
  const InfoModel();

  /// Fields used for value equality, hashing and diagnostics.
  List<Object?> get fields;
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is InfoModel &&
      _equal(fields, other.fields);
  @override
  int get hashCode => Object.hash(runtimeType, _hash(fields));
  @override
  String toString() => '$runtimeType(${fields.join(', ')})';
}

/// A typed failure from reading or decoding native measurements.
class FoldableError extends InfoModel implements Exception {
  /// Creates this measurement value.
  const FoldableError(this.code, this.message);

  /// Stable error category.
  final ErrorCode code;

  /// Human-readable diagnostic, not intended for matching program logic.
  final String message;
  @override
  List<Object?> get fields => [code, message];

  /// Copies this value with selected fields replaced.
  FoldableError copyWith({ErrorCode? code, String? message}) =>
      FoldableError(code ?? this.code, message ?? this.message);
}

/// A measured value with availability, source and UTC observation time.
/// Only ready values contain data. Keep custom values immutable.
class DataValue<T> extends InfoModel {
  const DataValue._(
    this.state,
    this.value,
    this.source,
    this.readAt,
    this.error,
  );

  /// Creates a ready value with the corresponding availability state.
  factory DataValue.ready(
    T value, {
    required DataSource source,
    required DateTime readAt,
  }) {
    if (value == null || source == DataSource.unknown || !readAt.isUtc) {
      throw ArgumentError(
        'Ready data requires a value, a known source and UTC readAt.',
      );
    }
    return DataValue._(DataState.ready, value, source, readAt, null);
  }

  /// Creates a loading value with the corresponding availability state.
  factory DataValue.loading({DataSource source = DataSource.unknown}) =>
      DataValue._(DataState.loading, null, source, null, null);

  /// Creates a notAvailable value with the corresponding availability state.
  factory DataValue.notAvailable({DataSource source = DataSource.unknown}) =>
      DataValue._(DataState.notAvailable, null, source, null, null);

  /// Creates a notSupported value with the corresponding availability state.
  factory DataValue.notSupported({DataSource source = DataSource.unknown}) =>
      DataValue._(DataState.notSupported, null, source, null, null);

  /// Creates a unknown value with the corresponding availability state.
  factory DataValue.unknown({DataSource source = DataSource.unknown}) =>
      DataValue._(DataState.unknown, null, source, null, null);

  /// Creates a error value with the corresponding availability state.
  factory DataValue.error(
    FoldableError error, {
    DataSource source = DataSource.unknown,
  }) => DataValue._(DataState.error, null, source, null, error);

  /// Availability of this value or conversion result.
  final DataState state;

  /// The measured value, non-null only while ready.
  final T? value;

  /// The API or calculation which supplied this value.
  final DataSource source;

  /// UTC observation time, present only for ready data.
  final DateTime? readAt;

  /// Latest failure, cleared by a successful measurement.
  final FoldableError? error;

  /// Whether a measured value is present.
  bool get isReady => state == DataState.ready;

  /// Changing state clears fields which are invalid in the new state.
  /// Explicitly clearing a required ready value/time or error is rejected.
  DataValue<T> copyWith({
    DataState? state,
    Object? value = _keep,
    DataSource? source,
    Object? readAt = _keep,
    Object? error = _keep,
  }) {
    final next = state ?? this.state;
    final data = identical(value, _keep)
        ? (next == DataState.ready ? this.value : null)
        : value as T?;
    final time = identical(readAt, _keep)
        ? (next == DataState.ready ? this.readAt : null)
        : readAt as DateTime?;
    final failure = identical(error, _keep)
        ? (next == DataState.error ? this.error : null)
        : error as FoldableError?;
    if (next == DataState.ready) {
      if (data == null || time == null || failure != null) {
        throw ArgumentError('Ready data requires a value/time and no error.');
      }
      return DataValue.ready(data, source: source ?? this.source, readAt: time);
    }
    if (data != null ||
        time != null ||
        (next == DataState.error ? failure == null : failure != null)) {
      throw ArgumentError('Invalid fields for data state ${next.name}.');
    }
    return DataValue._(next, null, source ?? this.source, null, failure);
  }

  @override
  List<Object?> get fields => [state, value, source, readAt, error];
}

DataValue<List<T>> _list<T>(DataValue<List<T>> v) => v.isReady
    ? DataValue.ready(
        List<T>.unmodifiable(v.value!),
        source: v.source,
        readAt: v.readAt!,
      )
    : v;
void _rect(Rect r) {
  if (![r.left, r.top, r.width, r.height].every((v) => v.isFinite) ||
      r.width < 0 ||
      r.height < 0) {
    throw ArgumentError('Invalid rect');
  }
}

void _insets(EdgeInsets e) {
  if (![e.left, e.top, e.right, e.bottom].every((v) => v.isFinite && v >= 0)) {
    throw ArgumentError('Invalid insets');
  }
}

/// Current Flutter view metrics in logical pixels.
class ViewInfo extends InfoModel {
  /// Creates this measurement value.
  ViewInfo({
    required this.size,
    required this.pixelRatio,
    required this.padding,
    required this.insets,
    required this.gestureInsets,
  }) {
    _rect(Offset.zero & size);
    if (!pixelRatio.isFinite || pixelRatio <= 0) {
      throw ArgumentError('Invalid pixelRatio');
    }
    _insets(padding);
    _insets(insets);
    _insets(gestureInsets);
  }

  /// Size in Flutter logical pixels.
  final Size size;

  /// Physical pixels per logical pixel.
  final double pixelRatio;

  /// Stable safe padding from FlutterView.viewPadding, including with a keyboard.
  final EdgeInsets padding;

  /// Obscured edge insets, such as the docked keyboard.
  final EdgeInsets insets;

  /// Edge distances reserved for system gestures.
  final EdgeInsets gestureInsets;
  @override
  List<Object?> get fields => [
    size,
    pixelRatio,
    padding,
    insets,
    gestureInsets,
  ];

  /// Copies this value with selected fields replaced.
  ViewInfo copyWith({
    Size? size,
    double? pixelRatio,
    EdgeInsets? padding,
    EdgeInsets? insets,
    EdgeInsets? gestureInsets,
  }) => ViewInfo(
    size: size ?? this.size,
    pixelRatio: pixelRatio ?? this.pixelRatio,
    padding: padding ?? this.padding,
    insets: insets ?? this.insets,
    gestureInsets: gestureInsets ?? this.gestureInsets,
  );
}

/// A fold, hinge or reserved area relative to the complete Flutter view.
class ViewArea extends InfoModel {
  /// Creates this measurement value.
  ViewArea({
    this.id,
    required this.type,
    required this.rect,
    this.extraSpace,
    this.isActive,
    this.splitsView,
    required this.direction,
    required this.cover,
    this.foldId,
    required this.source,
    this.nativeType,
  }) {
    _rect(rect);
    if (extraSpace != null) _insets(extraSpace!);
  }

  /// Optional identifier, scoped to the current observation session.
  final String? id;

  /// The reported area kind.
  final AreaType type;

  /// Frame in logical pixels relative to the view or converted widget box.
  final Rect rect;

  /// Reported margins; iOS frames already include them. Do not inflate again.
  final EdgeInsets? extraSpace;

  /// Whether this reserved area is active, not which physical screen is on.
  final bool? isActive;

  /// Whether the source reports a separating fold/hinge; null if unknown.
  final bool? splitsView;

  /// Direction of the fold line, if known.
  final AreaDirection direction;

  /// Reported content coverage; unknown is not none.
  final AreaCover cover;

  /// Optional link to a reported fold; never infer it from list position.
  final String? foldId;

  /// The API or calculation which supplied this value.
  final DataSource source;

  /// Native area kind retained for diagnostics.
  final String? nativeType;
  @override
  List<Object?> get fields => [
    id,
    type,
    rect,
    extraSpace,
    isActive,
    splitsView,
    direction,
    cover,
    foldId,
    source,
    nativeType,
  ];

  /// Copies this value with selected fields replaced.
  ViewArea copyWith({
    Object? id = _keep,
    AreaType? type,
    Rect? rect,
    Object? extraSpace = _keep,
    Object? isActive = _keep,
    Object? splitsView = _keep,
    AreaDirection? direction,
    AreaCover? cover,
    Object? foldId = _keep,
    DataSource? source,
    Object? nativeType = _keep,
  }) => ViewArea(
    id: identical(id, _keep) ? this.id : id as String?,
    type: type ?? this.type,
    rect: rect ?? this.rect,
    extraSpace: identical(extraSpace, _keep)
        ? this.extraSpace
        : extraSpace as EdgeInsets?,
    isActive: identical(isActive, _keep) ? this.isActive : isActive as bool?,
    splitsView: identical(splitsView, _keep)
        ? this.splitsView
        : splitsView as bool?,
    direction: direction ?? this.direction,
    cover: cover ?? this.cover,
    foldId: identical(foldId, _keep) ? this.foldId : foldId as String?,
    source: source ?? this.source,
    nativeType: identical(nativeType, _keep)
        ? this.nativeType
        : nativeType as String?,
  );
}

/// The reported state and direction of one fold.
class FoldInfo extends InfoModel {
  /// Creates this measurement value.
  const FoldInfo({
    this.id,
    required this.openState,
    required this.direction,
    this.nativeState,
  });

  /// Optional identifier, scoped to the current observation session.
  final String? id;

  /// OS fold status with independent availability.
  final DataValue<FoldState> openState;

  /// Direction of the fold line, if known.
  final AreaDirection direction;

  /// Native fold status retained for diagnostics.
  final String? nativeState;
  @override
  List<Object?> get fields => [id, openState, direction, nativeState];

  /// Copies this value with selected fields replaced.
  FoldInfo copyWith({
    Object? id = _keep,
    DataValue<FoldState>? openState,
    AreaDirection? direction,
    Object? nativeState = _keep,
  }) => FoldInfo(
    id: identical(id, _keep) ? this.id : id as String?,
    openState: openState ?? this.openState,
    direction: direction ?? this.direction,
    nativeState: identical(nativeState, _keep)
        ? this.nativeState
        : nativeState as String?,
  );
}

/// One hinge angle in degrees; a fold identifier may be unavailable.
class FoldAngle extends InfoModel {
  /// Creates this measurement value.
  FoldAngle({this.foldId, required this.degrees}) {
    if (!degrees.isFinite) throw ArgumentError('Invalid degrees');
  }

  /// Optional link to a reported fold; never infer it from list position.
  final String? foldId;

  /// Finite hinge angle in degrees, using the platform's angle convention.
  final double degrees;
  @override
  List<Object?> get fields => [foldId, degrees];

  /// Copies this value with selected fields replaced.
  FoldAngle copyWith({Object? foldId = _keep, double? degrees}) => FoldAngle(
    foldId: identical(foldId, _keep) ? this.foldId : foldId as String?,
    degrees: degrees ?? this.degrees,
  );
}

/// Additional public UIKit layout hints with independent availability.
class IosInfo extends InfoModel {
  /// Creates this measurement value.
  IosInfo({
    required this.widthClass,
    required this.heightClass,
    required this.barSide,
    required this.safeArea,
  }) {
    if (safeArea.isReady) _insets(safeArea.value!);
  }

  /// UIKit horizontal size class.
  final DataValue<IosSize> widthClass;

  /// UIKit vertical size class.
  final DataValue<IosSize> heightClass;

  /// UIKit logical vertical bar edge; does not prove a toolbar is visible.
  final DataValue<BarSide> barSide;

  /// Native safe area in logical pixels.
  final DataValue<EdgeInsets> safeArea;
  @override
  List<Object?> get fields => [widthClass, heightClass, barSide, safeArea];

  /// Copies this value with selected fields replaced.
  IosInfo copyWith({
    DataValue<IosSize>? widthClass,
    DataValue<IosSize>? heightClass,
    DataValue<BarSide>? barSide,
    DataValue<EdgeInsets>? safeArea,
  }) => IosInfo(
    widthClass: widthClass ?? this.widthClass,
    heightClass: heightClass ?? this.heightClass,
    barSide: barSide ?? this.barSide,
    safeArea: safeArea ?? this.safeArea,
  );
}

/// Immutable layout data for one view and observation session.
class FoldableData extends InfoModel {
  /// Creates this measurement value.
  FoldableData({
    required this.viewId,
    required this.sessionId,
    required this.revision,
    required this.viewState,
    required this.view,
    required this.isFoldable,
    required DataValue<List<ViewArea>> areas,
    required DataValue<List<FoldInfo>> folds,
    required this.ios,
    this.error,
  }) : areas = _list(areas),
       folds = _list(folds) {
    if (sessionId.isEmpty || revision < 0) {
      throw ArgumentError('Invalid session or counter');
    }
  }

  /// Opaque, engine-local Flutter view identifier.
  final int viewId;

  /// Observation session identifier; counters are comparable only within it.
  final String sessionId;

  /// Layout revision; timestamps alone do not advance it.
  final int revision;

  /// Attachment/lifecycle state of this view.
  final ViewState viewState;

  /// Current view metrics, independent from native fold availability.
  final DataValue<ViewInfo> view;

  /// Foldability evidence; unknown is distinct from false.
  final DataValue<bool> isFoldable;

  /// Measured areas, including inactive reserved regions; list is immutable.
  final DataValue<List<ViewArea>> areas;

  /// Reported folds; list is immutable.
  final DataValue<List<FoldInfo>> folds;

  /// iOS layout hints; unsupported on other platforms.
  final DataValue<IosInfo> ios;

  /// Latest failure, cleared by a successful measurement.
  final FoldableError? error;
  @override
  List<Object?> get fields => [
    viewId,
    sessionId,
    revision,
    viewState,
    view,
    isFoldable,
    areas,
    folds,
    ios,
    error,
  ];

  /// Copies this value with selected fields replaced.
  FoldableData copyWith({
    int? viewId,
    String? sessionId,
    int? revision,
    ViewState? viewState,
    DataValue<ViewInfo>? view,
    DataValue<bool>? isFoldable,
    DataValue<List<ViewArea>>? areas,
    DataValue<List<FoldInfo>>? folds,
    DataValue<IosInfo>? ios,
    Object? error = _keep,
  }) => FoldableData(
    viewId: viewId ?? this.viewId,
    sessionId: sessionId ?? this.sessionId,
    revision: revision ?? this.revision,
    viewState: viewState ?? this.viewState,
    view: view ?? this.view,
    isFoldable: isFoldable ?? this.isFoldable,
    areas: areas ?? this.areas,
    folds: folds ?? this.folds,
    ios: ios ?? this.ios,
    error: identical(error, _keep) ? this.error : error as FoldableError?,
  );
}

/// Angle data kept separate from layout updates.
class FoldAngles extends InfoModel {
  /// Creates this measurement value.
  FoldAngles({
    required this.viewId,
    required this.sessionId,
    required this.sequence,
    required DataValue<List<FoldAngle>> angles,
    this.error,
  }) : angles = _list(angles) {
    if (sessionId.isEmpty || sequence < 0) {
      throw ArgumentError('Invalid session or counter');
    }
  }

  /// Opaque, engine-local Flutter view identifier.
  final int viewId;

  /// Observation session identifier; counters are comparable only within it.
  final String sessionId;

  /// Angle update counter within the current session.
  final int sequence;

  /// Reported hinge angles; list is immutable.
  final DataValue<List<FoldAngle>> angles;

  /// Latest failure, cleared by a successful measurement.
  final FoldableError? error;
  @override
  List<Object?> get fields => [viewId, sessionId, sequence, angles, error];

  /// Copies this value with selected fields replaced.
  FoldAngles copyWith({
    int? viewId,
    String? sessionId,
    int? sequence,
    DataValue<List<FoldAngle>>? angles,
    Object? error = _keep,
  }) => FoldAngles(
    viewId: viewId ?? this.viewId,
    sessionId: sessionId ?? this.sessionId,
    sequence: sequence ?? this.sequence,
    angles: angles ?? this.angles,
    error: identical(error, _keep) ? this.error : error as FoldableError?,
  );
}

/// View areas clipped and converted into a laid-out widget box.
class LocalAreas extends InfoModel {
  /// Creates this measurement value.
  LocalAreas({
    required this.state,
    this.size,
    required List<ViewArea> areas,
    required this.sessionId,
    required this.revision,
  }) : areas = List<ViewArea>.unmodifiable(areas);

  /// Availability of this value or conversion result.
  final LocalState state;

  /// Size in Flutter logical pixels.
  final Size? size;

  /// Measured areas, including inactive reserved regions; list is immutable.
  final List<ViewArea> areas;

  /// Observation session identifier; counters are comparable only within it.
  final String sessionId;

  /// Layout revision; timestamps alone do not advance it.
  final int revision;
  @override
  List<Object?> get fields => [state, size, areas, sessionId, revision];

  /// Copies this value with selected fields replaced.
  LocalAreas copyWith({
    LocalState? state,
    Object? size = _keep,
    List<ViewArea>? areas,
    String? sessionId,
    int? revision,
  }) => LocalAreas(
    state: state ?? this.state,
    size: identical(size, _keep) ? this.size : size as Size?,
    areas: areas ?? this.areas,
    sessionId: sessionId ?? this.sessionId,
    revision: revision ?? this.revision,
  );
}
