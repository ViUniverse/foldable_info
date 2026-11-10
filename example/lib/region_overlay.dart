import 'dart:ui' show FlutterView;
import 'package:flutter/material.dart';
import 'package:foldable_info/foldable_info.dart';

/// Paints native geometry over the actual application view, without taking taps.
class RegionOverlay extends StatelessWidget {
  const RegionOverlay({super.key, required this.data});
  final FoldableData data;

  @override
  Widget build(BuildContext context) {
    final boxKey = GlobalKey();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          key: boxKey,
          painter: _Regions(data, boxKey, View.of(context)),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Regions extends CustomPainter {
  _Regions(this.data, this.boxKey, this.view);
  final FoldableData data;
  final GlobalKey boxKey;
  final FlutterView view;

  @override
  void paint(Canvas canvas, Size size) {
    final target = boxKey.currentContext?.findRenderObject();
    if (target is! RenderBox) return;
    final local = FoldableSpace.toBox(data: data, target: target, view: view);
    if (local.state != LocalState.ready) return;
    final labels = <Rect>[];
    for (final area in local.areas) {
      final color = area.type == AreaType.blocked
          ? Colors.deepOrange
          : Colors.purple;
      final rect = area.rect;
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: area.isActive == false ? .07 : .25),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final text = TextPainter(
        text: TextSpan(
          text:
              '${area.type.name} · ${area.isActive == false ? "inactive" : "active/unknown"}\n'
              '${rect.width.toStringAsFixed(0)} × ${rect.height.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black,
            backgroundColor: Color(0xEEFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width.clamp(1, 240));
      final x = rect.left.clamp(
        0.0,
        (size.width - text.width).clamp(0.0, size.width),
      );
      var y = rect.top.clamp(
        0.0,
        (size.height - text.height).clamp(0.0, size.height),
      );
      for (final previous in labels) {
        if (previous.overlaps(Rect.fromLTWH(x, y, text.width, text.height))) {
          y = (previous.bottom + 4).clamp(
            0.0,
            (size.height - text.height).clamp(0.0, size.height),
          );
        }
      }
      text.paint(canvas, Offset(x, y));
      labels.add(Rect.fromLTWH(x, y, text.width, text.height));
    }
  }

  @override
  bool shouldRepaint(_Regions oldDelegate) => true;
}
