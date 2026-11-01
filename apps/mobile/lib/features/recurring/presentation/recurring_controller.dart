import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/persist_safely.dart';
import '../data/group_repository.dart';
import '../domain/errand_group.dart';
import '../../errands/domain/errand_order.dart';

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => MemoryGroupRepository(),
);
final recurringProvider =
    NotifierProvider<RecurringController, List<ErrandGroup>>(
      RecurringController.new,
    );

class RecurringController extends Notifier<List<ErrandGroup>> {
  int _groupSequence = 0;
  int _itemSequence = 0;
  List<ErrandGroup>? recoveredOrder;
  bool _disposed = false;
  @override
  List<ErrandGroup> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final groups = ref.read(groupRepositoryProvider).read();
    _groupSequence = _nextSequence(groups.map((group) => group.id), 'group-');
    _itemSequence = _nextSequence(
      groups.expand((group) => group.items.map((item) => item.id)),
      'item-',
    );
    final corrected = [
      for (final g in groups)
        ErrandGroup(
          id: g.id,
          name: g.name,
          repeat: g.repeat,
          day: g.day,
          items: ErrandOrder.reconcile(g.items).items,
        ),
    ];
    final changed = List.generate(
      groups.length,
      (i) =>
          groups[i].items.map((e) => e.id).join('|') !=
          corrected[i].items.map((e) => e.id).join('|'),
    ).any((e) => e);
    if (changed) {
      recoveredOrder = groups;
      scheduleMicrotask(() {
        if (!_disposed && identical(state, corrected)) _persist(corrected);
      });
      return corrected;
    }
    return groups;
  }

  String reserveGroupId() => 'group-${_groupSequence++}';
  String reserveItemId() => 'item-${_itemSequence++}';
  void _commit(List<ErrandGroup> groups, {bool reconcile = true}) {
    state = List.unmodifiable([
      for (final group in groups)
        ErrandGroup(
          id: group.id,
          name: group.name,
          repeat: group.repeat,
          day: group.day,
          items: reconcile
              ? ErrandOrder.reconcile(group.items).items
              : group.items,
        ),
    ]);
    _persist(state);
  }

  void _persist(List<ErrandGroup> groups) {
    unawaited(
      persistSafely(
        ref.read(groupRepositoryProvider).save(groups),
        label: 'Recurring lists',
        onFailure: () => ref
            .read(saveFailuresProvider.notifier)
            .failed('Recurring lists', () => _commit(state)),
        onSuccess: () =>
            ref.read(saveFailuresProvider.notifier).saved('Recurring lists'),
      ),
    );
  }

  void save(ErrandGroup group) => _commit(
    state.any((item) => item.id == group.id)
        ? [
            for (final item in state)
              if (item.id == group.id) group else item,
          ]
        : [...state, group],
  );
  void remove(String id) =>
      _commit(state.where((item) => item.id != id).toList());
  void restore(List<ErrandGroup> groups, {bool reconcile = true}) =>
      _commit(groups, reconcile: reconcile);
}

int _nextSequence(Iterable<String> ids, String prefix) {
  var next = 0;
  for (final id in ids) {
    if (!id.startsWith(prefix)) continue;
    final sequence = int.tryParse(id.substring(prefix.length));
    if (sequence != null && sequence >= next) next = sequence + 1;
  }
  return next;
}
