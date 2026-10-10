## 0.1.1

- Use Dart language 3.9 while keeping Flutter 3.38 as the minimum. This also
  accepts the Dart 3.10 beta bundled with Flutter 3.38.0 without a prerelease
  SDK constraint. No native behavior or public measurement API changed.

## 0.1.0

Initial public release, focused on iOS.

- Read/watch view geometry and available native fold measurements without context.
- Read/watch hinge angles separately from layout updates.
- Add runtime-guarded public UIKit hinge status, reserved regions and size traits.
- Preserve availability, source, UTC observation time and immutable lists.
- Share native subscriptions with independent listener cancellation.
- Convert areas into widget coordinates with transform/staleness checks.
- Include a fake service, standalone example, tests and CI.
- Android/web/desktop use Flutter display-feature fallback; native Android angles
  and iOS native views beyond the registrar view are not supported.

Migration from the workspace prototype: UI providers/builders moved into the
Vi design system under Vi-prefixed names. `FoldableInfo.of(context)` was removed;
use `instance.forView(view)` for explicit view selection. This standalone package
has no provider or design-system dependency.
