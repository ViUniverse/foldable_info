import 'package:flutter/widgets.dart';
import 'models.dart';

Map<Object?, Object?> wireMap(Object? value) =>
    Map<Object?, Object?>.from(value as Map);
void checkWire(Map<Object?, Object?> raw, int viewId) {
  if (raw['version'] != 1) {
    throw const FoldableError(
      ErrorCode.badVersion,
      'Unsupported native data version.',
    );
  }
  if (raw['viewId'] != viewId) {
    throw const FoldableError(
      ErrorCode.noView,
      'Native data belongs to another view.',
    );
  }
  if (raw['sessionId'] is! String || (raw['sessionId'] as String).isEmpty) {
    throw const FoldableError(
      ErrorCode.badData,
      'Missing measurement session.',
    );
  }
  final counter = raw['revision'] ?? raw['sequence'];
  if (counter is! int || counter < 0) {
    throw const FoldableError(
      ErrorCode.badData,
      'Invalid measurement counter.',
    );
  }
}

double wireNumber(Object? value) {
  final number = (value as num).toDouble();
  if (!number.isFinite) {
    throw const FoldableError(ErrorCode.badData, 'Non-finite native number.');
  }
  return number;
}

Rect wireRect(Object? raw) {
  final values = wireMap(raw);
  return Rect.fromLTWH(
    wireNumber(values['x']),
    wireNumber(values['y']),
    wireNumber(values['width']),
    wireNumber(values['height']),
  );
}

EdgeInsets wireInsets(Object? raw) {
  final values = wireMap(raw);
  return EdgeInsets.fromLTRB(
    wireNumber(values['left']),
    wireNumber(values['top']),
    wireNumber(values['right']),
    wireNumber(values['bottom']),
  );
}
