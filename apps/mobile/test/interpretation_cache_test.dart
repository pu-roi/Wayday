import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';

String answer(String body) {
  final request = jsonDecode(body) as Map;
  final input =
      jsonDecode(
            ((request['contents'] as List).single as Map)['parts'][0]['text']
                as String,
          )
          as List;
  return jsonEncode({
    'candidates': [
      {
        'finishReason': 'STOP',
        'content': {
          'parts': [
            {
              'text': jsonEncode({
                'needs': [
                  for (final e in input)
                    {
                      'id': e['id'],
                      'query': 'grocery',
                      'category': 'grocery',
                      'items': ['rice'],
                      'durationMinutes': 30,
                      'after': <String>[],
                      'question': null,
                      'title': null,
                      'optional': null,
                      'timing': null,
                      'minute': null,
                    },
                ],
                'additions': <Object>[],
              }),
            },
          ],
        },
      },
    ],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('wayday/cache-fixture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, Map<String, dynamic>> disk;
  late int requests;
  late bool configured;
  Completer<void>? delay;
  DayPlan day() => DayPlan(
    errands: const [
      Errand(
        id: 'a',
        title: 'Grocery',
        notes: 'Bili ng bigas and food supplies',
      ),
    ],
  );
  GeminiInterpreter interpreter() => GeminiInterpreter(channel: channel);
  setUp(() {
    disk = {};
    requests = 0;
    configured = true;
    delay = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'geminiStatus') {
        return {
          'configured': configured,
          'remainingGenerations': 0, // Legacy counters no longer gate requests.
        };
      }
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final body = args['body'] as String;
      switch (call.method) {
        case 'interpretationStatus':
          return disk[body] ?? {'state': 'missing'};
        case 'invalidateInterpretation':
          disk[body] = {'state': 'failed'};
          return null;
        case 'interpret':
          final prior = disk[body];
          if (prior?['state'] == 'completed') return prior!['response'];
          if (prior != null && args['retry'] != true) {
            throw PlatformException(code: 'interrupted');
          }
          requests++;
          disk[body] = {'state': 'pending'};
          await delay?.future;
          final raw = answer(body);
          disk[body] = {'state': 'completed', 'response': raw};
          return raw;
        default:
          throw MissingPluginException();
      }
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'more than three changed inputs process without app-imposed caps',
    () async {
      for (var i = 0; i < 4; i++) {
        await interpreter().interpret(
          day().copyWith(
            errands: [
              day().errands.single.copyWith(notes: 'Current grocery need $i'),
            ],
          ),
        );
      }
      expect(requests, 4);
    },
  );
  test(
    'recreated interpreter reuses durable answer offline without charging allowance',
    () async {
      await interpreter().interpret(day());
      expect(requests, 1);
      configured = false;
      final restored = await interpreter().interpret(day());
      expect(restored.needs.single.id, 'a');
      expect(requests, 1);
    },
  );
  test(
    'a route change reuses understanding, while changed notes send a fresh request',
    () async {
      final original = day();
      await interpreter().interpret(original);
      await interpreter().interpret(
        original.copyWith(
          date: '2026-12-01',
          departure: 600,
          deadline: 1200,
          profile: TravelProfile.sedan,
          from: 'Another starting point',
          revision: 99,
        ),
      );
      expect(requests, 1);
      final edited = original.copyWith(
        errands: [original.errands.single.copyWith(notes: 'Medicine instead')],
      );
      await interpreter().interpret(edited);
      expect(requests, 2);
      // Undoing a change can use an earlier saved snapshot too.
      await interpreter().interpret(original);
      expect(requests, 2);
    },
  );
  test(
    'all interpretation-relevant edits change identity, including IDs and list order',
    () {
      final original = day();
      final e = original.errands.single;
      final key = interpretationRequest(original);
      final variants = [
        e.copyWith(title: 'Different title'),
        e.copyWith(notes: 'Different notes'),
        e.copyWith(optional: true),
        e.copyWith(durationMinutes: 45),
        e.copyWith(durationConfirmed: true),
        e.copyWith(timing: TimingRule.arriveBy, minute: 540),
        e.copyWith(confirmedFields: {'timing'}),
        const Errand(
          id: 'new-id',
          title: 'Grocery',
          notes: 'Bili ng bigas and food supplies',
        ),
      ];
      for (final changed in variants) {
        expect(
          interpretationRequest(original.copyWith(errands: [changed])),
          isNot(key),
        );
      }
      const second = Errand(id: 'b', title: 'Food');
      expect(
        interpretationRequest(original.copyWith(errands: [e, second])),
        isNot(interpretationRequest(original.copyWith(errands: [second, e]))),
      );
      expect(
        interpretationRequest(
          original.copyWith(
            errands: [
              e.copyWith(afterErrandIds: ['b']),
              second,
            ],
          ),
        ),
        isNot(interpretationRequest(original.copyWith(errands: [e, second]))),
      );
    },
  );
  test(
    'coordinate lease expiry does not spend money reinterpreting the same fixed-place errand',
    () {
      final lease = GooglePinLease()
        ..acquiredAt = DateTime.now()
        ..latitude = 14.58
        ..longitude = 121.06;
      final place = PlaceIntent(
        kind: PlaceKind.providerReference,
        label: 'User label',
        provider: 'google_ui_kit',
        providerPlaceId: 'test',
        googlePin: lease,
      );
      final source = day().copyWith(
        errands: [day().errands.single.copyWith(placeIntent: place)],
      );
      final before = interpretationRequest(source);
      lease.clear();
      expect(interpretationRequest(source), before);
      expect(before, isNot(contains('121.06')));
    },
  );
  test('changed flexible place preferences invalidate understanding', () {
    final source = day();
    final e = source.errands.single;
    final a = source.copyWith(
      errands: [
        e.copyWith(
          placeIntent: const PlaceIntent(
            kind: PlaceKind.search,
            label: 'Grocery',
            category: 'grocery',
            brand: 'SM',
          ),
        ),
      ],
    );
    final b = source.copyWith(
      errands: [
        e.copyWith(
          placeIntent: const PlaceIntent(
            kind: PlaceKind.search,
            label: 'Grocery',
            category: 'grocery',
            brand: 'Dali',
          ),
        ),
      ],
    );
    expect(interpretationRequest(a), isNot(interpretationRequest(b)));
  });
  test(
    'double taps and closing a screen while processing share one paid attempt',
    () async {
      delay = Completer<void>();
      final service = interpreter();
      final a = service.interpret(day());
      final b = service.interpret(day());
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      delay!.complete();
      await Future.wait([a, b]);
      await interpreter().interpret(day());
      expect(requests, 1);
    },
  );
  test(
    'check saved understanding never dispatches a missing or changed input',
    () async {
      await expectLater(
        interpreter().saved(day()),
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'cache_miss'),
        ),
      );
      expect(requests, 0);
      await interpreter().interpret(day());
      await interpreter().saved(day());
      expect(requests, 1);
      await expectLater(
        interpreter().saved(
          day().copyWith(
            errands: [
              day().errands.single.copyWith(notes: 'Different current need'),
            ],
          ),
        ),
        throwsA(isA<PlanningFailure>()),
      );
      expect(requests, 1);
    },
  );
  test(
    'interrupted and failed attempts require explicit retry rather than automatic payment',
    () async {
      final source = day();
      disk[interpretationRequest(source)] = {'state': 'pending'};
      await expectLater(
        interpreter().interpret(source),
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'interrupted'),
        ),
      );
      await expectLater(
        interpreter().interpret(source),
        throwsA(isA<PlanningFailure>()),
      );
      expect(requests, 0);
      await interpreter().retry(source);
      expect(requests, 1);
    },
  );
  test(
    'installation recovery never silently replaces lost understanding',
    () async {
      final source = day();
      disk[interpretationRequest(source)] = {'state': 'recovery'};
      await expectLater(
        interpreter().interpret(source),
        throwsA(
          isA<PlanningFailure>().having(
            (e) => e.message,
            'message',
            contains('installation recovery'),
          ),
        ),
      );
      expect(requests, 0);
      await interpreter().retry(source);
      expect(requests, 1);
    },
  );
  test(
    'invalid saved answer is rejected and marked failed without an automatic retry',
    () async {
      final source = day();
      disk[interpretationRequest(source)] = {
        'state': 'completed',
        'response': '{"wrong":true}',
      };
      await expectLater(
        interpreter().interpret(source),
        throwsA(
          isA<PlanningFailure>().having(
            (e) => e.kind,
            'kind',
            'interpretation',
          ),
        ),
      );
      expect(requests, 0);
      expect(disk.values.single['state'], 'failed');
      await interpreter().retry(source);
      expect(requests, 1);
    },
  );
  test(
    'canonical confirmation/dependency sets do not cause unnecessary cache misses',
    () {
      final source = day();
      final e = source.errands.single;
      final a = source.copyWith(
        errands: [
          e.copyWith(
            confirmedFields: {'place', 'duration'},
            afterErrandIds: ['b', 'c'],
          ),
          const Errand(id: 'b', title: 'Earlier visit'),
          const Errand(id: 'c', title: 'Another earlier visit'),
        ],
      );
      final b = source.copyWith(
        errands: [
          e.copyWith(
            confirmedFields: {'duration', 'place'},
            afterErrandIds: ['c', 'b'],
          ),
          const Errand(id: 'b', title: 'Earlier visit'),
          const Errand(id: 'c', title: 'Another earlier visit'),
        ],
      );
      expect(interpretationRequest(a), interpretationRequest(b));
    },
  );
  test(
    'completed legacy understanding is reused before generating typed output',
    () async {
      final body = legacyInterpretationRequest(day());
      disk[body] = {'state': 'completed', 'response': answer(body)};
      configured = false;
      final result = await interpreter().interpret(day());
      expect(result.needs.single.items, ['rice']);
      expect(requests, 0);
    },
  );
  for (final state in ['pending', 'failed']) {
    test(
      'a $state legacy outcome cannot silently retry through a schema upgrade',
      () async {
        disk[legacyInterpretationRequest(day())] = {'state': state};
        await expectLater(
          interpreter().interpret(day()),
          throwsA(isA<PlanningFailure>()),
        );
        expect(requests, 0);
      },
    );
  }
}
