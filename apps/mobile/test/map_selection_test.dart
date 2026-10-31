import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/maps/presentation/map_selection.dart';

void main() {
  test(
    'confirmation waits for the settled point, not an earlier position',
    () async {
      final selection = MapSelectionController();
      selection.begin();
      final confirming = selection.capture();
      selection.settle(14.61, 121.04);
      expect(await confirming, (14.61, 121.04));
    },
  );
  test('a newer gesture invalidates pending confirmation', () async {
    final selection = MapSelectionController();
    selection.begin();
    final pending = expectLater(selection.capture(), throwsStateError);
    selection.begin();
    selection.settle(14.62, 121.05);
    await pending;
  });
  test('unsettled confirmation has a bounded wait', () async {
    final selection = MapSelectionController(
      timeout: const Duration(milliseconds: 5),
    );
    selection.begin();
    await expectLater(selection.capture(), throwsA(isA<Exception>()));
  });
}
