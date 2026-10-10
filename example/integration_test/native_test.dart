import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:foldable_info/foldable_info.dart';
import 'package:foldable_info_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native reads, shared observation, cancellation, and view errors', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: SizedBox(key: key)));
    await tester.pumpAndSettle();
    final view = View.of(key.currentContext!);
    final handle = FoldableInfo.instance.forView(view);
    expect(identical(handle, FoldableInfo.instance.forView(view)), true);
    expect(identical(handle.watch(), FoldableInfo.watch()), true);
    expect(identical(handle.watchAngles(), FoldableInfo.watchAngles()), true);
    final data = await FoldableInfo.read();
    expect(data.viewState, ViewState.ready);
    expect(data.view.value!.size, view.physicalSize / view.devicePixelRatio);
    expect(data.ios.isReady, true);
    final samples = <FoldableData>[];
    final first = FoldableInfo.watch().listen(samples.add);
    final second = handle.watch().listen((_) {});
    final shared = await handle.read();
    await first.cancel();
    final afterOneCancel = await handle.read();
    expect(afterOneCancel.sessionId, shared.sessionId);
    final angleSamples = <FoldAngles>[];
    final angleSubscription = FoldableInfo.watchAngles().listen(
      angleSamples.add,
    );
    final angles = await FoldableInfo.readAngles();
    expect(angleSamples, isNotEmpty);
    expect(angleSamples.every((sample) => sample.viewId == view.viewId), true);
    if (angles.angles.isReady) {
      expect(angles.angles.value!.single.degrees, inInclusiveRange(0, 360));
      expect(afterOneCancel.folds.isReady, true);
    } else {
      expect(
        angles.angles.state,
        isIn([
          DataState.notSupported,
          DataState.notAvailable,
          DataState.loading,
        ]),
      );
    }
    await angleSubscription.cancel();
    expect((await FoldableInfo.read()).sessionId, shared.sessionId);
    await second.cancel();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    final next = await handle.read();
    expect(next.sessionId, isNot(shared.sessionId));
    await expectLater(
      const MethodChannel(
        'foldable_info/methods',
      ).invokeMethod<Object?>('read', {'viewId': 999}),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'noView')),
    );
    final recovery = await handle.read();
    expect(recovery.viewState, ViewState.ready);
    debugPrint(
      'NATIVE_CHECK size=${recovery.view.value!.size} areas=${recovery.areas.state.name} folds=${recovery.folds.state.name} angle=${angles.angles.state.name} sessionChanges=true',
    );
  });
  testWidgets('example can mount, watch angles and unmount', (tester) async {
    await tester.pumpWidget(const FoldableApp());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('View: ready'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Angle:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
