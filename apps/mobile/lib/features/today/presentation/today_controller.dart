import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/day_repository.dart';
import '../domain/day.dart';

final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => MemoryDayRepository(),
);
final todayProvider = NotifierProvider<TodayController, DayPlan>(
  TodayController.new,
);

class TodayController extends Notifier<DayPlan> {
  int _nextId = 0;
  @override
  DayPlan build() => ref.read(dayRepositoryProvider).read();

  void _commit(DayPlan day) {
    ref.read(dayRepositoryProvider).save(day);
    state = day;
  }

  void add(String text) {
    final title = text.trim();
    if (title.isEmpty) return;
    _commit(
      state.copyWith(
        errands: [
          ...state.errands,
          Errand(id: 'new-${_nextId++}', title: title),
        ],
      ),
    );
  }

  void update(Errand errand) => _commit(
    state.copyWith(
      errands: [
        for (final item in state.errands)
          if (item.id == errand.id) errand else item,
      ],
    ),
  );
  int addGroup({required String groupId, required List<Errand> errands}) {
    final copies = <Errand>[];
    for (final item in errands) {
      if (state.errands.any(
        (existing) =>
            existing.sourceGroupId == groupId &&
            existing.sourceItemId == item.id,
      )) {
        continue;
      }
      copies.add(
        item.copyForToday(newId: 'copy-${_nextId++}', groupId: groupId),
      );
    }
    if (copies.isNotEmpty) {
      _commit(state.copyWith(errands: [...state.errands, ...copies]));
    }
    return copies.length;
  }

  void remove(String id) => _commit(
    state.copyWith(
      errands: state.errands.where((item) => item.id != id).toList(),
    ),
  );
  void restore(DayPlan day) => _commit(day);
  void clear() => _commit(state.copyWith(errands: []));
  void loadExample() => _commit(exampleDay());
  void setEndpoint({required bool start, required String value}) {
    if (value.trim().isEmpty) return;
    _commit(
      start
          ? state.copyWith(from: value.trim())
          : state.copyWith(to: value.trim()),
    );
  }

  void setProfile(TravelProfile value) =>
      _commit(state.copyWith(profile: value));
  void setTimes({int? departure, int? deadline}) =>
      _commit(state.copyWith(departure: departure, deadline: deadline));
}
