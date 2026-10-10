# Contributing

Open an issue with the platform, Flutter version, OS version, device/simulator,
and a small example. For geometry issues include the view size, data states and
whether the widget uses SafeArea, multiple views or a transform. Avoid personal
information in screenshots or logs.

Keep this package focused on measurement. Layout policy and state-management
widgets belong in consumers. Import through public entrypoints across package
boundaries. Document platform limitations instead of guessing missing values.

Before a pull request, run `dart format --output=none --set-exit-if-changed lib test example/lib example/test example/integration_test`,
`flutter analyze`, `flutter test`, and the example tests. Native changes also
need `flutter test integration_test/native_test.dart -d <ios-device>` from example.
Include the results and untested platforms in the pull request.

Contributions are distributed under the project's MIT license. Do not copy code
without compatible licensing and attribution.
