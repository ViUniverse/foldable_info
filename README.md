# foldable_info

Read fold state, hinge angle, view size and blocked areas in Flutter. Your app
or design system decides how to arrange content; this package supplies data.

**0.1.x is an early iOS release.** The iOS bridge reads public UIKit APIs when
available. Android and other platforms use Flutter view metrics and display
features only; **native Android hinge angles are not implemented**.
The new Apple hinge/reserved-region APIs are currently documented as beta and
may change. Missing data is reported explicitly, not guessed.

## Install

```sh
flutter pub add foldable_info
```

Flutter 3.38+ is required. The Dart language minimum is 3.9, so the Dart 3.10
beta bundled with Flutter 3.38.0 is also accepted. iOS deployment target: 15.0+. New fold APIs need a supporting OS and device/view hierarchy.
There are no extra permissions, provider dependency or design-system dependency.

## Read once

```dart
import 'package:foldable_info/foldable_info.dart';

try {
  final data = await FoldableInfo.read();
  final size = data.view.value?.size;
  final state = data.folds.value?.firstOrNull?.openState.value;
  print('Size: $size, fold: ${state?.name ?? data.folds.state.name}');
} on FoldableError catch (error) {
  print('${error.code.name}: ${error.message}');
}
```

The direct methods use the engine's implicit Flutter view. They need no
`BuildContext`. In a multi-view app, select a view explicitly:

```dart
final handle = FoldableInfo.instance.forView(View.of(context));
final data = await handle.read();
```

Import `package:flutter/widgets.dart` for `View`. Native iOS currently supports
the engine registrar's view (Flutter view ID 0); another view reports `noView`.
The service never chooses an arbitrary native window. Engines have independent
services. Static methods report `noView` when no implicit Flutter view exists.

## Watch changes

```dart
final subscription = FoldableInfo.watch().listen(
  (data) { /* update your state */ },
  onError: (Object error) { /* handle the failure */ },
);
// In dispose, cancel only your own subscription.
await subscription.cancel();
```

`watch()` replays the latest snapshot. It shares native observation with other
listeners on the same view. Removing one listener does not stop the others.
View changes and native layout changes update the data. `sessionId` identifies
one observation session; compare `revision` only within that session. A different
observation timestamp alone does not advance the layout revision.

Use Flutter's own builder to display live data:

```dart
StreamBuilder<FoldableData>(
  stream: FoldableInfo.watch(),
  builder: (context, snapshot) {
    if (snapshot.hasError) return Text('Could not read fold data');
    final data = snapshot.data;
    if (data == null) return const Text('Loading');
    return Text(data.folds.value?.firstOrNull?.openState.value?.name
        ?? data.folds.state.name);
  },
)
```

Import `package:flutter/material.dart` for this widget example. The stream for
a live handle is stable across calls, so a rebuild does not restart it. The
package does not provide UI providers or builders. Provider, Riverpod, Bloc or
your design system can consume the same streams.

## Read the angle separately

```dart
final sample = await FoldableInfo.readAngles();
final degrees = sample.angles.value?.firstOrNull?.degrees;
final subscription = FoldableInfo.watchAngles().listen(
  (sample) { /* update an angle effect */ },
  onError: (Object error) { /* handle the failure */ },
);
await subscription.cancel();
```

Angle-only updates do not publish a new layout snapshot. Listen only while the
angle effect is active. Angles are in **degrees**; frames, padding and insets are
in **Flutter logical pixels**. The plugin uses the OS fold status; it does not
invent closed/partly-open/open thresholds from the angle. An angle list may have
no known `foldId`; do not join it to an area by guessing its index.

## Understand unavailable data

Each measured group is a `DataValue<T>`. Only `ready` contains a value.

| State | Meaning |
| --- | --- |
| `ready` | A value was measured, including an empty list. |
| `loading` | Waiting for the first valid measurement or matching geometry. |
| `notAvailable` | The API exists, but there is no current value in this hierarchy/state. |
| `notSupported` | This platform or API cannot provide that field. |
| `unknown` | Available evidence cannot answer the question. |
| `error` | Reading or decoding failed; see `error`. |

Ready values have a source and UTC `readAt`. The area, fold and angle lists in
snapshots are immutable. Read failures complete the Future with `FoldableError`;
stream failures also reach `onError`. A successful later measurement can recover.
Default read timeout: 5 seconds. Invalid timeouts throw `ArgumentError`.

An empty area list does **not** prove the device cannot fold. `isFoldable` remains
unknown without evidence. `ViewArea.isActive` says whether that reserved area is
active; it does not identify which physical screen is powered on. Fold state and
area activity describe different things and can change independently.

## Convert areas to widget coordinates

Native areas use the complete Flutter view's origin. A widget inside `SafeArea`,
a pane or a translated container can have a different origin. After layout:

```dart
final local = FoldableSpace.toBox(
  data: data,
  target: context.findRenderObject()! as RenderBox,
  view: View.of(context),
);
if (local.state == LocalState.ready) {
  // local.areas now use this widget's origin and are clipped to its box.
}
```

Import `package:flutter/rendering.dart` and `package:flutter/widgets.dart`.
The helper supports translation and positive axis-aligned scale, including
zero-width fold lines. It rejects rotation, skew, reflection, perspective,
another view and changed size/pixel ratio. Call again after layout or a new data
snapshot. iOS reserved frames already include the reported margins; do not add
`extraSpace` again to those frames. It is metadata, scaled during conversion.

## Platform support

| Data | iOS | Android | Web / desktop |
| --- | --- | --- | --- |
| View size, safe padding, keyboard/gesture insets | Flutter | Flutter | Flutter |
| Fold/blocked areas | UIKit reserved regions when available | Flutter `displayFeatures` | Flutter `displayFeatures`, often empty |
| Fold state | UIKit hinge status when available | Flutter display-feature posture | Usually unavailable |
| Hinge angle | UIKit hinge angle when available | **Not supported in 0.1.0** | Not supported |
| Size classes, native safe area, preferred bar side | UIKit | Not supported | Not supported |

Flutter decides which display features a platform delivers. This release has no
Android native bridge, `SensorManager` or direct Jetpack WindowManager dependency.
The platform labels include Flutter fallback support; they do not claim native
fold hardware support on every platform.

The iOS bridge uses public
[UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction)
and reserved-region APIs, guarded at runtime. Older systems still expose size
classes and safe area. Resolve `BarSide.start/end` using your widget's
`Directionality`. A preferred bar edge does not prove a toolbar is present.

## Limits

- Does not enumerate every UIKit toolbar, app overlay, floating/split keyboard,
  rounded corner or design spacing. Add app-owned obstacles in your layout layer.
- No physical-screen identity, six named device poses or hardware model detection.
- iOS native multi-view support beyond the registrar view is not implemented.
- No layout placement, navigation, overflow decisions or animation.
- Minimum-version declarations are not a complete tested device/SDK matrix.
  See [verified coverage](doc/verification.md) and [native details](doc/native-ios.md).

## Test and contribute

Import `package:foldable_info/testing.dart` for `FakeFoldableInfo`. Provide
fixtures keyed by view ID, call `fake.forView(view)` and use `sendData`,
`sendAngles` or `sendError`. Counters must advance within a session. Call
`dispose()` when finished; no global service replacement is needed.

The [example](example/README.md) uses only Flutter and this plugin, including
angle subscription lifetime and keyboard metrics. In a standalone checkout:

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter pub get
flutter test
flutter run -d <device-id>
```

See the [API overview and class diagram](doc/api-overview.md),
[CONTRIBUTING](CONTRIBUTING.md), [release steps](RELEASING.md),
[CHANGELOG](CHANGELOG.md) and [security reporting](SECURITY.md).
Licensed under [MIT](LICENSE).
