import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_info/foldable_info.dart';
import 'foldable_info_test.dart' show fixture;

ViewArea obstacle(
  Rect rect, {
  bool active = true,
  AreaType type = AreaType.blocked,
}) => ViewArea(
  type: type,
  rect: rect,
  extraSpace: const EdgeInsets.all(20),
  isActive: active,
  direction: AreaDirection.unknown,
  cover: AreaCover.unknown,
  source: DataSource.ios,
);

void main() {
  testWidgets(
    'avoids frame once, preserves taps/state, ignores inactive regions',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(400, 600);
      addTearDown(t.view.reset);
      final key = GlobalKey();
      var taps = 0;
      Future<void> show(List<ViewArea> areas) async {
        await t.pumpWidget(
          MaterialApp(
            home: FoldableSafeArea(
              data: fixture(t.view, areas: areas),
              child: SizedBox.expand(
                key: key,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Tap'),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await show([obstacle(const Rect.fromLTWH(316, 0, 84, 170))]);
      expect(t.getRect(find.byKey(key)), const Rect.fromLTWH(0, 0, 316, 600));
      await t.tap(find.text('Tap'));
      expect(taps, 1);
      await show([
        obstacle(const Rect.fromLTWH(316, 0, 84, 170), active: false),
      ]);
      expect(t.getSize(find.byKey(key)), const Size(400, 600));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('ancestor SafeArea and offset consume overlap only once', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(400, 600);
    t.view.padding = const FakeViewPadding(top: 30);
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        home: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 50),
            child: FoldableSafeArea(
              data: fixture(
                t.view,
                areas: [obstacle(const Rect.fromLTWH(0, 0, 84, 600))],
              ),
              child: SizedBox.expand(key: key),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.getRect(find.byKey(key)), const Rect.fromLTRB(84, 30, 400, 600));
  });
  testWidgets(
    'selected zero-width fold splits content; unavailable data falls back',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(400, 600);
      addTearDown(t.view.reset);
      final key = GlobalKey();
      final data = fixture(
        t.view,
        areas: [
          obstacle(const Rect.fromLTWH(200, 0, 0, 600), type: AreaType.fold),
        ],
      );
      Future<void> show(FoldableData data) async {
        await t.pumpWidget(
          MaterialApp(
            home: FoldableSafeArea(
              data: data,
              avoid: const {AreaType.fold},
              child: SizedBox.expand(key: key),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await show(data);
      expect(t.getRect(find.byKey(key)), const Rect.fromLTWH(0, 0, 200, 600));
      await show(data.copyWith(areas: DataValue.notSupported()));
      expect(t.getSize(find.byKey(key)), const Size(400, 600));
    },
  );
  testWidgets(
    'all overlapping occlusions are used, RTL ties and full coverage',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(400, 600);
      addTearDown(t.view.reset);
      final key = GlobalKey();
      Future<void> show(
        List<ViewArea> areas, {
        TextDirection direction = TextDirection.ltr,
      }) async {
        await t.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: FoldableSafeArea(
                data: fixture(t.view, areas: areas),
                avoid: const {AreaType.blocked, AreaType.fold},
                child: SizedBox.expand(key: key),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await show([
        obstacle(const Rect.fromLTWH(330, 30, 37, 37)),
        obstacle(const Rect.fromLTWH(316, 0, 84, 170)),
      ]);
      expect(t.getRect(find.byKey(key)).right, 316);
      await show([
        obstacle(const Rect.fromLTWH(200, 0, 0, 600), type: AreaType.fold),
      ], direction: TextDirection.rtl);
      expect(t.getRect(find.byKey(key)), const Rect.fromLTWH(200, 0, 200, 600));
      await show([obstacle(const Rect.fromLTWH(0, 0, 400, 600))]);
      expect(t.getSize(find.byKey(key)), Size.zero);
    },
  );
  testWidgets('remeasures moving ancestors even without a new snapshot', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(400, 600);
    addTearDown(t.view.reset);
    final key = GlobalKey();
    final data = fixture(
      t.view,
      areas: [obstacle(const Rect.fromLTWH(0, 0, 84, 600))],
    );
    final offset = ValueNotifier<double>(0);
    addTearDown(offset.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<double>(
          valueListenable: offset,
          builder: (context, value, child) => Padding(
            padding: EdgeInsets.only(left: value),
            child: child,
          ),
          child: FoldableSafeArea(
            data: data,
            child: SizedBox.expand(key: key),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.getRect(find.byKey(key)).left, 84);
    offset.value = 100;
    await t.pumpAndSettle();
    expect(t.getRect(find.byKey(key)).left, 100);
    expect(t.takeException(), isNull);
  });
}
