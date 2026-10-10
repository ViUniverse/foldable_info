# iOS bridge

The plugin registers method and separate layout/angle event channels for one
Flutter engine. It attaches a non-interactive, accessibility-hidden measuring
view inside the registrar's Flutter view. It never selects a global key window.
Current native support is Flutter view ID 0; other IDs return noView.

A native session starts when the probe attaches. Layout, safe-area, trait and
hinge changes are observed through public UIKit APIs. Subscribers share the
probe. The last subscription/read releases it and removes its hinge interaction.
Read requests have a bounded timeout. Event delivery checks the attachment epoch
so a callback from a detached probe cannot publish into its replacement.

## API mapping

| Native input | Public data |
| --- | --- |
| FlutterView metrics | ViewInfo size, pixel ratio, padding and insets |
| UIHingeInteraction / UIHinge.status | FoldInfo.openState |
| UIHinge.angle | FoldAngle.degrees, converted from radians |
| UIView reserved occlusion regions | ViewArea type blocked |
| UIView reserved division regions | ViewArea type fold |
| ReservedRegion.frame / margins / isActive | rect / extraSpace / isActive |
| UITraitCollection horizontal/vertical size classes | IosInfo widthClass / heightClass |
| UITraitCollection.verticalBarEdge | IosInfo.barSide, logical start/end |
| UIView.safeAreaInsets | IosInfo.safeArea |

New APIs are accessed by their public Objective-C names and guarded at runtime.
An unavailable class/selector reports unsupported; an interaction without a
current hinge reports loading or notAvailable. This allows the source to compile
against older SDKs without inventing measurements. The Apple hinge and
reserved-region documentation is beta; the public binding must be retested as
Apple finalizes the APIs.

Reserved frames include the native margins already. The extraSpace property is
metadata; do not add it again. Inactive regions are retained in snapshots so the
consumer can decide which facts matter. Region activity does not mean a physical
screen is active. Region IDs are session-scoped and cannot be persisted as device
identifiers. A preferred bar edge does not assert that a toolbar exists.

Native coordinates are checked against current Flutter size. The widget helper
then supports translation and positive scale. Geometry from another view or an
unsupported host transform must not be treated as valid local geometry.

## Sources

- [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction)
- [UIView](https://developer.apple.com/documentation/uikit/uiview)
- [UITraitCollection](https://developer.apple.com/documentation/uikit/uitraitcollection)
- [Flutter plugin development](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Flutter UIScene migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
