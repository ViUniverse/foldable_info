# Releasing

1. Confirm release scope and unsupported platforms in README/CHANGELOG.
2. Update the version in pubspec.yaml and ios/foldable_info.podspec together.
3. Run formatting, analysis, plugin and example tests; build the iOS example.
   Native changes require integration tests on a supported iOS runtime and an
   older runtime without the new fold APIs.
4. Run `flutter pub publish --dry-run` in the standalone package. Review the file
   list, metadata and license. The package must have no workspace resolution or
   unpublished dependencies. The example uses `path: ../` for foldable_info.
5. Push a reviewed commit to main and confirm CI results. Record tested Flutter,
   Xcode and runtime versions in doc/verification.md.
6. With an authorized pub.dev account, run `flutter pub publish`. Verify the
   resulting hosted version before creating/pushing a `v<version>` Git tag and
   GitHub release. A dry run is not a publication or a reserved package name.

The initial GitHub upload prepares a 0.1.0 candidate; it does not by itself prove
that a pub.dev upload has happened. The source workspace may retain
`resolution: workspace`; the exporter removes it only from the standalone copy.
