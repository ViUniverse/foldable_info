# Foldable package comparison

**Reviewed on 2026-11-10 (Asia/Ho_Chi_Minh).** Versions below were the latest
pub.dev releases returned by the registry when reviewed. This is a dated
capability comparison, not a performance benchmark or a ranking by downloads.

**Evidence levels:** **S** = read the published source archive and manifest;
**D** = publisher documentation; **R** = ran the package ourselves. Competitor
rows are **S+D only**: none were built or run for this comparison. `foldable_info`
has **S+R** evidence with simulator/emulator limits in [verification](verification.md).
A source implementation does not certify any particular physical device.

“Not exposed” means the reviewed public API has no separate field for that
measurement. It does not mean its native frame is wrong. In particular, UIKit
reserved frames can already include margins even when the Dart model does not
expose the margins separately. No package gets credit here for distinguishing
camera from status UI based only on an occlusion rectangle.

## Measurements and declared SDK requirements

The Flutter and Dart columns are **manifest declarations, not validated minimum
build combinations**. Both constraints must be satisfied. A permissive Flutter
constraint does not override a newer Dart requirement or native toolchain needs.

| Package / reviewed release | Fold input on iOS / Android | Separate native margins | Fold vs occlusion | Foldability API | Declared Flutter / Dart |
| --- | --- | --- | --- | --- | --- |
| [foldable_info 0.3.0](https://pub.dev/packages/foldable_info/versions/0.3.0) | UIKit / native WindowManager + sensor | `extraSpace`; iOS rect already includes them | `AreaType` fold / hinge / blocked | `DataValue<bool>`; unknown stays explicit | ≥3.38.0 / ^3.9.0 |
| [foldable 1.0.5](https://pub.dev/packages/foldable/versions/1.0.5) | UIKit / no Android native implementation | Not exposed by `ReservedRegion` | division / occlusion kind | Boolean capability/API | ≥3.24.0 / ^3.5.0 |
| [unfold 0.2.0](https://pub.dev/packages/unfold/versions/0.2.0) | UIKit / Flutter display features | `ReservedRegion.margins`; frame includes margins, `rect` removes them | Separate division and occlusion lists | API-support flag; not a hardware `isFoldable` | ≥3.44.0 / ^3.12.0 |
| [nitro_fold_duo 0.0.1](https://pub.dev/packages/nitro_fold_duo/versions/0.0.1) | Native bridge / native WindowManager + sensor | Individual margins + geometry extension; rect includes them | `DuoRegionKind` | `isSupported`; semantics differ from hardware identity | ≥3.3.0 / ^3.13.3 |
| [foldable_device 1.0.5](https://pub.dev/packages/foldable_device/versions/1.0.5) | UIKit / native WindowManager + sensor | Not exposed by `FoldRegion` | Separate fold and occlusion properties | Boolean `FoldableHelper.isFoldable` | ≥3.3.0 / ≥3.5.0 &lt;4.0.0 |
| [iphone_duo_ui_pro 1.0.0](https://pub.dev/packages/iphone_duo_ui_pro/versions/1.0.0) | UIKit / no native Android plugin | Not exposed by `DuoRegion` | Separate division and occlusion collections | Nullable hinge; no dedicated `isFoldable` found | ≥3.38.0 / ^3.10.0 |
| [duo_kit 0.1.2](https://pub.dev/packages/duo_kit/versions/0.1.2) | MediaQuery supplied by a separate bridge / Flutter display features | Not in `FoldGeometry` | Flutter display-feature types | Geometry, not hardware detection | ≥3.41.0 / ≥3.11.0 &lt;4.0.0 |
| [duo_flex 0.4.0](https://pub.dev/packages/duo_flex/versions/0.4.0) | UIKit / native WindowManager + sensor | Not exposed by `DuoDisplayRegion` | Semantic reserved division/occlusion types | Nullable `DuoDeviceInfo.isFoldable` plus capabilities | ≥3.47.2 / ^3.13.2 |

Important for Flutter 3.41 users: `nitro_fold_duo`'s ≥3.3 Flutter declaration is
not sufficient; its Dart ^3.13.3 requirement is newer than Flutter 3.41's Dart.
Likewise, a stable ^3.10.0 constraint may exclude a bundled Dart prerelease.
Only `foldable_info` 0.3.0's own 3.38/3.41.2/stable CI combinations have runtime/CI evidence in this review; this is not a competitor build matrix.

## Layout integration

Dedicated avoidance widgets, internal widget geometry handling and general
conversion utilities are listed separately because they solve different tasks.
The recipes included in the 0.3.1 example are **example code**, not new public
widgets. The measurement comparison retains the reviewed 0.3.0 baseline; 0.3.1
does not change those public measurement APIs.

| Package / version | Avoidance and pane layout | Dialog / sheet integration | Widget-coordinate handling | Evidence |
| --- | --- | --- | --- | --- |
| foldable_info 0.3.0 | `FoldableSafeArea` chooses one free rectangle. | No public MediaQuery bridge; current repository adds a per-route example | Public `FoldableSpace.toBox`, clipping, translation/positive scale and stale/unsupported-transform states | S+R; [coverage](verification.md) |
| foldable 1.0.5 | `FoldAwareBuilder`; no dedicated avoidance container found | Optional display-feature bridge | Builder converts region origins internally | S+D |
| unfold 0.2.0 | `OcclusionSafeArea`, `FoldSplit`, `TabletopSplit`, navigation scaffold | Optional display-feature bridge | Widgets measure window position internally | S+D |
| nitro_fold_duo 0.0.1 | `DuoOcclusionSafeArea`, split widgets and bar scaffold | Display-feature bridge | Origin/inset helpers and widget measurements | S+D |
| foldable_device 1.0.5 | `FoldSafeArea` and padding helper | No dedicated route bridge found | Avoidance widget measures its global box | S+D |
| iphone_duo_ui_pro 1.0.0 | Two-pane/grid widgets; occlusion handling in scaffold/panes | Display-feature bridge and dialog/sheet helpers | Pane/grid widgets convert origins internally | S+D |
| duo_kit 0.1.2 | `FoldScaffold`, `FoldSplitView`; uses Flutter safe padding | `FoldAnchor` with supplied display features | Split-view handles local placement internally | S+D |
| duo_flex 0.4.0 | Responsive and posture-selection widgets; no general occlusion-avoidance widget found | No dedicated route bridge found | No equivalent public box-conversion utility found | S+D |

A bridge can alter framework dialog/sheet placement throughout a subtree; a
route-local recipe changes only that presentation. Absence of a bridge is not
absence of fold data, and availability of a bridge is not proof that every
system overlay or status configuration is covered.

## Choosing by responsibility

Use the measurements you need and evaluate layout policy separately. A native
measurement package can suit an app with its own design system; a package with
navigation/grid/scaffold widgets can reduce app-level layout work when those
policies match the product. Those scopes are not interchangeable, so the tables
do not rank a larger widget catalog as automatically better geometry.

For `foldable_info`, the practical tradeoffs are:

- **Native Android input:** WindowManager geometry and optional sensor readings
  can be consumed outside a MediaQuery-driven widget tree. This still depends
  on the vendor exposing the APIs.
- **Margins as metadata:** `extraSpace` helps inspect what the platform reserved;
  it is not padding to add a second time.
- **Local conversion:** a public conversion result makes clipping, offsets,
  scale and unsupported/stale geometry explicit for custom panes and overlays.
- **Deterministic fixtures:** `FakeFoldableInfo` can feed independent views,
  newer snapshots and errors into app tests without global replacement. The
  [recipe tests](../example/test/recipes_test.dart) exercise an already-open
  editor through failures and new geometry using that public fake.
- **Separate angle observation:** apps can subscribe for an active angle effect
  without treating each angle sample as a new layout snapshot. No CPU/frame-rate
  advantage over competitors was measured in this review.

These are concrete API choices, not a claim that other packages cannot solve
similar use cases. Test the exact package version, host SDK and target device
for the behavior your app needs.

## Reproducible source evidence

[The registry snapshot](comparison/registry-snapshot.json) records each exact
archive URL, SHA-256 and declared environment. The archives were downloaded from
the pub.dev API, checksummed, extracted locally and inspected without executing
them. No competitor code is copied into this repository.

| Published archive | Principal files inspected inside the archive |
| --- | --- |
| [foldable 1.0.5 source](https://pub.dev/api/archives/foldable-1.0.5.tar.gz) | `pubspec.yaml`, `lib/foldable.dart`, `lib/src/model/reserved_region.dart`, `lib/src/model/foldable_capabilities.dart`, `lib/src/widgets/fold_aware_builder.dart`, `lib/src/bridge/display_feature_bridge.dart` |
| [unfold 0.2.0 source](https://pub.dev/api/archives/unfold-0.2.0.tar.gz) | `pubspec.yaml`, `lib/src/geometry.dart`, `lib/src/scope.dart`, `lib/src/widgets.dart`, `lib/src/navigation.dart` |
| [nitro_fold_duo 0.0.1 source](https://pub.dev/api/archives/nitro_fold_duo-0.0.1.tar.gz) | `pubspec.yaml`, `README.md`, `lib/src/geometry/duo_geometry.dart`, `lib/src/geometry/duo_local_origin.dart`, `lib/src/widgets/duo_occlusion_safe_area.dart`, `android/src/main/kotlin/dev/shreeman/nitro_fold_duo/NitroFoldDuoImpl.kt` |
| [foldable_device 1.0.5 source](https://pub.dev/api/archives/foldable_device-1.0.5.tar.gz) | `pubspec.yaml`, `lib/foldable_device.dart`, `android/src/main/kotlin/com/esmailelmahdy/foldable_device/FoldableDevicePlugin.kt` |
| [iphone_duo_ui_pro 1.0.0 source](https://pub.dev/api/archives/iphone_duo_ui_pro-1.0.0.tar.gz) | `pubspec.yaml`, `lib/iphone_duo_ui_pro.dart`, `lib/src/duo_environment.dart`, `lib/src/duo_display_features.dart`, `lib/src/fold_aware_two_pane.dart`, `lib/src/duo_adaptive_scaffold.dart` |
| [duo_kit 0.1.2 source](https://pub.dev/api/archives/duo_kit-0.1.2.tar.gz) | `pubspec.yaml`, `lib/src/geometry/fold_geometry.dart`, `lib/src/widgets/fold_split_view.dart`, `lib/src/widgets/fold_scaffold.dart`, `lib/src/presentation/fold_anchor.dart` |
| [duo_flex 0.4.0 source](https://pub.dev/api/archives/duo_flex-0.4.0.tar.gz) | `pubspec.yaml`, `lib/duo_flex.dart`, `lib/src/models/duo_device_info.dart`, `lib/src/models/duo_display_region.dart`, `lib/src/widgets/duo_fold_aware_layout.dart`, `lib/src/platform/method_channel_duo_flex.dart` |

For `foldable_info`, [published 0.3.0 source](https://pub.dev/api/archives/foldable_info-0.3.0.tar.gz)
and the current [example recipes](recipes.md) are separate evidence: the P2
recipes are not retroactively claimed as shipped in the 0.3.0 archive. Update
this date, version pins and evidence together when revisiting the comparison.
