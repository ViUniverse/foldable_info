import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_info/foldable_info.dart';
import 'package:foldable_info/src/view_metrics.dart';
import 'package:foldable_info/src/wire.dart';

Map<String, Object?> androidRaw(WidgetTester t) => {
  'version': 1,
  'platform': 'android',
  'viewId': t.view.viewId,
  'sessionId': 'android',
  'revision': 1,
  'attached': true,
  'paused': false,
  'geometryValid': true,
  'pixelRatio': t.view.devicePixelRatio,
  'size': {
    'width': viewInfo(t.view).size.width,
    'height': viewInfo(t.view).size.height,
  },
  'layoutRead': true,
  'hasHingeSensor': false,
  'hasFoldFeature': true,
  'features': [
    {
      'id': 'fold-0',
      'type': 'fold',
      'rect': {'x': 100, 'y': 0, 'width': 0, 'height': 200},
      'direction': 'topToBottom',
      'cover': 'none',
      'splitsView': true,
      'openState': 'partlyOpen',
      'nativeState': 'HALF_OPENED',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Android preserves posture, separation, source and links',
    (t) async {
      final d = decodeData(androidRaw(t), t.view, false);
      final a = d.areas.value!.single, f = d.folds.value!.single;
      expect(d.view.source, DataSource.flutter);
      expect(d.ios.state, DataState.notSupported);
      expect(a.source, DataSource.android);
      expect(a.rect.width, 0);
      expect(a.foldId, f.id);
      expect(a.splitsView, true);
      expect(a.cover, AreaCover.none);
      expect(f.openState.value, FoldState.partlyOpen);
      expect(f.nativeState, 'HALF_OPENED');
      expect(d.isFoldable.value, true);
    },
  );
  testWidgets('empty window is not proof of non-foldable hardware', (t) async {
    final r = androidRaw(t)
      ..['features'] = []
      ..['hasFoldFeature'] = false;
    expect(decodeData(r, t.view, false).isFoldable.state, DataState.unknown);
    r['hasHingeSensor'] = true;
    final d = decodeData(r, t.view, false);
    expect(d.isFoldable.value, true);
    expect(d.folds.value, isEmpty);
  });
  testWidgets('Android resize, pixel ratio and pause invalidate geometry', (
    t,
  ) async {
    final r = androidRaw(t)..['pixelRatio'] = 99;
    expect(decodeData(r, t.view, false).areas.state, DataState.loading);
    r['pixelRatio'] = t.view.devicePixelRatio;
    r['size'] = {'width': 1, 'height': 1};
    expect(decodeData(r, t.view, false).areas.state, DataState.loading);
    expect(decodeData(r, t.view, true).areas.state, DataState.notAvailable);
    expect(decodeData(androidRaw(t), t.view, true).viewState, ViewState.paused);
  });
  testWidgets('malformed Android group retains metrics and hardware evidence', (
    t,
  ) async {
    final r = androidRaw(t)
      ..['features'] = [
        {'rect': 'bad'},
      ];
    final d = decodeData(r, t.view, false);
    expect(d.areas.state, DataState.error);
    expect(d.folds.state, DataState.error);
    expect(d.view.isReady, true);
    expect(d.isFoldable.value, true);
    expect(d.error!.code, ErrorCode.badData);
    expect(decodeData(androidRaw(t), t.view, false).error, isNull);
  });
  testWidgets('unknown future Android state is not inferred from angle', (
    t,
  ) async {
    final r = androidRaw(t);
    (r['features'] as List).single['openState'] = 'future';
    final d = decodeData(r, t.view, false);
    expect(d.folds.value!.single.openState.state, DataState.unknown);
    final a = decodeAngles({
      'platform': 'android',
      'viewId': t.view.viewId,
      'sessionId': 'android',
      'sequence': 1,
      'attached': true,
      'paused': false,
      'state': 'ready',
      'degrees': 0,
    }, false);
    expect(a.angles.source, DataSource.android);
    expect(a.angles.value!.single.foldId, isNull);
    expect(a.angles.value!.single.degrees, 0);
    expect(d.folds.value!.single.openState.state, DataState.unknown);
  });
  testWidgets(
    'Android direct methods use bridge; a missing plugin is explicit',
    (t) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('foldable_info/methods');
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'read'
            ? androidRaw(t)
            : {
                'version': 1,
                'platform': 'android',
                'viewId': t.view.viewId,
                'sessionId': 'android-angle',
                'sequence': 1,
                'attached': true,
                'paused': false,
                'state': 'notSupported',
              },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(
        (await FoldableInfo.read()).folds.value!.single.openState.source,
        DataSource.android,
      );
      expect(
        (await FoldableInfo.readAngles()).angles.state,
        DataState.notSupported,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw MissingPluginException(),
      );
      await expectLater(
        FoldableInfo.read(),
        throwsA(
          isA<FoldableError>().having(
            (e) => e.code,
            'code',
            ErrorCode.noPlugin,
          ),
        ),
      );
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
