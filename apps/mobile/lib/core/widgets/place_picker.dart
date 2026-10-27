import 'package:flutter/material.dart';
import '../../features/maps/presentation/online_pin_picker.dart';
import '../../features/places/domain/place_intent.dart';

Future<PlaceIntent?> choosePlace(
  BuildContext context, {
  required String title,
  required String initial,
  PlaceIntent? initialPlace,
}) => Navigator.of(context, rootNavigator: true).push<PlaceIntent>(
  MaterialPageRoute(
    builder: (_) =>
        PlacePicker(title: title, initial: initial, initialPlace: initialPlace),
  ),
);

/// Shared entry point for endpoints and errands. Every choice stays on one page.
class PlacePicker extends StatelessWidget {
  const PlacePicker({
    required this.title,
    required this.initial,
    this.initialPlace,
    super.key,
  });
  final String title;
  final String initial;
  final PlaceIntent? initialPlace;

  @override
  Widget build(BuildContext context) => OnlinePinPicker(
    title: title,
    initial: initialPlace ?? PlaceIntent(label: initial),
  );
}
