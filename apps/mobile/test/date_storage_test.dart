import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/planning/data/review_trip_repository.dart';

void main() {
  test(
    'date-selection JSON survives close/reopen without changing review identity',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-date-');
      final file = File('${dir.path}/test.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      var repository = await SqliteDayRepository.open(db);
      final original = repository.read();
      await repository.save(
        original.copyWith(date: '2026-11-05', dateSelected: true, revision: 1),
      );
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      repository = await SqliteDayRepository.open(db);
      expect(repository.read().date, '2026-11-05');
      expect(repository.read().dateSelected, isTrue);
      expect(
        reviewTripSourceKey(original),
        reviewTripSourceKey(original.copyWith(dateSelected: true)),
      );
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
