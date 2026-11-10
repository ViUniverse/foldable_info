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

## Avoidance widget and documentation update — 2026-11-10

The example was run on the existing iPhone Duo iOS 27.1 simulator with Flutter
3.47.6 / Dart 3.13.5 / Xcode 27.1 from a standalone export. It was hot restarted
after UI changes. Closed, partial landscape, partial portrait and flat portrait
snapshots, including all inactive regions and margins, are stored in
[the measurement record](measurements/2026-11-10/README.md). README images are
actual simulator captures, except the explicitly labelled geometry schematic.
The GIF is a sequence of captures, not a continuous hardware recording.

The before/after demo was inspected on the simulator: with avoidance off, the
control crossed the vertical fold; with it on, the control stayed in the
largest free rectangle on the left. Tapping it through the enabled overlay
produced the expected confirmation. The example's outer SafeArea keeps its
diagnostic buttons outside the status column.

The customer-specific 144-wide region was not reproduced: this run reported
134 × 82 in portrait, 84 × 120 on the inner landscape view, and 84 × 170 closed.
Occlusion margins were zero. No fixed-width padding or native semantic subtype
was introduced. Physical device behavior and arbitrary status contents remain
unverified. API geometry can briefly lag rotation; see the measurement record.

Flutter 3.41.2 / Dart 3.11 was downloaded from the official Flutter tag for an
isolated compatibility check, rather than resolving the full ViAce workspace
(which has unrelated dependencies requiring newer Dart). This release keeps
Flutter 3.38 as its declared minimum. The CI Dart matrix now also includes
3.41.2; a configured job is not itself a passing CI result.

| Current check | Result |
| --- | --- |
| Workspace package analysis, Flutter 3.47.6 | No issues |
| Package tests, Flutter 3.47.6 | 32 passed |
| Example widget test | Passed; loading, error/recovery, angle lifetime, overlay toggle and copied diagnostic JSON |
| Standalone analysis and 32 package tests, Flutter 3.41.2 | Passed |
| Standalone example widget test, Flutter 3.41.2 | Passed |
| Duo iOS 27.1 native integration, current example | 2 passed; closed 0°, separate 37 × 37 and 84 × 170 blocked regions |
| iPhone 18 Pro iOS 27.0 native integration, current example | 2 passed; fold/region/angle fields unsupported, metrics and example remain usable |

Five new widget tests cover single/multiple overlapping obstacles, zero-width
folds, inactive regions, margins without reinflation, nested SafeArea/offsets,
ancestor movement without a new snapshot, RTL ties, complete coverage, missing
data fallback and button taps. Existing coordinate tests cover DPR and scale.
Native Android was not rerun for this Dart/widget/documentation update; previous
Android emulator evidence above remains explicitly dated.

Final formatting checked 29 Dart files with no changes; `git diff --check`
passed. Standalone publication dry run reported 0 warnings (about 2 MB archive)
with README images and pub.dev screenshot metadata included. No publication was
performed. Local Markdown image/document links were checked for missing files.
The final example was relaunched and hot reloaded on Duo after the native suites.

## 0.3.0 release preparation — 2026-11-10

The standalone release keeps workspace resolution out of both manifests and
uses the example's local path dependency. Dart analysis, all 32 package tests,
the example widget test and formatting passed with Flutter 3.47.6. The Dart
implementation was also checked on Flutter 3.41.2 as recorded above. Generated
SwiftPM state and local CocoaPods setup are excluded from the release export.
The standalone 0.3.0 iOS simulator debug build passed with Swift Package Manager.

## P2 example recipes and comparison — 2026-11-10 (0.3.1)

The [package comparison](comparison.md) uses exact published archive versions and
SHA-256 values from the pub.dev registry. Seven competing packages were read at
source/manifest level; none were built or run. Runtime and CI evidence for our
published 0.3.0 is separate from the new example recipes in 0.3.1.

The new recipe screen was run with Flutter 3.47.6 / Dart 3.13.5 on the iPhone Duo
iOS 27.1 simulator and hot reloaded after fixes. With Live geometry selected:

- List/detail retained Article 3 through closed → partial transitions.
- The player changed from horizontal tabletop to vertical book layout while
  remaining in the playing state and advancing to 17 seconds; Pause worked.
- The bookmark action incremented its count; a primary-pane dialog moved to the
  upper pane when the device rotated; Save returned a result to the page.
- Selecting the secondary pane opened the sheet below the horizontal fold.
- RTL and text 2× were visually inspected. The normal text and keyboard-capture
  controls were restored after inspection.

[Recipe screenshots and walkthrough](recipes.md) are actual simulator captures
from those live layouts, not physical-device evidence. Runtime text entry via
the desktop simulator controls was not established; draft entry/preservation and
keyboard-inset handling were verified by widget tests instead.

All **7 example tests** passed on Flutter 3.47.6 and in an isolated Flutter
3.41.2 / Dart 3.11 checkout. The six new recipe tests cover splitting rules and
zero-width lines, draft/selection through compact and expanded layouts, player
controls/continuity, selected-pane dialog/sheet results and keyboard clearance,
RTL with text 2× at 320 × 640 plus safe padding (including scrolling to a slider that stays outside the fold even in compact fallback), and an already-open editor
through native-stream failure/recovery and changes in split orientation.
Analysis passed for the package and the 3.41.2 example. The public library API,
native bridges and platform minimums are unchanged by this P2 work.

These recipes deliberately do not promise per-pane keyboard isolation, arbitrary
transform support, every app's state retention policy, or physical-device/manual
screen-reader certification. Pane sizes and responsive breakpoints are example
policies. No new navigation scaffold or global display-feature bridge is added.

The final P2 example web release build also passed, including the Wasm dry run.
It retained the previously recorded optional Cupertino icon-font warning. Local
Markdown document/image links were checked and had no missing targets.

## 0.3.1 release preparation — 2026-11-10

Rechecked from a clean standalone export with Flutter 3.47.6: analysis passed,
32 package tests and 7 example tests passed, all 35 Dart files passed formatting,
and the iOS simulator debug build passed with Swift Package Manager. Both package
manifests are standalone; the workspace-only resolution and local CocoaPods
configuration are not part of the release. The podspec version matches 0.3.1.
The release adds example/recipe screenshots to the pub.dev gallery.

The 3.38.0 example suite was rerun locally and all 7 tests passed. The compact
back-button test uses a stable key because older Flutter versions implement
`TextButton.icon` with a different concrete widget type. This corrects the test
lookup while preserving its navigation and draft-retention assertions.
