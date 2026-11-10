import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foldable_info_example/region_overlay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_info/foldable_info.dart';
import 'package:foldable_info/testing.dart';
import 'package:foldable_info_example/main.dart';

void main() {
  testWidgets('example displays loading, native errors and recovery', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final id = tester.view.viewId;
    final initial = FoldableData(
      viewId: id,
      sessionId: 'test',
      revision: 0,
      viewState: ViewState.loading,
      view: DataValue.loading(),
      isFoldable: DataValue.unknown(),
      areas: DataValue.loading(),
      folds: DataValue.loading(),
      ios: DataValue.loading(),
    );
    final fake = FakeFoldableInfo(views: {id: initial});
    addTearDown(fake.dispose);
    await tester.pumpWidget(FoldableApp(info: fake));
    await tester.pump();
    expect(find.text('View: loading'), findsOneWidget);
    expect(find.text('Foldable: unknown'), findsOneWidget);
    expect(find.byType(RegionOverlay), findsOneWidget);
    await tester.tap(find.byTooltip('Toggle region overlay'));
    await tester.pump();
    expect(find.byType(RegionOverlay), findsNothing);
    await tester.tap(find.byTooltip('Copy geometry snapshot'));
    await tester.pump();
    final dump = jsonDecode(copied!) as Map;
    expect(dump['viewId'], id);
    expect(dump['areasState'], 'loading');
    expect(dump['units'], 'logicalPixels');
    fake.sendError(
      viewId: id,
      error: const FoldableError(ErrorCode.nativeError, 'test failure'),
    );
    await tester.pump();
    expect(find.textContaining('Read error:'), findsOneWidget);
    fake.sendData(initial.copyWith(revision: 2));
    await tester.pump();
    expect(find.textContaining('Read error:'), findsNothing);
    expect(find.text('View: loading'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Angle: loading'), findsOneWidget);
    fake.sendAngles(
      FoldAngles(
        viewId: id,
        sessionId: 'test',
        sequence: 1,
        angles: DataValue.ready(
          [FoldAngle(degrees: 128)],
          source: DataSource.ios,
          readAt: DateTime.utc(2026),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Angle: 128.0°'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.textContaining('Angle:'), findsNothing);
  });
}
