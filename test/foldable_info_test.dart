import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_info/foldable_info.dart';
import 'package:foldable_info/src/replay_feed.dart';
import 'package:foldable_info/src/view_metrics.dart';
import 'package:foldable_info/src/layout_comparison.dart';
import 'package:foldable_info/src/wire.dart';

final time = DateTime.utc(2026, 10, 10);
DataValue<T> ready<T>(T v) =>
    DataValue.ready(v, source: DataSource.ios, readAt: time);
FoldableData fixture(
  ui.FlutterView view, {
  int revision = 1,
  List<ViewArea> areas = const [],
}) => FoldableData(
  viewId: view.viewId,
  sessionId: 'test',
  revision: revision,
  viewState: ViewState.ready,
  view: ready(viewInfo(view)),
  isFoldable: DataValue.unknown(),
  areas: ready(areas),
  folds: ready([]),
  ios: DataValue.notSupported(),
);
ViewArea area(Rect r, {EdgeInsets? extra}) => ViewArea(
  type: AreaType.fold,
  rect: r,
  extraSpace: extra,
  direction: AreaDirection.topToBottom,
  cover: AreaCover.none,
  source: DataSource.ios,
);
Map<String, Object?> raw(
  ui.FlutterView view, {
  String session = 'native',
  int revision = 1,
  int? hinge = 3,
}) => {
  'version': 1,
  'viewId': view.viewId,
  'sessionId': session,
  'revision': revision,
  'size': {
    'width': viewInfo(view).size.width,
    'height': viewInfo(view).size.height,
  },
  'attached': true,
  'paused': false,
  'geometryValid': true,
  'regionsSupported': true,
  'areas': <Object>[],
  'hingeSupported': true,
  'hingeRead': true,
  'hingeState': hinge,
  'ios': {
    'widthClass': 2,
    'heightClass': 1,
    'barSupported': true,
    'barSide': 2,
    'safeArea': {'left': 0, 'top': 0, 'right': 84, 'bottom': 34},
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('default shortcuts share the implicit view and its streams', (
    t,
  ) async {
    final handle = FoldableInfo.instance.forView(t.view);
    expect(identical(FoldableInfo.watch(), handle.watch()), true);
    expect(identical(FoldableInfo.watchAngles(), handle.watchAngles()), true);
    final data = await FoldableInfo.read();
    expect(data.viewId, t.view.viewId);
    expect(data.view.value!.size, viewInfo(t.view).size);
    final angles = await FoldableInfo.readAngles();
    expect(angles.viewId, t.view.viewId);
    expect(angles.angles.state, DataState.notSupported);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
  testWidgets('invalid area group preserves valid view and hinge data', (
    t,
  ) async {
    final payload = raw(t.view)
      ..['areas'] = [
        {'rect': 'bad'},
      ];
    final data = decodeData(payload, t.view, false);
    expect(data.areas.state, DataState.error);
    expect(data.folds.value!.single.openState.value, FoldState.open);
    expect(data.ios.isReady, true);
    expect(data.view.isReady, true);
    expect(data.error!.code, ErrorCode.badData);
    final recovered = decodeData(raw(t.view), t.view, false);
    expect(recovered.error, isNull);
    expect(recovered.areas.isReady, true);
  });
  testWidgets(
    'unattached view is loading; unknown future traits stay unknown',
    (t) async {
      final payload = raw(t.view)..['attached'] = false;
      final data = decodeData(payload, t.view, false);
      expect(data.viewState, ViewState.loading);
      expect(data.areas.state, DataState.loading);
      expect(data.folds.state, DataState.loading);
      final future = raw(t.view, hinge: 99);
      (future['ios'] as Map)['widthClass'] = 99;
      final unknown = decodeData(future, t.view, false);
      expect(unknown.ios.value!.widthClass.state, DataState.unknown);
      expect(unknown.folds.value!.single.openState.state, DataState.unknown);
      expect(unknown.folds.value!.single.nativeState, '99');
    },
  );
  test(
    'copyWith preserves state invariants and supports explicit clearing',
    () {
      expect(ready(1).copyWith(state: DataState.loading).value, isNull);
      expect(ready(1).copyWith(state: DataState.loading).readAt, isNull);
      expect(() => ready(1).copyWith(value: null), throwsArgumentError);
      expect(
        () => DataValue<int>.loading().copyWith(state: DataState.ready),
        throwsArgumentError,
      );
      const failure = FoldableError(ErrorCode.timeout, 'timeout');
      expect(
        DataValue<int>.error(failure).copyWith(state: DataState.loading).error,
        isNull,
      );
      expect(failure.copyWith(message: 'retry').message, 'retry');
    },
  );
  test('ready values reject ambiguous values and preserve UTC', () {
    expect(
      () => DataValue.ready(null, source: DataSource.ios, readAt: time),
      throwsArgumentError,
    );
    expect(
      () => DataValue.ready(1, source: DataSource.unknown, readAt: time),
      throwsArgumentError,
    );
    expect(
      () => DataValue.ready(1, source: DataSource.ios, readAt: DateTime(2026)),
      throwsArgumentError,
    );
    expect(DataValue<bool>.unknown().value, isNull);
    expect(ready(false).value, false);
  });
  test('replay is shared, cancellation belongs to each listener', () async {
    var starts = 0, stops = 0;
    final feed = ReplayFeed(1, start: () => starts++, stop: () => stops++);
    final a = <int>[], b = <int>[];
    final first = feed.stream.listen(a.add);
    await Future<void>.delayed(Duration.zero);
    feed.add(2);
    final second = feed.stream.listen(b.add);
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    expect(b, [2]);
    await first.cancel();
    expect(stops, 0);
    feed.add(3);
    await Future<void>.delayed(Duration.zero);
    expect(a, [1, 2]);
    expect(b, [2, 3]);
    await second.cancel();
    expect(stops, 1);
  });
  testWidgets(
    'models freeze lists, copy clears nullable data, hash matches equality',
    (t) async {
      final list = [area(const Rect.fromLTWH(100, 0, 0, 400))];
      final a = fixture(t.view, areas: list), b = fixture(t.view, areas: list);
      list.clear();
      expect(a.areas.value!.length, 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(() => a.areas.value!.clear(), throwsUnsupportedError);
      expect(
        a.areas.value!.single.copyWith(id: 'x').copyWith(id: null).id,
        isNull,
      );
      expect(() => FoldAngle(degrees: double.nan), throwsArgumentError);
    },
  );
  testWidgets(
    'unknown hardware differs from false; native state is not angle threshold',
    (t) async {
      final r = raw(t.view, hinge: null);
      final a = decodeData(r, t.view, false);
      expect(a.isFoldable.state, DataState.unknown);
      expect(a.folds.state, DataState.notAvailable);
      final b = decodeData(raw(t.view, hinge: 2), t.view, false);
      expect(b.isFoldable.value, true);
      expect(b.folds.value!.single.openState.value, FoldState.partlyOpen);
      expect(b.ios.value!.barSide.value, BarSide.end);
    },
  );
  testWidgets(
    'old iOS has traits and safe area but fold APIs are unsupported',
    (t) async {
      final r = raw(t.view)
        ..['regionsSupported'] = false
        ..['hingeSupported'] = false
        ..['hingeState'] = null;
      (r['ios'] as Map)['barSupported'] = false;
      final d = decodeData(r, t.view, false);
      expect(d.areas.state, DataState.notSupported);
      expect(d.folds.state, DataState.notSupported);
      expect(d.ios.value!.safeArea.value!.right, 84);
      expect(d.ios.value!.barSide.state, DataState.notSupported);
    },
  );
  testWidgets(
    'snapshot after resize or host transform invalidates native geometry',
    (t) async {
      final r = raw(t.view);
      r['size'] = {'width': 1, 'height': 1};
      expect(decodeData(r, t.view, false).areas.state, DataState.loading);
      r['size'] = (raw(t.view)['size']);
      r['geometryValid'] = false;
      expect(decodeData(r, t.view, false).areas.state, DataState.loading);
      expect(decodeData(raw(t.view), t.view, true).viewState, ViewState.paused);
    },
  );
  testWidgets(
    'native margins are kept once, inactive division remains in data',
    (t) async {
      final r = raw(t.view);
      r['areas'] = [
        {
          'id': 'hinge',
          'nativeType': 'division',
          'rect': {'x': 100, 'y': 0, 'width': 40, 'height': 400},
          'extraSpace': {'left': 20, 'top': 0, 'right': 20, 'bottom': 0},
          'active': false,
        },
      ];
      final a = decodeData(r, t.view, false).areas.value!.single;
      expect(a.rect.width, 40);
      expect(a.extraSpace!.left, 20);
      expect(a.isActive, false);
      final later = decodeData(r, t.view, false);
      expect(sameLayout(later, decodeData(r, t.view, false)), true);
      expect(
        () => checkWire({...r, 'version': 2}, t.view.viewId),
        throwsA(isA<FoldableError>()),
      );
      expect(
        () => checkWire({...r, 'viewId': 99}, t.view.viewId),
        throwsA(isA<FoldableError>()),
      );
    },
  );
  for (final ratio in [1.0, 3.0]) {
    testWidgets(
      'projection preserves logical coordinates at pixel ratio $ratio',
      (t) async {
        t.view.physicalSize = const Size(400, 400) * ratio;
        t.view.devicePixelRatio = ratio;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 50, top: 30),
                child: Transform.scale(
                  scale: 2,
                  alignment: Alignment.topLeft,
                  child: SizedBox(key: key, width: 100, height: 100),
                ),
              ),
            ),
          ),
        );
        final box = key.currentContext!.findRenderObject()! as RenderBox;
        final data = fixture(
          t.view,
          areas: [
            area(const Rect.fromLTWH(150, 30, 0, 200)),
            area(
              const Rect.fromLTWH(50, 30, 40, 200),
              extra: const EdgeInsets.all(20),
            ),
            area(const Rect.fromLTWH(350, 0, 10, 10)),
          ],
        );
        final local = FoldableSpace.toBox(
          data: data,
          target: box,
          view: t.view,
        );
        expect(local.state, LocalState.ready);
        expect(local.areas.length, 2);
        expect(local.areas.first.rect, const Rect.fromLTWH(50, 0, 0, 100));
        expect(local.areas[1].rect.width, 20);
        expect(local.areas[1].extraSpace!.left, 10);
        expect(
          () => FoldableSpace.toBox(
            data: data.copyWith(viewId: 99),
            target: box,
            view: t.view,
          ),
          throwsArgumentError,
        );
      },
    );
  }
  testWidgets('projection rejects skew/reflection and stale size', (t) async {
    final key = GlobalKey();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Transform.rotate(
          angle: .4,
          child: SizedBox(key: key, width: 100, height: 100),
        ),
      ),
    );
    final box = key.currentContext!.findRenderObject()! as RenderBox,
        d = fixture(t.view);
    expect(
      FoldableSpace.toBox(data: d, target: box, view: t.view).state,
      LocalState.badTransform,
    );
    expect(
      FoldableSpace.toBox(
        data: d.copyWith(
          view: ready(d.view.value!.copyWith(size: const Size(1, 1))),
        ),
        target: box,
        view: t.view,
      ).state,
      LocalState.oldData,
    );
  });
  testWidgets('Flutter fallback keeps revision until view data changes', (
    t,
  ) async {
    final handle = FoldableInfo.instance.forView(t.view);
    final first = await handle.read();
    final repeated = await handle.read();
    expect(repeated.revision, first.revision);
    t.view.physicalSize = const Size(900, 700);
    addTearDown(t.view.resetPhysicalSize);
    final resized = await handle.read();
    expect(resized.revision, first.revision + 1);
    expect((await handle.read()).revision, resized.revision);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
  testWidgets('native reads fail clearly and streams reject old snapshots', (
    t,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final handle = FoldableInfo.instance.forView(t.view);
    messenger.setMockMethodCallHandler(
      const MethodChannel('foldable_info/methods'),
      (call) async => raw(t.view),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('foldable_info/methods'),
        null,
      ),
    );
    final a = await FoldableInfo.read();
    expect(a.folds.value!.single.openState.value, FoldState.open);
    messenger.setMockMethodCallHandler(
      const MethodChannel('foldable_info/methods'),
      (call) async => raw(t.view, revision: 0, hinge: 1),
    );
    expect(
      (await handle.read()).folds.value!.single.openState.value,
      FoldState.open,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('foldable_info/methods'),
      (call) async => {...raw(t.view), 'version': 2},
    );
    await expectLater(
      FoldableInfo.read(),
      throwsA(
        isA<FoldableError>().having(
          (e) => e.code,
          'code',
          ErrorCode.badVersion,
        ),
      ),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('foldable_info/methods'),
      (call) => Completer<Object?>().future,
    );
    await t.runAsync(
      () => expectLater(
        FoldableInfo.read(timeout: const Duration(milliseconds: 2)),
        throwsA(
          isA<FoldableError>().having((e) => e.code, 'code', ErrorCode.timeout),
        ),
      ),
    );
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('angle-only reads reject retired sessions and older counters', (
    t,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('foldable_info/methods');
    var session = 'angle-first', sequence = 1, degrees = 60.0;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'version': 1,
        'viewId': t.view.viewId,
        'sessionId': session,
        'sequence': sequence,
        'attached': true,
        'paused': false,
        'state': 'ready',
        'degrees': degrees,
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final handle = FoldableInfo.instance.forView(t.view);
    expect((await handle.readAngles()).angles.value!.single.degrees, 60);
    session = 'angle-next';
    degrees = 128;
    expect((await handle.readAngles()).angles.value!.single.degrees, 128);
    session = 'angle-first';
    sequence = 99;
    degrees = 5;
    expect((await handle.readAngles()).sessionId, 'angle-next');
    expect((await handle.readAngles()).angles.value!.single.degrees, 128);
    session = 'angle-next';
    sequence = 0;
    expect((await handle.readAngles()).angles.value!.single.degrees, 128);
    sequence = 2;
    degrees = 180;
    expect((await handle.readAngles()).angles.value!.single.degrees, 180);
    debugDefaultTargetPlatformOverride = null;
  });
}
