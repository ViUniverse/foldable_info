import 'package:flutter/widgets.dart';
import 'models.dart';
import 'space.dart';

/// Keeps a child in the largest rectangular part of its box clear of measured
/// obstacles. Equal-sized choices prefer the top, then the leading side.
///
/// Supply live snapshots (for example from StreamBuilder). Both constraints
/// must be bounded. SafeArea is applied first by default, so ancestor-consumed
/// padding is not added twice. Only intersecting, active or activity-unknown
/// areas of [avoid] are considered; margins are never added to their frames.
///
/// Geometry is measured after layout, including ancestor offsets/scale. The
/// child is hidden until the first measurement and settles on the next frame.
/// Later ancestor movement is remeasured after each rendered frame. Unsupported
/// transforms, stale or unavailable data fall back to SafeArea alone. This is a
/// single-region container, not a two-pane layout or a general packing widget.
class FoldableSafeArea extends StatefulWidget {
  /// Creates a container driven by a snapshot for the current Flutter view.
  const FoldableSafeArea({
    super.key,
    required this.data,
    required this.child,
    this.avoid = const {AreaType.blocked, AreaType.hinge},
    this.useSafeArea = true,
  });

  /// Latest native/view snapshot; must belong to this widget's Flutter view.
  final FoldableData data;

  /// Content placed inside the chosen free rectangle.
  final Widget child;

  /// Types to avoid. Include AreaType.fold to keep content on one side of a fold.
  final Set<AreaType> avoid;

  /// Whether to consume Flutter safe padding before measuring reserved regions.
  final bool useSafeArea;

  @override
  State<FoldableSafeArea> createState() => _FoldableSafeAreaState();
}

class _FoldableSafeAreaState extends State<FoldableSafeArea> {
  final _box = GlobalKey();
  EdgeInsets _padding = EdgeInsets.zero;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final target = _box.currentContext?.findRenderObject();
    if (target is RenderBox && target.hasSize) {
      final local = FoldableSpace.toBox(
        data: widget.data,
        target: target,
        view: View.of(context),
      );
      final bounds = Offset.zero & target.size;
      final obstacles = local.state == LocalState.ready
          ? local.areas
                .where(
                  (a) => widget.avoid.contains(a.type) && a.isActive != false,
                )
                .map((a) => a.rect)
                .toList()
          : <Rect>[];
      final free = largestFreeRect(
        bounds,
        obstacles,
        rtl: Directionality.of(context) == TextDirection.rtl,
      );
      final padding = EdgeInsets.fromLTRB(
        free.left,
        free.top,
        bounds.right - free.right,
        bounds.bottom - free.bottom,
      );
      if (!_measured || padding != _padding) {
        setState(() {
          _padding = padding;
          _measured = true;
        });
      }
    }
    // Does not request frames when the application is idle.
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  Widget build(BuildContext context) {
    Widget result = LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          throw FlutterError(
            'FoldableSafeArea needs bounded width and height. '
            'Use Expanded or SizedBox inside a scroll view.',
          );
        }
        return SizedBox.expand(
          key: _box,
          child: Opacity(
            opacity: _measured ? 1 : 0,
            child: ExcludeSemantics(
              excluding: !_measured,
              child: IgnorePointer(
                ignoring: !_measured,
                child: Padding(
                  padding: _padding,
                  child: ClipRect(child: widget.child),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (widget.useSafeArea) result = SafeArea(child: result);
    return result;
  }
}

// Every maximal empty axis-aligned rectangle has edges on the box or obstacle
// edges. Enumerating these candidates also preserves zero-width fold lines.
Rect largestFreeRect(Rect bounds, List<Rect> obstacles, {bool rtl = false}) {
  if (obstacles.isEmpty) return bounds;
  final xs = {
    bounds.left,
    bounds.right,
    ...obstacles.expand((r) => [r.left, r.right]),
  }.toList()..sort();
  final ys = {
    bounds.top,
    bounds.bottom,
    ...obstacles.expand((r) => [r.top, r.bottom]),
  }.toList()..sort();
  var best = Rect.fromLTWH(rtl ? bounds.right : bounds.left, bounds.top, 0, 0);
  var bestArea = 0.0;
  for (var l = 0; l < xs.length - 1; l++) {
    for (var r = l + 1; r < xs.length; r++) {
      for (var t = 0; t < ys.length - 1; t++) {
        for (var b = t + 1; b < ys.length; b++) {
          final candidate = Rect.fromLTRB(xs[l], ys[t], xs[r], ys[b]);
          final blocked = obstacles.any(
            (o) =>
                candidate.left < o.right &&
                candidate.right > o.left &&
                candidate.top < o.bottom &&
                candidate.bottom > o.top,
          );
          if (blocked) continue;
          final area = candidate.width * candidate.height;
          if (area > bestArea ||
              (area == bestArea &&
                  (candidate.top < best.top ||
                      (candidate.top == best.top &&
                          (rtl
                              ? candidate.right > best.right
                              : candidate.left < best.left))))) {
            best = candidate;
            bestArea = area;
          }
        }
      }
    }
  }
  return best;
}
