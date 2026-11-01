import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  test('public gateway pins the same instructions and schema as Android', () {
    const errand = Errand(id: 'fixture', title: 'Groceries');
    final context = ClarificationContext.create(
      errand,
      const ErrandNeed(
        id: 'fixture',
        query: 'grocery',
        category: 'grocery',
        question: 'Which items?',
      ),
      const [errand],
    );
    Map<String, dynamic> fixed(String body) =>
        Map<String, dynamic>.from(jsonDecode(body) as Map)..remove('contents');
    final contracts = {
      'interpretation': fixed(
        interpretationRequest(DayPlan(errands: const [errand])),
      ),
      'clarification': fixed(clarificationRequest(context, 'Rice', const [])),
    };
    final file = File(
      '../../services/api/src/wayday_api/gateway/contracts.json',
    );
    if (Platform.environment['WAYDAY_EXPORT_CONTRACTS'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(contracts)}\n',
      );
    }
    expect(
      jsonDecode(file.readAsStringSync()),
      contracts,
      reason:
          'Explicitly export/review changed gateway contracts; transport changes must not alter native cache identities.',
    );
  });
}
