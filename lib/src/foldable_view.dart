import 'models.dart';

/// A measurement handle associated with one Flutter view.
///
/// Cancel your subscriptions, not the shared handle. Native observation stops
/// when no active stream subscriptions or one-shot reads remain.
abstract class FoldableView {
  /// Opaque, engine-local identifier of the measured view.
  int get viewId;

  /// Reads layout data once; native failures throw FoldableError.
  Future<FoldableData> read({Duration timeout = const Duration(seconds: 5)});

  /// Shared replay stream. Cancel only your own subscription.
  Stream<FoldableData> watch();

  /// Reads hinge angles once, separately from layout data.
  Future<FoldAngles> readAngles({
    Duration timeout = const Duration(seconds: 5),
  });

  /// Shared angle stream; listen only while an angle effect is active.
  Stream<FoldAngles> watchAngles();
}
