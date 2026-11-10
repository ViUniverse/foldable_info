# Geometry contract

All public sizes, frames and insets use Flutter logical pixels. Native iOS points
are mapped into the engine view. `ViewArea.rect` starts at the complete Flutter
view origin, not a Scaffold body, SafeArea, pane or scroll viewport.

| Field | Meaning | Consumer rule |
| --- | --- | --- |
| `rect` | Native reported frame in view coordinates | On iOS it already includes margins; use it directly for avoidance. It can extend outside the view. |
| `extraSpace` | Native margins metadata, nullable elsewhere | Do not inflate the iOS frame again. It is not additional safe-area padding. |
| `type` | `fold`, `hinge`, `blocked`, `unknown` | A division need not hide pixels. A blocked area can be hardware or system UI. |
| `isActive` | Whether the region currently affects this view | False is different from unknown. Inactive regions remain available for diagnostics and stable layout choices. |
| `cover` / `splitsView` | Occlusion and separation when reported | Unknown is not false. |
| `id` | Session-scoped region identifier | Never persist it as a hardware identity. |

Apple defines occlusions broadly, including cameras, Dynamic Island and window
controls. The API's kind does not identify camera vs status cluster. The plugin
therefore reports `blocked` instead of inventing a subtype. It does distinguish
these regions from folds/divisions. A safe inset or preferred bar side alone
does not enumerate every toolbar or status element.

## Nested widgets

After layout, call `FoldableSpace.toBox` with a RenderBox and the same FlutterView.
The result subtracts the widget offset, divides by positive axis-aligned scale,
and clips frames to that box. This handles SafeArea, translated panes and scroll
offsets without adding padding again. Margins metadata is scaled too.

For example, an iOS frame `[316, 0, 84, 170]` with left/right margins 20 is still
84 pixels wide. In a box starting at x=300 it starts at x=16; it is not 124 pixels
wide. A box already starting at x=400 has no overlap to avoid. A zero-width fold
line is preserved when it crosses the box. Rotation, skew, reflection and
perspective are explicitly rejected. Changed view size/DPR returns `oldData`.

## FoldableSafeArea

The widget first consumes Flutter SafeArea (unless opted out), measures its
remaining bounded box after layout, and chooses the largest empty rectangle
around matching, non-inactive areas. It preserves child identity, takes no
subscriptions itself, and does not add margins. `avoid` defaults to blocked
areas and hinge gaps; select fold explicitly to constrain content to one pane.
When there is no free space the child is clipped into an empty rectangle.

This rectangular strategy can reserve a full side strip for a corner obstacle.
It does not pack content around holes. Equal-area choices prefer top, then
leading side. Until the first measurement the child is invisible and not
interactive. After-layout measurements settle on a subsequent frame, including
when ancestors move. Unsupported transforms or missing/stale geometry fall back
to Flutter SafeArea alone; callers needing stricter behavior can gate content on
availability and `FoldableSpace.toBox` themselves.

## Diagnose an unexpected 84/144 pixel region

1. Run the example with the overlay visible and copy a geometry snapshot before
   and after each pose/rotation. Keep all regions, including inactive ones.
2. Record OS/SDK, simulator vs physical device, view size/DPR, safe insets,
   bar side, session/revision, frame and margins; note camera/status visibility.
3. Compare matching view-local geometry, not a clipped child frame with a full
   view frame. Check whether multiple blocked regions overlap.
4. Check later layout events after a transition before treating a frame as final.
5. Do not hard-code 84/144 or add margins again. A screenshot's width alone does
   not identify which system element the region represents.

The customer measurements are a report to reproduce, not a portable device
constant. See [verification](verification.md) for actual measured evidence.

Sources: [Apple ReservedRegion](https://developer.apple.com/documentation/uikit/uiview/reservedregion),
[Android folding features](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware).
