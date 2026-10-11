import 'dart:ui' as ui;
import 'android_decoder.dart';
import 'ios_decoder.dart';
import 'models.dart';

export 'angle_decoder.dart' show decodeAngles;
export 'wire_reader.dart' show wireMap, checkWire;

FoldableData decodeData(
  Map<Object?, Object?> raw,
  ui.FlutterView view,
  bool paused,
) => switch (raw['platform']) {
  'android' => decodeAndroidData(raw, view, paused),
  _ => decodeIosData(raw, view, paused),
};
