import 'dart:ui' show FlutterView, ViewPadding;
import 'package:flutter/material.dart';
import 'package:foldable_info/foldable_info.dart';

/// Example-only geometry choices; these never claim a measured device pose.
enum RecipePreview { live, book, tabletop, noFold }

FoldableData? recipeData(
  FlutterView view,
  FoldableData? live,
  RecipePreview mode,
) {
  if (mode == RecipePreview.live) return live;
  final dpr = view.devicePixelRatio;
  final size = view.physicalSize / dpr;
  final now = DateTime.now().toUtc();
  DataValue<T> ready<T>(T value) =>
      DataValue.ready(value, source: DataSource.calculated, readAt: now);
  EdgeInsets insets(ViewPadding p) => EdgeInsets.fromLTRB(
    p.left / dpr,
    p.top / dpr,
    p.right / dpr,
    p.bottom / dpr,
  );
  final hasFold = mode != RecipePreview.noFold;
  final vertical = mode == RecipePreview.book;
  final areas = hasFold
      ? [
          ViewArea(
            type: AreaType.fold,
            rect: vertical
                ? Rect.fromLTWH(size.width / 2 - 12, 0, 24, size.height)
                : Rect.fromLTWH(0, size.height / 2 - 12, size.width, 24),
            isActive: true,
            splitsView: true,
            direction: vertical
                ? AreaDirection.topToBottom
                : AreaDirection.leftToRight,
            cover: AreaCover.none,
            source: DataSource.calculated,
          ),
        ]
      : <ViewArea>[];
  return FoldableData(
    viewId: view.viewId,
    sessionId: 'illustrative-${mode.name}',
    revision: 0,
    viewState: ViewState.ready,
    view: ready(
      ViewInfo(
        size: size,
        pixelRatio: dpr,
        padding: insets(view.viewPadding),
        insets: insets(view.viewInsets),
        gestureInsets: insets(view.systemGestureInsets),
      ),
    ),
    isFoldable: hasFold ? ready(true) : DataValue.unknown(),
    areas: ready(areas),
    folds: ready(
      hasFold
          ? [
              FoldInfo(
                openState: ready(FoldState.partlyOpen),
                direction: areas.single.direction,
              ),
            ]
          : [],
    ),
    ios: DataValue.notSupported(),
  );
}

// Keep app state mounted while native data loads or fails. Only Flutter view
// metrics are measured here; unavailable native groups are never ready-empty.
FoldableData unavailableRecipeData(FlutterView view, {required bool failed}) {
  final metrics = recipeData(view, null, RecipePreview.noFold)!;
  const error = FoldableError(
    ErrorCode.nativeError,
    'Example geometry stream failed',
  );
  return metrics.copyWith(
    sessionId: 'example-unavailable',
    view: metrics.view.copyWith(source: DataSource.flutter),
    areas: failed ? DataValue.error(error) : DataValue.loading(),
    folds: failed ? DataValue.error(error) : DataValue.loading(),
    ios: DataValue.unknown(),
    error: failed ? error : null,
  );
}

typedef PaneSplit = ({Rect first, Rect second, bool vertical});

/// Split only when a reported separating region spans this entire local box.
/// Margins are already in rect. A zero-width fold still divides the box.
PaneSplit? recipeSplit(
  Size size,
  Iterable<ViewArea> areas,
  FoldState? posture, {
  double minimumExtent = 120,
}) {
  for (final area in areas) {
    if (area.isActive == false ||
        (area.type != AreaType.fold && area.type != AreaType.hinge)) {
      continue;
    }
    if (area.type == AreaType.fold &&
        area.splitsView != true &&
        posture != FoldState.partlyOpen) {
      continue;
    }
    final r = area.rect;
    final vertical =
        area.direction == AreaDirection.topToBottom ||
        (area.direction == AreaDirection.unknown && r.height > r.width);
    if (vertical &&
        r.top <= .5 &&
        r.bottom >= size.height - .5 &&
        r.left >= minimumExtent &&
        size.width - r.right >= minimumExtent) {
      return (
        first: Rect.fromLTRB(0, 0, r.left, size.height),
        second: Rect.fromLTRB(r.right, 0, size.width, size.height),
        vertical: true,
      );
    }
    if (!vertical &&
        r.left <= .5 &&
        r.right >= size.width - .5 &&
        r.top >= minimumExtent &&
        size.height - r.bottom >= minimumExtent) {
      return (
        first: Rect.fromLTRB(0, 0, size.width, r.top),
        second: Rect.fromLTRB(0, r.bottom, size.width, size.height),
        vertical: false,
      );
    }
  }
  return null;
}

/// Measures the bounded recipe canvas after layout, not the screen's center.
/// Rechecks every rendered frame so scrolling/ancestor movement is respected.
class RecipeGeometry extends StatefulWidget {
  const RecipeGeometry({super.key, required this.data, required this.builder});
  final FoldableData data;
  final Widget Function(BuildContext, LocalAreas?) builder;
  @override
  State<RecipeGeometry> createState() => _RecipeGeometryState();
}

class _RecipeGeometryState extends State<RecipeGeometry> {
  final _box = GlobalKey();
  LocalAreas? _local;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final box = _box.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final local = FoldableSpace.toBox(
        data: widget.data,
        target: box,
        view: View.of(context),
      );
      if (local != _local) setState(() => _local = local);
    }
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(key: _box, child: widget.builder(context, _local));
}

PaneSplit? splitFor(
  BuildContext context,
  LocalAreas? local,
  FoldableData data,
) {
  if (local?.state != LocalState.ready) return null;
  final posture = data.folds.value?.firstOrNull?.openState.value;
  final split = recipeSplit(
    local!.size!,
    local.areas,
    posture,
    minimumExtent: MediaQuery.textScalerOf(context).scale(120),
  );
  if (split == null ||
      !split.vertical ||
      Directionality.of(context) != TextDirection.rtl) {
    return split;
  }
  return (first: split.second, second: split.first, vertical: true);
}

/// Fixed child slots retain text, selection and scroll state when rectangles move.
class RecipePanes extends StatelessWidget {
  const RecipePanes({
    super.key,
    required this.data,
    required this.first,
    required this.second,
    required this.firstRect,
    required this.secondRect,
    this.showFirst = true,
    this.showSecond = true,
  });
  final FoldableData data;
  final Widget first, second;
  final Rect firstRect, secondRect;
  final bool showFirst, showSecond;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fromRect(
        rect: firstRect,
        child: ExcludeFocus(
          excluding: !showFirst,
          child: Offstage(
            offstage: !showFirst,
            child: FoldableSafeArea(
              data: data,
              useSafeArea: false,
              avoid: const {AreaType.blocked, AreaType.hinge, AreaType.fold},
              child: first,
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: secondRect,
        child: ExcludeFocus(
          excluding: !showSecond,
          child: Offstage(
            offstage: !showSecond,
            child: FoldableSafeArea(
              data: data,
              useSafeArea: false,
              avoid: const {AreaType.blocked, AreaType.hinge, AreaType.fold},
              child: second,
            ),
          ),
        ),
      ),
    ],
  );
}
