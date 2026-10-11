import 'package:collection/collection.dart';
import 'models.dart';

const _layoutEquality = DeepCollectionEquality();

/// Timestamps and counters are observations, not changes to layout.
bool sameLayout(FoldableData previous, FoldableData next) =>
    previous.sessionId == next.sessionId &&
    _layoutEquality.equals(_layoutFields(previous), _layoutFields(next));

List<Object?> _layoutFields(FoldableData data) => [
  data.viewState,
  data.view,
  data.isFoldable,
  data.areas,
  data.folds,
  data.ios,
  data.error,
].map(_layoutValue).toList();

Object? _layoutValue(Object? value) => switch (value) {
  DataValue() => [
    value.state,
    _layoutValue(value.value),
    value.source,
    value.error,
  ],
  InfoModel() => value.fields.map(_layoutValue).toList(),
  List() => value.map(_layoutValue).toList(),
  _ => value,
};
