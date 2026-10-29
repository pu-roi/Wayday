import 'errand.dart';

/// Stable topological ordering. Invalid inputs are preserved for correction.
class ErrandOrder {
  ErrandOrder._(this.items, this.issue, this.changed);
  final List<Errand> items;
  final String? issue;
  final bool changed;

  factory ErrandOrder.reconcile(List<Errand> source) {
    ErrandOrder invalid(String issue) =>
        ErrandOrder._(List.unmodifiable(source), issue, false);
    final byId = {for (final item in source) item.id: item};
    if (byId.length != source.length) {
      return invalid(
        'Some errands have duplicate identities. Review this list.',
      );
    }
    for (final item in source) {
      for (final id in item.afterErrandIds) {
        if (!byId.containsKey(id)) {
          return invalid(
            '“${item.title}” refers to an errand that is no longer available. Edit its After rules.',
          );
        }
      }
    }
    final remaining = [...source];
    final result = <Errand>[];
    final done = <String>{};
    while (remaining.isNotEmpty) {
      final index = remaining.indexWhere(
        (item) => item.afterErrandIds.every(done.contains),
      );
      if (index < 0) {
        return invalid(
          'The After rules form a circle. Edit them before planning.',
        );
      }
      final item = remaining.removeAt(index);
      result.add(item);
      done.add(item.id);
    }
    final changed = List.generate(
      source.length,
      (index) => source[index].id != result[index].id,
    ).any((value) => value);
    return ErrandOrder._(List.unmodifiable(result), null, changed);
  }
}
