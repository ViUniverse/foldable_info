# Verified coverage

Release candidate: 0.1.0. Native Android angles are outside this release.

The first iOS implementation was exercised on the Duo iOS 27.1 simulator and
an iPad Pro 11-inch M5 simulator running iOS 26.2. Duo tests included several fold
poses; the older runtime retained safe area/size classes and reported newer fold
APIs as unsupported. Simulator results do not certify physical devices or every
UIKit container. UIKit toolbar enumeration and physical screen identity are not
features of this release.

Toolchain available for the release check: Flutter 3.47.6, Dart 3.13.5, Xcode 27.1.
The declared minimum is Flutter 3.38 / Dart 3.10 / iOS 15. CI includes Dart checks
on Flutter 3.38 and stable, but a configuration is not evidence of a completed run.
Older SDK builds, iOS 15 and physical device tests remain unverified.

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
