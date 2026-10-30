import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';

const pin = PlaceIntent(
  kind: PlaceKind.specific,
  label: 'Test place',
  latitude: 14.58,
  longitude: 121.06,
  source: 'manual',
);
Map<String, dynamic> need(String id) => {
  'id': id,
  'query': 'grocery store',
  'category': 'grocery',
  'items': ['bigas', 'toyo'],
  'after': <String>[],
  'durationMinutes': 40,
  'question': null,
  'title': null,
  'optional': null,
  'timing': null,
  'minute': null,
};
PlanningBudget budget() =>
    PlanningBudget(read: () async => null, write: (_) async {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('configured Gemini has no local finite-attempt gate', () async {
    const channel = MethodChannel('wayday/test-paid-gate');
    var dispatched = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'interpretationStatus') return {'state': 'missing'};
      if (call.method == 'geminiStatus') {
        return {'configured': true, 'remainingGenerations': 0};
      }
      dispatched = true;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(
      GeminiInterpreter(channel: channel).interpret(
        DayPlan(
          errands: [const Errand(id: 'a', title: 'Grocery')],
        ),
      ),
      throwsA(
        isA<PlanningFailure>().having((e) => e.kind, 'kind', 'interrupted'),
      ),
    );
    expect(dispatched, isTrue);
  });
  test(
    'serialized accounting counts matrix elements and persists across instances',
    () async {
      String? saved;
      final b = PlanningBudget(
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
      );
      await b.reserve('matrix', 36, daily: 72, monthly: 72);
      await b.reserve('matrix', 36, daily: 72, monthly: 72);
      final reopened = PlanningBudget(
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
      );
      await expectLater(
        reopened.reserve('matrix', 1, daily: 72, monthly: 72),
        throwsA(isA<PlanningFailure>().having((e) => e.kind, 'kind', 'quota')),
      );
      expect(saved, isNot(contains('latitude')));
      final failed = PlanningBudget(
        read: () async => 'corrupt',
        write: (_) async {},
      );
      await expectLater(
        failed.reserve('routes', 1, daily: 5, monthly: 5),
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'accounting'),
        ),
      );
    },
  );
  test(
    'Gemini handles sentence input without sending stored map coordinates or original renamed text',
    () async {
      const channel = MethodChannel('wayday/test-gemini');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? request;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'interpretationStatus') return {'state': 'missing'};
        if (call.method == 'geminiStatus') {
          return {'configured': true, 'remainingGenerations': 1};
        }
        request = (call.arguments as Map)['body'] as String;
        return jsonEncode({
          'candidates': [
            {
              'finishReason': 'STOP',
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'needs': [need('a')],
                      'additions': <Object>[],
                    }),
                  },
                ],
              },
            },
          ],
        });
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final day = DayPlan(
        errands: [
          const Errand(
            id: 'a',
            title: 'Grocery',
            originalText: 'Old renamed activity',
            notes: 'Bili ng bigas and toyo, then kain tayo.',
            placeIntent: pin,
          ),
        ],
      );
      final result = await GeminiInterpreter(channel: channel).interpret(day);
      expect(result.needs.single.items, ['bigas', 'toyo']);
      expect(request, contains('Bili ng bigas and toyo'));
      expect(request, isNot(contains('14.58')));
      expect(request, isNot(contains('121.06')));
      expect(request, isNot(contains('Old renamed activity')));
    },
  );
  test(
    'interpretation rejects foreign references and preserves explicit values',
    () {
      final day = DayPlan(
        errands: [
          const Errand(
            id: 'a',
            title: 'Food',
            notes: 'My own text',
            timing: TimingRule.arriveBy,
            minute: 540,
            durationMinutes: 25,
            durationConfirmed: true,
            confirmedFields: {'optional', 'dependencies'},
            afterErrandIds: [],
            placeIntent: pin,
          ),
        ],
      );
      final data = need('a')
        ..addAll({
          'optional': true,
          'timing': 'finishBefore',
          'minute': 600,
          'after': ['missing'],
        });
      expect(
        () => Interpretation.fromJson({
          'needs': [data],
        }, day),
        throwsFormatException,
      );
      data['after'] = <String>[];
      final applied = Interpretation.fromJson({
        'needs': [data],
      }, day).needs.single.apply(day.errands.single);
      expect(applied.durationMinutes, 25);
      expect(applied.timing, TimingRule.arriveBy);
      expect(applied.minute, 540);
      expect(applied.optional, isFalse);
      expect(applied.notes, 'My own text');
      expect(applied.placeIntent.latitude, 14.58);
    },
  );
  test(
    'matrix uses correct resource, actual mode, signing restrictions and asymmetric unreachable cells',
    () async {
      final roads = PlanningRoads(
        MockClient((r) async {
          expect(r.url.path, '/distanceMatrix/v2:computeRouteMatrix');
          expect(r.headers['X-Android-Package'], 'test.app');
          expect(r.headers['X-Android-Cert'], 'ABC');
          final body = jsonDecode(r.body) as Map;
          expect(body['travelMode'], 'TWO_WHEELER');
          expect(
            (((body['destinations'] as List).first as Map)['waypoint']
                as Map)['location'],
            isNotNull,
          );
          expect(body['routingPreference'], 'TRAFFIC_AWARE');
          expect(body['departureTime'], endsWith('Z'));
          return http.Response(
            jsonEncode([
              {
                'originIndex': 0,
                'destinationIndex': 0,
                'status': <String, dynamic>{},
                'condition': 'ROUTE_EXISTS',
                'duration': '0s',
              },
              {
                'originIndex': 0,
                'destinationIndex': 1,
                'status': <String, dynamic>{},
                'condition': 'ROUTE_EXISTS',
                'duration': '123.2s',
              },
              {
                'originIndex': 1,
                'destinationIndex': 0,
                'status': <String, dynamic>{},
                'condition': 'ROUTE_NOT_FOUND',
              },
              {
                'originIndex': 1,
                'destinationIndex': 1,
                'status': <String, dynamic>{},
                'condition': 'ROUTE_EXISTS',
                'duration': '0s',
              },
            ]),
            200,
          );
        }),
        budget(),
        apiKey: 'fixture',
        identity: () async => {'package': 'test.app', 'certificate': 'ABC'},
      );
      final result = await roads.matrix(DayPlan(errands: []), [
        const PlanCandidate(key: '@start', place: pin, errandIds: {}),
        const PlanCandidate(key: '@end', place: pin, errandIds: {}),
      ]);
      expect(result['matrix'], [
        [0, 124],
        [null, 0],
      ]);
    },
  );
  test(
    'provider failure returns typed error without inventing route data',
    () async {
      final roads = PlanningRoads(
        MockClient(
          (_) async =>
              http.Response('private diagnostic should never be shown', 403),
        ),
        budget(),
        apiKey: 'fixture',
        identity: () async => {'package': 'app', 'certificate': 'ABC'},
      );
      await expectLater(
        roads.matrix(DayPlan(errands: []), [
          const PlanCandidate(key: '@start', place: pin, errandIds: {}),
          const PlanCandidate(key: '@end', place: pin, errandIds: {}),
        ]),
        throwsA(isA<PlanningFailure>().having((e) => e.kind, 'kind', 'access')),
      );
      expect(() => decodePolyline('~'), throwsA(isA<PlanningFailure>()));
    },
  );
  test(
    'v2 additive upgrade preserves Today and restores accepted tasks/progress after restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('wayday-planning-');
      final file = File('${dir.path}/test.sqlite');
      var db = WaydayDatabase(NativeDatabase(file));
      final day = DayPlan(
        errands: [
          const Errand(id: 'a', title: 'Collect', placeIntent: pin),
          const Errand(
            id: 'b',
            title: 'Submit',
            placeIntent: pin,
            afterErrandIds: ['a'],
          ),
        ],
      );
      final local = await LocalRepositories.open(database: db);
      await local.today.save(day);
      await db.customStatement('DROP TABLE accepted_itineraries');
      await db.customStatement('DROP TABLE review_trips');
      await db.customStatement('DROP TABLE clarification_sessions');
      await db.customStatement('DROP TABLE IF EXISTS recommendation_drafts');
      await db.customStatement('PRAGMA user_version=2');
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      final repo = SqliteItineraryRepository(db, (_) => GooglePinLease());
      final plan = AcceptedItinerary(
        day: day,
        stops: [
          const ItineraryStop(pin, ['a', 'b']),
        ],
        acceptedAt: DateTime.now(),
      );
      expect(() => plan.complete('b'), throwsA(isA<PlanningFailure>()));
      await repo.save(plan.complete('a'));
      await db.close();
      db = WaydayDatabase(NativeDatabase(file));
      try {
        final restored = await SqliteItineraryRepository(
          db,
          (_) => GooglePinLease(),
        ).read();
        expect(restored!.completed, {'a'});
        expect(restored.stops.single.errandIds, ['a', 'b']);
        final today = await LocalRepositories.open(database: db);
        expect(today.today.read().errands.map((e) => e.title), [
          'Collect',
          'Submit',
        ]);
        final json = restored.toJson();
        json['completed'] = ['b'];
        expect(
          () => AcceptedItinerary.fromJson(json, (_) => GooglePinLease()),
          throwsFormatException,
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'durable Google references never copy temporary coordinates into an itinerary',
    () {
      final lease = GooglePinLease()
        ..acquiredAt = DateTime.now()
        ..latitude = 14.58
        ..longitude = 121.06;
      final place = PlaceIntent(
        kind: PlaceKind.providerReference,
        label: 'My grocery choice',
        provider: 'google_ui_kit',
        providerPlaceId: 'fixture-place',
        googlePin: lease,
      );
      final p = AcceptedItinerary(
        day: DayPlan(
          errands: [Errand(id: 'a', title: 'Grocery', placeIntent: place)],
        ),
        stops: [
          ItineraryStop(place, ['a']),
        ],
        acceptedAt: DateTime.now(),
      );
      final encoded = jsonEncode(p.toJson());
      expect(encoded, isNot(contains('14.58')));
      expect(encoded, isNot(contains('121.06')));
      expect(encoded, isNot(contains('polyline')));
      expect(encoded, isNot(contains('arrival')));
      final expired = AcceptedItinerary.fromJson(
        p.toJson(),
        (_) => GooglePinLease(),
      );
      expect(expired.stops.single.place.hasCoordinates, isFalse);
      expect(expired.stops.single.errandIds, ['a']);
    },
  );
}
