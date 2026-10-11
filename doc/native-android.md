# Native Android bridge

This implementation is on the development branch; the hosted 0.1.1 package does
not contain it yet. Minimum Android API: 24. Compile SDK: 36. Java: 17.

## APIs and mapping

- [Jetpack WindowManager 1.5.1](https://developer.android.com/jetpack/androidx/releases/window)
  via `WindowInfoTrackerCallbackAdapter` observes the attached Activity window.
- [FoldingFeature](https://developer.android.com/reference/androidx/window/layout/FoldingFeature)
  supplies bounds, orientation, occlusion, `isSeparating` and native posture.
  `FLAT` maps to `open`; `HALF_OPENED` maps to `partlyOpen`. Android does not
  report `closed` through this API. Empty features remain an empty ready list,
  and never imply `isFoldable=false`.
- [Sensor.TYPE_HINGE_ANGLE](https://developer.android.com/reference/android/hardware/Sensor#TYPE_HINGE_ANGLE)
  exists from API 30. `SensorManager` observes the default sensor, only for active
  angle subscribers or pending reads. Angles are degrees (0–360), follow the
  platform convention, and are not converted into posture thresholds.

FoldingFeature has no public fold-versus-hinge type getter. Full occlusion maps
to the package's `hinge` area; otherwise the area is `fold`. Use `cover` and
`splitsView` when deciding layout. Flutter cutouts are preserved with Flutter as
source; native fold areas use Android as source. No duplicate Flutter folds are
added. Area/fold IDs link the same snapshot, not permanent hardware identity.
The angle sensor has no public link to these IDs, so `FoldAngle.foldId` is null.

## Coordinates and windows

WindowManager bounds are window-relative physical pixels. The bridge finds only
the FlutterView attached to this plugin's engine, subtracts its location in the
window, clips bounds to that view, and divides by display density. Zero-width or
zero-height fold lines survive clipping. Features outside the view are excluded.
The Dart bridge also checks native size and pixel ratio against the Flutter view.
Host transforms are rejected instead of producing incorrect coordinates.
`FoldableSpace.toBox` can then project the view frame into a widget's box.

Multi-window/Split View therefore measures the current Activity window, not the
whole physical device. A window on a cover display or one side of the fold may
have no folding features. This does not identify which physical screen is active.
Only engine view ID 0 is supported; another ID or a read without an Activity
reports `noView`. Background/headless engines cannot measure an Activity window.

## Lifetime and unavailable data

Layout and angle demands are tracked independently. Multiple Dart listeners
share one native subscription per stream. Canceling one listener leaves the
others running. One-shot reads retain observation until a measurement, failure
or timeout, then release it. Layout reads wait for the first WindowManager
callback; angle reads wait for a sensor sample. A device may delay or never emit
an event, in which case the requested timeout is reported.

No sensor or API below 30 reports `notSupported`. Failed sensor registration
reports `notAvailable`; a present sensor awaiting a sample reports `loading`.
The sensor stops when the Activity stops or angle demand ends; its old value is
cleared before resume. Activity detach removes window/global-layout callbacks,
stops sensors, and fails pending reads. Reattachment starts a new session;
late callbacks from the old Activity are rejected. The plugin never selects an
unrelated Activity or another engine's FlutterView.

These APIs depend on vendor implementations. No hardware model detection,
physical-screen identity, exact closed-state promise, app-overlay measurement or
layout placement is provided. See [verification](verification.md) for actual
runtime coverage; emulator tests do not certify physical devices.
