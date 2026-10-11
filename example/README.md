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
