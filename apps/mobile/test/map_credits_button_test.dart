import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';

void main() {
  testWidgets('the map information button opens Wayday credits', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: MapCreditsButton()),
        ),
      ),
    );
    expect(find.byTooltip('Map credits and licenses'), findsOneWidget);
    await tester.tap(find.byTooltip('Map credits and licenses'));
    await tester.pumpAndSettle();
    expect(find.text('Online map and place search'), findsOneWidget);
    expect(find.textContaining('OpenMapTiles'), findsOneWidget);
    expect(find.textContaining('openstreetmap.org/copyright'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Map credits and licenses'), findsOneWidget);
  });
}
