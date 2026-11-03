import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/planning/data/alternative_route_client.dart';
import 'package:wayday/core/network/gateway_client.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/recommendation_page.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'automatic_route_refresh_test.dart' show CountingUnderstanding;
import 'helpers/planning_fixtures.dart';

class LimitedRoads extends Roads {
  bool limited = true;
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    calls++;
    await gate?.future;
    if (limited) {
      throw const PlanningFailure(
        'Route calculation is temporarily unavailable. Try again later.',
        kind: 'quota',
        providerStatus: 429,
      );
    }
    return super.matrix(day, points, cancelled: cancelled);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'navigation availability copy keeps provider diagnostics separate',
    () async {
      for (final status in [
        nav.NavigationRouteStatus.quotaExceeded,
        nav.NavigationRouteStatus.quotaCheckFailed,
      ]) {
        final failure = TripNavigation.routeFailure(status);
        expect(failure.kind, 'navigation_${status.name}');
        expect(failure.message, isNot(contains('quota')));
        expect(failure.message, contains('Try another map'));
      }
      var calls = 0;
      final gateway = GatewayClient(
        baseUrl: 'https://fixture.invalid',
        token: () async => 'fixture',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"error":{"code":"provider_quota"}}', 429);
        }),
      );
      addTearDown(gateway.client.close);
      await expectLater(
        AlternativeRouteClient(enabled: true, gateway: gateway).route([
          const NavigationCoordinate(latitude: 14.5, longitude: 121),
          const NavigationCoordinate(latitude: 14.6, longitude: 121.1),
        ], TravelProfile.walk),
        throwsA(
          isA<PlanningFailure>()
              .having((e) => e.kind, 'diagnostic kind', 'alternative_429')
              .having(
                (e) => e.message,
                'plain explanation',
                isNot(contains('quota')),
              ),
        ),
      );
      expect(calls, 1);
    },
  );
  testWidgets('a discovery quota failure cannot become a road-only retry', (
    tester,
  ) async {
    final roads = LimitedRoads();
    final model = PlanningController(
      fixture().copyWith(
        errands: const [Errand(id: 'a', title: 'Groceries')],
      ),
      Interpreter(),
      roads,
      MemoryItineraryRepository(),
    );
    addTearDown(model.dispose);
    addTearDown(roads.client.close);
    await model.understand();
    model.applyReview();
    model.recommendationFailure = const PlanningFailure(
      'Search temporarily unavailable.',
      kind: 'quota',
    );
    model.error = model.recommendationFailure!.message;
    expect(model.unresolved, isNotEmpty);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: RecommendationPage(
            model: model,
            onChange: (_) {},
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Retry route update'),
          )
          .onPressed,
      isNull,
    );
    expect(roads.calls, 0);
  });
  test(
    'HTTP 429 remains diagnostic but user wording is plain and explicitly retryable',
    () async {
      var requests = 0;
      final roads = PlanningRoads(
        MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({'error': 'upstream rate limit'}),
            429,
          );
        }),
        PlanningBudget(read: () async => null, write: (_) async {}),
        apiKey: 'fixture-only',
        identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
      );
      addTearDown(roads.client.close);
      await expectLater(
        roads.matrix(fixture(), [
          PlanCandidate(key: 'one', place: pin, errandIds: {'a'}),
          PlanCandidate(
            key: 'two',
            place: const PlaceIntent(latitude: 14.59, longitude: 121.07),
            errandIds: {'b'},
          ),
        ]),
        throwsA(
          isA<PlanningFailure>()
              .having((e) => e.kind, 'kind', 'quota')
              .having((e) => e.providerStatus, 'HTTP status', 429)
              .having(
                (e) => e.message,
                'user explanation',
                'Route calculation is temporarily unavailable. Try again later.',
              ),
        ),
      );
      expect(requests, 1);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'quota recovery stays enabled at text $scale and retries roads once without interpretation',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final roads = LimitedRoads(), interpreter = CountingUnderstanding();
        final model = PlanningController(
          fixture(),
          interpreter,
          roads,
          MemoryItineraryRepository(),
          solver: (input) async => solveDay(input),
        );
        addTearDown(model.dispose);
        addTearDown(roads.client.close);
        await model.understand();
        model.applyReview();
        await model.calculate();
        expect(model.recommendationFailure?.kind, 'quota');
        final choices = Map.of(model.displayChoices);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: AnimatedBuilder(
                animation: model,
                builder: (context, _) => RecommendationPage(
                  model: model,
                  onChange: (_) {},
                  onContinue: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, 'Retry route update');
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(find.text('Plan paused'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 30));
        expect(roads.calls, 1, reason: 'No automatic quota retry.');
        roads.limited = false;
        roads.gate = Completer<void>();
        await tester.runAsync(() async {
          await tester.tap(button);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        expect(roads.calls, 2);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Updating route…'),
              )
              .onPressed,
          isNull,
        );
        roads.gate!.complete();
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(model.proposalReady, isTrue, reason: model.error);
        expect(find.widgetWithText(FilledButton, 'Start trip'), findsOneWidget);
        expect(roads.calls, 2);
        expect(interpreter.calls, 1);
        expect(model.displayChoices, choices);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
