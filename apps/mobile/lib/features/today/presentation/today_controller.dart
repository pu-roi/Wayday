import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_workspace.dart';
import '../../places/domain/place_intent.dart';
import '../data/day_repository.dart';
import '../domain/day.dart';

final dayRepositoryProvider = Provider<DayRepository>((ref) {
  final workspace = ref.watch(localWorkspaceProvider);
  return workspace == null
      ? MemoryDayRepository()
      : LocalDayRepository(workspace);
});
final todayProvider = NotifierProvider<TodayController, DayPlan>(
  TodayController.new,
);

class TodayController extends Notifier<DayPlan> {
  @override
  DayPlan build() => ref.read(dayRepositoryProvider).read();

  void _commit(DayPlan day) {
    day = day.copyWith(revision: state.revision + 1);
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
          Errand(id: const Uuid().v4(), title: title, originalText: title),
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
    final idMap = <String, String>{
      for (final item in errands)
        item.id:
            state.errands
                .where(
                  (e) =>
                      e.sourceGroupId == groupId && e.sourceItemId == item.id,
                )
                .firstOrNull
                ?.id ??
            const Uuid().v4(),
    };
    for (final item in errands) {
      if (state.errands.any(
        (existing) =>
            existing.sourceGroupId == groupId &&
            existing.sourceItemId == item.id,
      )) {
        continue;
      }
      copies.add(
        item.copyForToday(
          newId: idMap[item.id]!,
          groupId: groupId,
          idMap: idMap,
        ),
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
  bool applyReview(DayPlan day, {required int expectedRevision}) {
    if (state.revision != expectedRevision) return false;
    _commit(day);
    return true;
  }

  void clear() => _commit(state.copyWith(errands: []));
  void setDate(DateTime value) =>
      _commit(state.copyWith(date: calendarDate(value)));
  void setEndpoint({
    required bool start,
    required String value,
    PlaceIntent? place,
  }) {
    if (value.trim().isEmpty) return;
    _commit(
      start
          ? state.copyWith(from: value.trim(), fromPlace: place)
          : state.copyWith(to: value.trim(), toPlace: place),
    );
  }

  void setProfile(TravelProfile value) =>
      _commit(state.copyWith(profile: value));
  void setTimes({int? departure, int? deadline}) =>
      _commit(state.copyWith(departure: departure, deadline: deadline));
}
