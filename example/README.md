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
flutter test integration_test/native_test.dart -d <ios-device-id>
```

In the ViAce workspace, resolve dependencies from the workspace root instead.
The native tests cover reads, shared subscriptions, cancellation, view errors,
recovery and mounting/unmounting the example. No Vi UI or provider package is
needed. Android/native angle support remains outside this iOS-first release.
