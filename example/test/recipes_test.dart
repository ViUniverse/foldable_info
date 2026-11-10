import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_info/foldable_info.dart';
import 'package:foldable_info/testing.dart';
import 'package:foldable_info_example/recipes/geometry.dart';
import 'package:foldable_info_example/recipes/recipes_page.dart';

ViewArea fold(Rect r, {bool active = true, bool separating = false}) =>
    ViewArea(
      type: AreaType.fold,
      rect: r,
      isActive: active,
      splitsView: separating,
      direction: r.width > r.height
          ? AreaDirection.leftToRight
          : AreaDirection.topToBottom,
      cover: AreaCover.none,
      source: DataSource.calculated,
    );

Future<void> mode(WidgetTester t, String label) async {
  await t.tap(find.byKey(const ValueKey('recipe-preview')));
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

Future<void> start(WidgetTester t, {Size size = const Size(1000, 900)}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  await t.pumpWidget(const MaterialApp(home: RecipesPage()));
  await t.pumpAndSettle();
  await mode(t, 'Illustrative no fold');
}

void main() {
  test(
    'splits only current spanning geometry; retains zero-width divisions',
    () {
      const size = Size(1000, 900);
      final r = fold(const Rect.fromLTWH(490, 0, 20, 900));
      expect(recipeSplit(size, [r], FoldState.partlyOpen)?.first.right, 490);
      expect(recipeSplit(size, [r], FoldState.open), isNull);
      expect(
        recipeSplit(size, [r.copyWith(isActive: false)], FoldState.partlyOpen),
        isNull,
      );
      expect(
        recipeSplit(size, [
          fold(const Rect.fromLTWH(500, 0, 0, 900)),
        ], FoldState.partlyOpen)?.second.left,
        500,
      );
      expect(
        recipeSplit(size, [
          fold(const Rect.fromLTWH(490, 50, 20, 800)),
        ], FoldState.partlyOpen),
        isNull,
      );
      expect(
        recipeSplit(size, [
          r.copyWith(type: AreaType.hinge, splitsView: true),
        ], FoldState.open),
        isNotNull,
      );
    },
  );

  testWidgets(
    'selection and draft survive fold and compact/expanded transitions',
    (t) async {
      await start(t);
      await t.tap(find.text('Article 3'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('recipe-note')),
        'Keep this draft',
      );
      await mode(t, 'Illustrative book');
      expect(find.text('Article 3 details'), findsOneWidget);
      expect(find.text('Keep this draft'), findsOneWidget);
      await mode(t, 'Illustrative no fold');
      t.view.physicalSize = const Size(430, 900);
      await t.pumpAndSettle();
      expect(find.text('Article 3 details'), findsOneWidget);
      expect(find.text('Keep this draft'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('recipe-back-to-list')));
      await t.pumpAndSettle();
      expect(find.text('Article 3'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('player actions and progress survive changing geometry', (
    t,
  ) async {
    await start(t);
    await t.tap(find.text('Tabletop player'));
    await t.pumpAndSettle();
    await t.tap(find.text('Play'));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('2 / 180 seconds'), findsOneWidget);
    await mode(t, 'Illustrative tabletop');
    expect(find.text('Pause'), findsOneWidget);
    await t.tap(find.text('Pause'));
    await t.pump();
    final before = int.parse(
      (t.widget<Text>(find.byKey(const ValueKey('recipe-position'))).data!)
          .split(' / ')
          .first,
    );
    expect(before, greaterThanOrEqualTo(2));
    await t.tap(find.byTooltip('Forward 15 seconds'));
    await t.pump();
    expect(find.text('${before + 15} / 180 seconds'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('dialog follows selected pane and saves; sheet avoids keyboard', (
    t,
  ) async {
    await start(t);
    await mode(t, 'Illustrative book');
    await t.tap(find.text('Controls / surfaces'));
    await t.pumpAndSettle();
    await t.tap(find.text('Primary pane'));
    await t.pumpAndSettle();
    await t.tap(find.text('Secondary pane').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Open dialog'));
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(AlertDialog)).left, greaterThanOrEqualTo(512));
    await t.enterText(
      find.widgetWithText(TextField, 'Annotation'),
      'Pane note',
    );
    await t.tap(find.text('Save note'));
    await t.pumpAndSettle();
    expect(find.text('Saved note: Pane note'), findsOneWidget);
    await t.tap(find.text('Open sheet'));
    await t.pumpAndSettle();
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Save note')).bottom, lessThan(600));
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'RTL primary pane is on right and large text remains scrollable',
    (t) async {
      await start(t);
      await mode(t, 'Illustrative book');
      await t.tap(find.text('RTL'));
      await t.tap(find.text('Controls / surfaces'));
      await t.pumpAndSettle();
      await t.tap(find.text('Open dialog'));
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byType(AlertDialog)).left,
        greaterThanOrEqualTo(512),
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(320, 640);
      t.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Text 2×'));
      await t.tap(find.text('Text 2×'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      for (final tab in [
        'List / detail',
        'Tabletop player',
        'Controls / surfaces',
      ]) {
        await t.ensureVisible(find.text(tab));
        await t.tap(find.text(tab));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (tab == 'Tabletop player') {
          await t.scrollUntilVisible(
            find.byType(Slider),
            100,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('recipe-player-controls')),
              matching: find.byType(Scrollable),
            ),
          );
          await t.pumpAndSettle();
          final slider = t.getRect(find.byType(Slider));
          expect(
            slider.right <= 148 || slider.left >= 172,
            true,
            reason: 'Compact controls must still avoid the illustrative fold',
          );
        }
      }
    },
  );
  testWidgets(
    'an open route follows new live geometry without losing its editor',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1000, 900);
      addTearDown(t.view.reset);
      final initial = recipeData(t.view, null, RecipePreview.book)!;
      final fake = FakeFoldableInfo(views: {t.view.viewId: initial});
      addTearDown(fake.dispose);
      await t.pumpWidget(MaterialApp(home: RecipesPage(info: fake)));
      await t.pumpAndSettle();
      await t.tap(find.text('Controls / surfaces'));
      await t.pumpAndSettle();
      await t.tap(find.text('Open dialog'));
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(AlertDialog)).right, lessThanOrEqualTo(488));
      await t.enterText(
        find.widgetWithText(TextField, 'Annotation'),
        'Keep route draft',
      );
      fake.sendError(
        viewId: t.view.viewId,
        error: const FoldableError(ErrorCode.nativeError, 'temporary failure'),
      );
      await t.pumpAndSettle();
      expect(find.text('Keep route draft'), findsOneWidget);
      expect(t.getCenter(find.byType(AlertDialog)).dx, closeTo(500, 1));
      fake.sendData(
        recipeData(
          t.view,
          null,
          RecipePreview.tabletop,
        )!.copyWith(sessionId: initial.sessionId, revision: 2),
      );
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byType(AlertDialog)).bottom,
        lessThanOrEqualTo(438),
      );
      expect(find.text('Keep route draft'), findsOneWidget);
      fake.sendData(
        recipeData(
          t.view,
          null,
          RecipePreview.noFold,
        )!.copyWith(sessionId: initial.sessionId, revision: 3),
      );
      await t.pumpAndSettle();
      expect(t.getCenter(find.byType(AlertDialog)).dx, closeTo(500, 1));
      await t.tap(find.text('Save note'));
      await t.pumpAndSettle();
      expect(find.text('Saved note: Keep route draft'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
