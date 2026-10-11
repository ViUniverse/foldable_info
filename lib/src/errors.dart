import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'models.dart';

FoldableError asFoldError(Object error) {
  if (error is FoldableError) return error;
  if (error is TimeoutException) {
    return const FoldableError(ErrorCode.timeout, 'Native read timed out.');
  }
  if (error is MissingPluginException) {
    return const FoldableError(
      ErrorCode.noPlugin,
      'foldable_info is not registered in this engine.',
    );
  }
  if (error is PlatformException) {
    final code =
        ErrorCode.values.firstWhereOrNull((code) => code.name == error.code) ??
        ErrorCode.nativeError;
    return FoldableError(code, error.message ?? 'Native operation failed.');
  }
  return const FoldableError(ErrorCode.badData, 'Invalid native data.');
}

FoldableData errorData(FoldableData last, FoldableError error) => last.copyWith(
  revision: last.revision + 1,
  error: error,
  areas: DataValue.error(error),
  folds: DataValue.error(error),
  ios: DataValue.error(error),
  isFoldable: DataValue.error(error),
);
