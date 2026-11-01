import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/planning/presentation/review_trip_details.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  testWidgets(
    'large text keeps long and missing endpoints reachable without motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const longName =
          'Pasukan sa barangay hall, malapit sa palengke at simbahan';
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ReviewTripDetails(
                day: fixture().copyWith(
                  fromPlace: const PlaceIntent(
                    label: 'Choose a starting point',
                  ),
                  toPlace: pin.withLabel(longName),
                ),
                initiallyExpanded: false,
                onDate: () {},
                onDeparture: () {},
                onDeadline: () {},
                onFrom: () {},
                onTo: () => changed = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Trip details'));
      await tester.pump();
      expect(find.text('Date').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Choose a map location'));
      await tester.pump();
      expect(find.text('Choose a map location').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text(longName));
      await tester.pump();
      await tester.tap(find.text(longName));
      expect(changed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every trip field is a named button with a full-field target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReviewTripDetails(
              day: fixture(),
              initiallyExpanded: true,
              onDate: () => calls.add('Date'),
              onDeparture: () => calls.add('Departure'),
              onDeadline: () => calls.add('Finish the day by'),
              onFrom: () => calls.add('From'),
              onTo: () => calls.add('To'),
            ),
          ),
        ),
      ),
    );
    for (final label in [
      'Date',
      'Departure',
      'Finish the day by',
      'From',
      'To',
    ]) {
      final field = find.bySemanticsLabel(RegExp('^$label, '));
      await tester.ensureVisible(field);
      expect(
        tester.getSemantics(field),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: tester.getSemantics(field).label,
        ),
      );
      final rect = tester.getRect(field);
      expect(rect.height, greaterThanOrEqualTo(48));
      await tester.tapAt(Offset(rect.right - 8, rect.center.dy));
    }
    expect(calls, ['Date', 'Departure', 'Finish the day by', 'From', 'To']);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('keyboard opens details and activates the date field', (
    tester,
  ) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ReviewTripDetails(
            day: fixture(),
            initiallyExpanded: false,
            onDate: () => changed = true,
            onDeparture: () {},
            onDeadline: () {},
            onFrom: () {},
            onTo: () {},
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Hide'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(changed, isTrue);
  });

  testWidgets('restored disclosure keeps its header consistent', (
    tester,
  ) async {
    final bucket = PageStorageBucket();
    var visible = true;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return visible
                    ? ReviewTripDetails(
                        day: fixture(),
                        initiallyExpanded: false,
                        onDate: () {},
                        onDeparture: () {},
                        onDeadline: () {},
                        onFrom: () {},
                        onTo: () {},
                      )
                    : const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    change(() => visible = false);
    await tester.pumpAndSettle();
    change(() => visible = true);
    await tester.pumpAndSettle();
    expect(find.text('Departure'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
  });
}
