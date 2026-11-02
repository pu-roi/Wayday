import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/data/gemini_request_client.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';

/// Offline harness: no credential, HTTP client or automatic model dispatch.
/// Human review flags attest semantic claims that JSON validation cannot prove.
void main() {
  final cases =
      (jsonDecode(
                File(
                  'test/fixtures/errand_understanding_cases.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  DayPlan day(Map<String, dynamic> c) => DayPlan(
    errands: [
      Errand(
        id: c['id'] as String,
        title: c['title'] as String,
        notes: c['notes'] as String,
      ),
    ],
  );
  test(
    'evaluation balances sixty cases across language, family and held-out split',
    () {
      expect(cases.length, 60);
      expect(cases.map((c) => c['id']).toSet().length, 60);
      expect(cases.map((c) => c['family']).toSet().length, 10);
      for (final language in ['en', 'fil', 'taglish']) {
        for (final split in ['development', 'heldout']) {
          expect(
            cases
                .where((c) => c['language'] == language && c['split'] == split)
                .length,
            10,
          );
        }
      }
      final export = Platform.environment['WAYDAY_ERRAND_EVAL_EXPORT'];
      if (export != null) {
        Directory(export).createSync(recursive: true);
        for (final c in cases) {
          File(
            '$export/${c['id']}.request.json',
          ).writeAsStringSync(interpretationRequest(day(c)));
        }
      }
    },
  );
  final responsePath = Platform.environment['WAYDAY_ERRAND_EVAL_RESPONSES'];
  if (responsePath != null) {
    test(
      'reviewed recorded model outputs meet intent and non-invention gates',
      () {
        final records =
            (jsonDecode(File(responsePath).readAsStringSync()) as List)
                .cast<Map<String, dynamic>>();
        expect(records.length, 60);
        final byId = {for (final record in records) record['caseId']: record};
        expect(byId.length, 60);
        var correct = 0;
        for (final c in cases) {
          final record = byId[c['id']]!;
          final reply = GeminiReply(
            interpretationRequest(day(c)),
            jsonEncode(record['response']),
          );
          final need = Interpretation.fromJson(
            reply.value,
            day(c),
          ).needs.single;
          final intentCorrect =
              need.locationIntent?.name == c['expectedLocationIntent'];
          final requiresQuestion =
              need.question?.trim().isNotEmpty == true &&
              need.questionRequired != false;
          final questionCorrect = requiresQuestion == c['essentialQuestion'];
          if (intentCorrect && questionCorrect) correct++;
          if (c['critical'] == true) {
            expect(
              intentCorrect && questionCorrect,
              isTrue,
              reason: c['id'] as String,
            );
          }
          if (c['forbidWholesalePrimary'] == true) {
            expect(
              need.searchIntent?.excludedPrimaryTypes,
              contains('wholesaler'),
              reason: c['id'] as String,
            );
            expect(
              need.searchIntent?.acceptableTypes,
              isNot(contains('wholesaler')),
            );
          }
          final families = (c['venueFamilies'] as List).cast<String>();
          if (families.isNotEmpty) {
            expect(
              need.searchIntent,
              isNotNull,
              reason: '${c['id']}: usable venue hints',
            );
            expect(
              need.searchIntent!.acceptableTypes.any(families.contains),
              isTrue,
              reason: '${c['id']}: appropriate venue family',
            );
          }
          for (final flag
              in (c['requiresHumanReview'] as List).cast<String>()) {
            expect(
              record[flag],
              isTrue,
              reason: '${c['id']}: human review required for $flag',
            );
          }
        }
        expect(correct / cases.length, greaterThanOrEqualTo(.95));
      },
    );
  }
}
