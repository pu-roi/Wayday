import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/domain/analysis_run.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'SQLite close/reopen preserves pending run and rejects older state merges',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wayday-fresh-analysis-',
      );
      final file = File('${directory.path}/app.sqlite');
      var database = WaydayDatabase(NativeDatabase(file));
      final day = fixture();
      final key = clarificationSourceKey(day);
      final result = await Interpreter().interpret(day);
      final pending = AnalysisRun(
        id: 'synthetic-run',
        body: interpretationRequest(day),
        errands: day.errands,
      );
      final session = ClarificationSession(
        analysis: AnalysisState(
          revision: 1,
          errands: day.errands,
          result: result,
          pending: pending,
        ),
      );
      await SqliteClarificationRepository(database).save(key, session);
      await database.close();
      database = WaydayDatabase(NativeDatabase(file));
      final repository = SqliteClarificationRepository(database);
      final restored = await repository.read(key);
      expect(restored.analysis!.pending!.id, 'synthetic-run');
      expect(restored.analysis!.pending!.body, pending.body);
      restored.analysis = AnalysisState(
        revision: 2,
        errands: day.errands,
        result: result,
        activeId: pending.id,
      );
      await repository.save(key, restored);
      await repository.save(key, session);
      final latest = await repository.read(key);
      expect(latest.analysis!.activeId, pending.id);
      expect(latest.analysis!.pending, isNull);
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
