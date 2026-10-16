import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  List<ErrandGroup> build() => ref.read(groupRepositoryProvider).read();
  String reserveGroupId() => 'group-${_groupSequence++}';
  String reserveItemId() => 'item-${_itemSequence++}';
  void _commit(List<ErrandGroup> groups) {
    state = List.unmodifiable(groups);
    ref.read(groupRepositoryProvider).save(state);
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
