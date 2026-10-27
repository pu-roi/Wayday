import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/persist_safely.dart';
import '../data/group_repository.dart';
import '../domain/errand_group.dart';

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
  @override
  List<ErrandGroup> build() {
    final groups = ref.read(groupRepositoryProvider).read();
    _groupSequence = _nextSequence(groups.map((group) => group.id), 'group-');
    _itemSequence = _nextSequence(
      groups.expand((group) => group.items.map((item) => item.id)),
      'item-',
    );
    return groups;
  }

  String reserveGroupId() => 'group-${_groupSequence++}';
  String reserveItemId() => 'item-${_itemSequence++}';
  void _commit(List<ErrandGroup> groups) {
    state = List.unmodifiable(groups);
    unawaited(
      persistSafely(
        ref.read(groupRepositoryProvider).save(state),
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
  void restore(List<ErrandGroup> groups) => _commit(groups);
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
