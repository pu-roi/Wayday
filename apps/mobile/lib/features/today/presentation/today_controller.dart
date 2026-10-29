import 'dart:async';

import '../../../core/data/persist_safely.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/day_repository.dart';
import '../domain/day.dart';
import '../../errands/domain/errand_order.dart';
import '../../places/domain/place_intent.dart';

final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => MemoryDayRepository(),
);
final todayProvider = NotifierProvider<TodayController, DayPlan>(
  TodayController.new,
);

class TodayController extends Notifier<DayPlan> {
  int _nextId = 0;
  DayPlan? recoveredOrder;
  bool _disposed = false;
  @override
  DayPlan build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final day = ref.read(dayRepositoryProvider).read();
    _nextId = _nextSequence(day.errands.map((item) => item.id), const [
      'new-',
      'copy-',
    ]);
    final order = ErrandOrder.reconcile(day.errands);
    if (!order.changed) return day;
    recoveredOrder = day;
    final corrected = day.copyWith(
      errands: order.items,
      revision: day.revision + 1,
    );
    scheduleMicrotask(() {
      if (!_disposed && identical(state, corrected)) _persist(corrected);
    });
    return corrected;
  }

  void _commit(DayPlan day, {bool reconcile = true}) {
    final order = reconcile ? ErrandOrder.reconcile(day.errands) : null;
    state = day.copyWith(
      errands: order?.items ?? day.errands,
      revision: state.revision + 1,
    );
    _persist(state);
  }

  void _persist(DayPlan day) {
    unawaited(
      persistSafely(
        ref.read(dayRepositoryProvider).save(day),
        label: 'Today errands',
        onFailure: () => ref
            .read(saveFailuresProvider.notifier)
            .failed('Today errands', () => _commit(state)),
        onSuccess: () =>
            ref.read(saveFailuresProvider.notifier).saved('Today errands'),
      ),
    );
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
    final idMap = <String, String>{};
    for (final existing in state.errands) {
      if (existing.sourceGroupId == groupId && existing.sourceItemId != null) {
        idMap[existing.sourceItemId!] = existing.id;
      }
    }
    for (final item in errands) {
      idMap.putIfAbsent(item.id, () => 'copy-${_nextId++}');
    }
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
  void restore(DayPlan day, {bool reconcile = true}) =>
      _commit(day, reconcile: reconcile);
  void clear() => _commit(
    state.copyWith(
      errands: [],
      from: '',
      to: '',
      departure: 510,
      deadline: 1080,
      profile: TravelProfile.motor,
    ),
  );
  void setEndpoint({required bool start, required PlaceIntent value}) {
    if (value.label.trim().isEmpty) return;
    _commit(
      start
          ? state.copyWith(from: value.label.trim(), fromPlace: value)
          : state.copyWith(to: value.label.trim(), toPlace: value),
    );
  }

  void setProfile(TravelProfile value) =>
      _commit(state.copyWith(profile: value));
  void setDate(DateTime value) =>
      _commit(state.copyWith(date: calendarDate(value)));
  void setTimes({int? departure, int? deadline}) =>
      _commit(state.copyWith(departure: departure, deadline: deadline));
}

int _nextSequence(Iterable<String> ids, List<String> prefixes) {
  var next = 0;
  for (final id in ids) {
    for (final prefix in prefixes) {
      if (!id.startsWith(prefix)) continue;
      final sequence = int.tryParse(id.substring(prefix.length));
      if (sequence != null && sequence >= next) next = sequence + 1;
    }
  }
  return next;
}
