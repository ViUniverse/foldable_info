import 'models.dart';
import 'wire_reader.dart';

FoldAngles decodeAngles(Map<Object?, Object?> raw, bool paused) {
  final source = raw['platform'] == 'android'
      ? DataSource.android
      : DataSource.ios;
  final DataValue<List<FoldAngle>> value;
  if (paused || raw['paused'] == true || raw['attached'] != true) {
    value = DataValue.notAvailable(source: source);
  } else {
    value = switch (raw['state']) {
      'ready' => DataValue.ready(
        [FoldAngle(degrees: wireNumber(raw['degrees']))],
        source: source,
        readAt: DateTime.now().toUtc(),
      ),
      'loading' => DataValue.loading(source: source),
      'notSupported' => DataValue.notSupported(source: source),
      'notAvailable' => DataValue.notAvailable(source: source),
      _ => DataValue.unknown(source: source),
    };
  }
  return FoldAngles(
    viewId: raw['viewId'] as int,
    sessionId: raw['sessionId'] as String,
    sequence: raw['sequence'] as int,
    angles: value,
  );
}
