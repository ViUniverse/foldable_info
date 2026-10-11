import 'dart:ui' show Rect;
import 'models.dart';

/// Shares source/time across a snapshot while keeping group failures independent.
class DecodeValues {
  DecodeValues(this.source) : readAt = DateTime.now().toUtc();

  final DataSource source;
  final DateTime readAt;
  FoldableError? error;

  DataValue<T> ready<T>(T value) =>
      DataValue.ready(value, source: source, readAt: readAt);

  DataValue<T> read<T>(
    T Function() decode, {
    String message = 'Invalid native measurement group.',
  }) {
    try {
      return ready(decode());
    } catch (_) {
      error ??= FoldableError(ErrorCode.badData, message);
      return DataValue.error(error!, source: source);
    }
  }
}

ViewState nativeViewState({required bool attached, required bool available}) =>
    switch ((attached, available)) {
      (false, _) => ViewState.loading,
      (true, false) => ViewState.paused,
      (true, true) => ViewState.ready,
    };

AreaDirection areaDirection(Rect rect) => switch ((rect.width, rect.height)) {
  (final width, final height) when width == height => AreaDirection.unknown,
  (final width, final height) when width > height => AreaDirection.leftToRight,
  _ => AreaDirection.topToBottom,
};
