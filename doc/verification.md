# Verified coverage

Release under verification: 0.2.0, including native Android. Version 0.1.1 was
iOS-first. The sections below retain the toolchains and scope of each check;
earlier test counts describe earlier snapshots.

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

## Initial iOS standalone release checks

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

## Native Android implementation checks

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

The initial closed/cover-display attempt did not pass the foreground integration suite:
the emulator switched both displays off and paused the Activity. The suite's
ready-data assertions then failed. It is not evidence that cover-display
foreground behavior works. A later foreground check is recorded below. Geometry readiness,
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

## High-density coordinate conversion and foreground cover display

The 0.2.0 snapshot has 27 plugin Dart tests. `FoldableSpace.toBox` now omits the
RenderView physical paint scale when mapping native logical frames to logical
widget coordinates. Regression coverage includes DPR 1 and 3, widget offset,
scale, margins and zero-width fold lines.

On 2026-10-11, a consuming Flutter app passed native integration on Pixel 10 Pro
Fold API 37 across flat → half-open → closed, and half-open → closed → flat.
After the emulator's display transition, the test host woke the device and
dismissed the emulator keyguard. The foreground view changed from
851.7 × 882.9 to 443.1 × 969.8 logical pixels; the closed view replaced its fold
with the cover camera region. Both runs read once initially and then received
geometry through the native layout stream without polling reads between poses.
The player controller and position remained unchanged.

The same consuming app passed on iPhone Duo iOS 27.1 across closed portrait →
partial landscape → flat landscape, on Pixel 7, and on iPhone 18 Pro iOS 27.0.
The older iOS runtime correctly reported reserved regions as unsupported and
used Flutter fallback. These consumer checks establish foreground behavior in
those emulator/simulator configurations; they do not verify physical hardware,
all window containers, every posture or live Split View resize.

## 0.2.0 standalone release checks

Rechecked on 2026-10-11 from a clean standalone public-repository export with
Flutter 3.47.6 / Dart 3.13.5 / Xcode 27.1, and Eclipse Temurin JDK 17 for Android.
The test host used a temporary Flutter config for that JDK; no machine-specific
path is included in the package.

| Check | Result |
| --- | --- |
| Formatting | 25 Dart files, no changes required |
| Analysis | No issues |
| Plugin tests | 27 passed |
| Example widget test | 1 passed |
| Native Android Java tests | 9 passed |
| Android debug APK | Built from the standalone checkout |
| Android closed-cover native integration | 2 passed on Pixel 10 Pro Fold API 37; foreground view 443.1 × 969.8, empty fold list, angle 0°, new session and cancellation/recovery verified |
| iOS simulator debug build | Passed with Swift Package Manager |
| Web release build | Passed, including Wasm dry run |

The web build retains the optional Cupertino icon-font warning described above;
the example uses Material icons. Android Gradle checks use Java 17; a host's
newer Android Studio Java does not imply that the example's Gradle 8 supports
that Java version. Earlier minimum-Flutter CI results concern the iOS-first
release; the Android matrix is configured for this release and its actual
outcome must be read from the release commit's CI run.
