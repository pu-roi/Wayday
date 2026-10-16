import '../../errands/domain/errand.dart';
import '../domain/errand_group.dart';

abstract interface class GroupRepository {
  List<ErrandGroup> read();
  void save(List<ErrandGroup> groups);
}

class MemoryGroupRepository implements GroupRepository {
  List<ErrandGroup> _groups = List.unmodifiable([
    ErrandGroup(
      id: 'weekly',
      name: 'Weekly essentials',
      repeat: RepeatPattern.weekly,
      items: const [
        Errand(
          id: 'weekly-groceries',
          title: 'Stock up on groceries',
          notes: 'Vegetables\nFruits\nMeat',
        ),
        Errand(id: 'weekly-laundry', title: 'Pick up the laundry'),
        Errand(id: 'weekly-cat', title: 'Get cat food'),
      ],
    ),
    ErrandGroup(
      id: 'midweek',
      name: 'A little reset',
      items: const [
        Errand(id: 'midweek-pharmacy', title: 'Stop by the pharmacy'),
        Errand(
          id: 'midweek-coffee',
          title: 'Coffee and a quiet moment',
          optional: true,
        ),
      ],
    ),
  ]);
  @override
  List<ErrandGroup> read() => _groups;
  @override
  void save(List<ErrandGroup> groups) => _groups = List.unmodifiable(groups);
}
