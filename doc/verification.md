# Verified coverage

Published release: 0.1.1 (iOS-first). The Android results below describe the
new development branch, not the hosted 0.1.1 archive.

The first iOS implementation was exercised on the Duo iOS 27.1 simulator and
an iPad Pro 11-inch M5 simulator running iOS 26.2. Duo tests included several fold
poses; the older runtime retained safe area/size classes and reported newer fold
APIs as unsupported. Simulator results do not certify physical devices or every
UIKit container. UIKit toolbar enumeration and physical screen identity are not
features of this release.

Toolchain available for the release check: Flutter 3.47.6, Dart 3.13.5, Xcode 27.1.
The declared minimum is Flutter 3.38 / Dart language 3.9 / iOS 15. GitHub CI has
passed analysis, plugin/example tests and a web build on Flutter 3.38.0, plus an
iOS simulator build on stable. The minimum-version result is recorded in
[this CI job](https://github.com/ViUniverse/foldable_info/actions/runs/38078839087/job/114291373343).
That run also exposed a prerelease SDK publication warning, corrected by the
stable Dart language constraint below. iOS builds on the minimum Flutter SDK,
iOS 15 and physical device tests remain unverified.

## Standalone release checks

Checked on 2026-10-11 in an exported standalone Git checkout, without workspace
resolution or Vi UI dependencies:

| Check | Result |
| --- | --- |
| Formatting | 10 Dart files, no changes needed |
| Analysis | No issues |
| Plugin tests | 16 passed |
| Example test | 1 passed; loading, error/recovery and angle toggle |
| API documentation | 2 public libraries; 0 warnings, 0 errors |
| Web release build | Passed, including Flutter's Wasm dry run |
| Duo iOS 27.1 native integration | 2 passed; areas, fold state and angle ready |
| iPad iOS 26.2 native integration | 2 passed; new APIs correctly unsupported |
| Live example launch and hot reload | Passed on Duo |
| Swift Package Manager simulator builds | Passed as part of both native suites |
| pub.dev publication dry run | 0 warnings; compressed archive about 95 KB |

A dry run does not upload the package or reserve its name. The web build produced
a Flutter icon-font warning for the optional Cupertino icon family; the example
uses Material widgets and its build completed. CI outcomes are separate from
these local results.

## Minimum Flutter constraint correction

The first GitHub run passed stable Dart checks but Flutter 3.38.0 failed dependency
resolution: that stable Flutter release contains Dart 3.10.0-290.4.beta, which
`^3.10.0` excludes. Version 0.1.1 uses Dart language 3.9 and keeps the Flutter 3.38 minimum,
so the bundled SDK is accepted without requiring a prerelease Dart SDK. This
changes SDK compatibility only; native source and the measurement API are unchanged.
The 0.1.0 pub.dev upload succeeded before this CI result was finalized.

## Native Android development checks

Checked on 2026-10-11 with Flutter 3.47.6 / Dart 3.13.5, Temurin JDK 17,
AGP 8.11.1, Gradle 8.14.3, and a Pixel 10 Pro Fold emulator on Android API 37.
No machine-specific Java or Android SDK path is committed.

| Check | Result |
| --- | --- |
| Plugin Dart tests | 22 passed, including Android decoding and direct methods |
| Example widget test | 1 passed |
| Native Java tests | 9 passed: clipping/offset/density, zero-width fold lines, sensor absence/failure, cancellation/timeout, background and detach |
| Android debug APK | Built and installed |
| Live Android example and hot reload | Passed |
| Half-open native integration | 2 passed; `partlyOpen`, angle 90°, fold line plus separate Flutter cutout |
| Flat native integration | 2 passed; `open`, angle 180° |
| iPhone Duo iOS regression | 2 passed after the shared Dart bridge changes |

Both Android runs checked shared subscribers, cancellation, new observation
sessions, invalid view IDs, recovery and mounting/unmounting the example.
Posture and angle were asserted independently against explicitly controlled
emulator inputs. The fold line was x=425.8 in a view of 851.7 × 882.9 logical pixels.

The closed/cover-display attempt did not pass the foreground integration suite:
the emulator switched both displays off and paused the Activity. The suite's
ready-data assertions then failed. It is not evidence that cover-display
foreground behavior works; that case remains unverified. Geometry readiness,
background cleanup and sensor stop/restart are tested separately as listed above.

Physical Android devices, a live Split View resize, multiple hinges, and Android
API 24–36 runtime behavior remain unverified. Android build checks are also added
to CI for Flutter 3.38.0 and stable; a configured job is not itself a passing
result. The example toolchain intentionally remains on AGP/Gradle 8 for the
minimum Flutter SDK; current Flutter reports future-support deprecation warnings.

## Declarative Dart refactor

The public API and Flutter 3.38 / Dart language 3.9 constraints are unchanged.
`collection` 1.19.1 is now an explicit dependency. SDK `indexed`/`nonNulls` and
collection lookup/equality helpers replace manual transformations where useful.

All 22 existing plugin tests passed before and after restructuring. Four added
regression tests cover ordered model equality/custom value identity, copyWith
state invariants, snapshot comparison and horizontal/ordinary area clipping.
A temporary differential check compared the previous and refactored decoders
across 232 native availability/malformed-group combinations; all agreed. The
previous implementation is not retained in the package. The example widget test,
analysis and formatting also passed.

After refactoring, Android flat/180° native integration and Duo iOS integration
both passed (2 tests each). Live Android hot restart also passed.
