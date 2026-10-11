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
need `flutter test integration_test/native_test.dart -d <device>` from example
on the changed platform. For Android, also build the example APK and run
`./gradlew :foldable_info:testDebugUnitTest` from `example/android` (JDK 17).
Include the results and untested platforms in the pull request.

Contributions are distributed under the project's MIT license. Do not copy code
without compatible licensing and attribution.

## Dart internals

- `service.dart` selects a view; `foldable_view.dart` defines the public handle.
- `native_view.dart` owns native subscriptions and Flutter lifecycle events.
- `native_session.dart` rejects old sessions/counters; `replay_feed.dart` shares streams.
- `wire.dart` selects the decoder; Android, iOS and angle decoders read their own payloads.
- `view_metrics.dart` reads Flutter metrics; `flutter_data.dart` handles the fallback and cutouts.
- `layout_comparison.dart` compares layout without observation times or counters.
- `space.dart` converts/clips areas into a widget box; `models.dart` defines values.

Prefer pure `map`/`where`/`nonNulls` transformations and `switch` mappings for data.
Keep resource acquisition, cancellation and lifecycle steps explicit. Use Dart SDK
or `collection` helpers where they make intent clearer. Preserve the Flutter 3.38
minimum; avoid newer syntax that forces consumers to upgrade.
