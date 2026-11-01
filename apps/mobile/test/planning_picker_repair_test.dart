import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/widgets/place_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

void main() {
  testWidgets(
    'planning retains the original center picker and confirms a manual point',
    (tester) async {
      PlaceMapRequest? request;
      PlaceIntent? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeMapBuilderProvider.overrideWithValue((value) {
              request = value;
              return const SizedBox.expand();
            }),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => result = await choosePlace(
                    context,
                    title: 'Location for pick up laundry',
                    initial: '',
                    forPlanning: true,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(request, isNotNull);
      expect(request!.centerPicker, isTrue);
      expect(find.text('Move the map to set your pin'), findsOneWidget);
      request!.onSelect!(14.58, 121.06);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(result!.latitude, 14.58);
      expect(result!.longitude, 121.06);
      expect(result!.provider, isNull);
    },
  );

  testWidgets('an SDK recommendation is never projected onto the manual map', (
    tester,
  ) async {
    PlaceMapRequest? request;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeMapBuilderProvider.overrideWithValue((value) {
            request = value;
            return const SizedBox.expand();
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: const PlacePicker(
            title: 'Choose place',
            initial: 'My errand',
            forPlanning: true,
            initialPlace: PlaceIntent(
              kind: PlaceKind.providerReference,
              label: 'My errand',
              provider: 'google_places_sdk',
              providerPlaceId: 'kept-id',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(request, isNotNull);
    expect(request!.focus, isNull);
    expect(request!.pins, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Use name only'), findsNothing);
  });
}
