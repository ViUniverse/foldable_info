# Example

This app depends only on Flutter and foldable_info. It shows view metrics,
available fold state/areas, iOS bar hints and an optional angle stream.
Turning off the angle switch removes its StreamBuilder and cancels that
subscription. It does not select an adaptive layout for you.

In a standalone checkout:

```sh
cd example
flutter pub get
flutter run -d <device-id>
flutter test
flutter test integration_test/native_test.dart -d <device-id>
```

In the ViAce workspace, resolve dependencies from the workspace root instead.
The native tests cover reads, shared subscriptions, cancellation, view errors,
recovery and mounting/unmounting the example. No Vi UI or provider package is
needed. Version 0.2.0 includes native Android WindowManager and optional hinge
angles; version 0.1.1 was iOS-first. See
[Android APIs and limitations](../doc/native-android.md).

To check a controlled foldable emulator pose, set its device state and hinge
sensor through emulator controls, then supply test expectations, for example:

```sh
flutter test integration_test/native_test.dart -d <android-device-id> \
  --dart-define=EXPECTED_POSTURE=partlyOpen --dart-define=EXPECTED_ANGLE=90
```

The state and sensor controls are independent in the emulator. This test checks
that both APIs are read directly, without deriving one value from the other.

## Visual diagnostics

The layer button toggles a non-interactive overlay over the full view. Orange
means blocked/occlusion, purple means fold/hinge; inactive areas have lighter
fill. Labels show the clipped local frame dimensions; the measurements below show native margins metadata. Toggle “Avoid regions in demo” to compare the same control with and without avoidance. The
protected-control panel uses `FoldableSafeArea`; tap the control to verify it
remains interactive. Geometry outside this panel does not affect its layout.

The copy button puts the current complete snapshot on the clipboard, including
all regions, margins, activity, view/DPR, padding, keyboard/gesture insets,
posture, bar side, UTC capture time and session/revision. The example never logs
these automatically. Capture before/after each pose for a bug report; see
[geometry diagnosis](../doc/geometry.md). Native region IDs are session-scoped.


## Layout recipes

Tap the book icon **Layout recipes** in the diagnostics app bar. The three tabs
contain working list/detail, local player simulation, floating bookmark controls
and pane-local dialog/sheet editors. Live snapshots are the default. Illustrative
book/tabletop/no-fold geometry is labelled and can run on ordinary devices. RTL
and text 2× controls help inspect reading order and accessibility layouts.

See [recipe walkthrough and source links](../doc/recipes.md) for state, insets,
keyboard and transform behavior. The examples do not add exported scaffolds,
a global MediaQuery bridge, real audio playback or network dependencies.
