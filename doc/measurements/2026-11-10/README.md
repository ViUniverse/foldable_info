# Duo region investigation — 2026-11-10

Source: example's explicit “Copy geometry snapshot” action, iPhone Duo simulator,
iOS 27.1, Xcode 27.1, Flutter 3.47.6 / Dart 3.13.5. JSON is unmodified app output;
UTC capture times and per-session revisions are inside each file. Values below
are logical pixels. No physical device was measured.

| Capture | View | Active blocked frame sizes | Division | Margins L/T/R/B |
| --- | --- | --- | --- | --- |
| [Closed](closed.json) | 466 × 678 | 37 × 37 and 84 × 170 | None reported | Both occlusions: 0/0/0/0 |
| [Partial landscape](partial-landscape.json) | 951 × 669 | 84 × 120; separate 58 × 37 camera-shaped region inactive | 40 × 669, active | Division: 20/0/20/0; occlusions: zero |
| [Partial portrait](partial-portrait.json) | 669 × 951 | 134 × 82; separate 37 × 58 region inactive | 669 × 40, active | Division: 0/20/0/20; occlusions: zero |
| [Flat portrait](flat-portrait.json) | 669 × 951 | 134 × 82; separate 37 × 58 region inactive | 669 × 40, inactive | Division: 0/20/0/20; occlusions: zero |

The overlay places the larger active region over the visible system status
cluster. UIKit identifies it only as occlusion, so the public API does not claim
a camera/status subtype. Multiple regions coexist and must all be considered.

This run reproduced a change from a vertical 84-wide region to a horizontal
134-wide region on rotation. The customer's exact 144-wide or 84 × 174 frames
were not reproduced. Their original build, status contents and capture timing
are not available, so those exact differences remain unexplained. These numbers
are evidence for these configurations, not constants for layout.

In these captures, occlusion margins are zero; adding margins cannot fix a
missing status region. Division margins are nonzero but already contained in
the reported 40-pixel frame. Double-inflating would create an 80-pixel gap.

During a later rapid rotation sequence, the app briefly displayed a status rect
at the previous orientation before a subsequent layout revision corrected it.
This was observed in the runtime UI, not recorded in these settled snapshots.
It reinforces the need to consume live geometry and record later revisions;
this work does not claim to eliminate every UIKit transition timing issue.

For reproducibility: launch the standalone example, select closed / partially
open / open in Device Hub, rotate with the device controls, wait for layout to
settle, then copy the snapshot. For images, `simctl io ... screenshot --display=1`
captures the cover; `--display=3` captured the inner display in this simulator.
Check `simctl io ... enumerate` first: display IDs are not portable.
