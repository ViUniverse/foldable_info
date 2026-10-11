import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_info/foldable_info.dart';
import 'package:foldable_info/src/layout_comparison.dart';
import 'foldable_info_test.dart' show area, fixture, ready, time;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'model equality preserves ordered nested lists and custom value identity',
    () {
      final first = ready(<Object?>[
        1,
        <Object?>[null, 2],
      ]);
      final second = ready(<Object?>[
        1,
        <Object?>[null, 2],
      ]);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first,
        isNot(
          ready(<Object?>[
            1,
            <Object?>[2, null],
          ]),
        ),
      );

      final customValue = {'a': 1};
      expect(ready(customValue), ready(customValue));
      expect(ready(customValue), isNot(ready(Map.of(customValue))));
      expect(ready(<int>{1}), isNot(ready(<int>{1})));
    },
  );

  test('copyWith keeps error and non-ready data invariants', () {
    const failure = FoldableError(ErrorCode.timeout, 'timeout');
    final failed = ready(7).copyWith(state: DataState.error, error: failure);
    expect(failed.error, failure);
    expect(failed.value, isNull);
    expect(failed.readAt, isNull);
    expect(() => failed.copyWith(error: null), throwsArgumentError);

    for (final state in [
      DataState.loading,
      DataState.notAvailable,
      DataState.notSupported,
      DataState.unknown,
    ]) {
      final changed = failed.copyWith(state: state);
      expect(changed.error, isNull);
      expect(changed.value, isNull);
      expect(changed.readAt, isNull);
      expect(() => changed.copyWith(value: 1), throwsArgumentError);
      expect(() => changed.copyWith(readAt: time), throwsArgumentError);
    }
  });

  testWidgets(
    'layout equality ignores observation metadata and detects actual changes',
    (tester) async {
      final first = fixture(tester.view).copyWith(
        folds: ready([
          FoldInfo(
            openState: ready(FoldState.open),
            direction: AreaDirection.unknown,
          ),
        ]),
      );
      final later = time.add(const Duration(seconds: 1));
      final refreshed = first.copyWith(
        revision: 99,
        view: first.view.copyWith(readAt: later),
        folds: first.folds.copyWith(
          value: [
            first.folds.value!.single.copyWith(
              openState: first.folds.value!.single.openState.copyWith(
                readAt: later,
              ),
            ),
          ],
          readAt: later,
        ),
      );
      expect(sameLayout(first, refreshed), true);
      expect(sameLayout(first, refreshed.copyWith(sessionId: 'new')), false);
      expect(
        sameLayout(first, refreshed.copyWith(viewState: ViewState.paused)),
        false,
      );
      expect(
        sameLayout(
          first,
          refreshed.copyWith(
            view: refreshed.view.copyWith(source: DataSource.android),
          ),
        ),
        false,
      );
      expect(
        sameLayout(
          first,
          first.copyWith(
            folds: ready([
              first.folds.value!.single.copyWith(
                openState: ready(FoldState.partlyOpen),
              ),
            ]),
          ),
        ),
        false,
      );
    },
  );

  testWidgets(
    'projection clips horizontal lines and drops outside areas in input order',
    (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 50, top: 30),
              child: SizedBox(key: key, width: 200, height: 200),
            ),
          ),
        ),
      );
      final data = fixture(
        tester.view,
        areas: [
          area(const Rect.fromLTWH(0, 80, 400, 0)),
          area(const Rect.fromLTWH(250, 0, 0, 400)),
          area(const Rect.fromLTWH(50, 20, 80, 40)),
          area(const Rect.fromLTWH(0, 500, 400, 0)),
        ],
      );
      final local = FoldableSpace.toBox(
        data: data,
        target: key.currentContext!.findRenderObject()! as RenderBox,
        view: tester.view,
      );
      expect(local.state, LocalState.ready);
      expect(local.areas.map((area) => area.rect), [
        const Rect.fromLTWH(0, 50, 200, 0),
        const Rect.fromLTWH(0, 0, 80, 30),
      ]);
    },
  );
}
