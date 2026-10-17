import 'package:flutter/material.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';

/// Synthetic coordinates exercise selection without calling a tile service.
Widget testMap(PlaceMapRequest request) => ColoredBox(
  color: const Color(0xFFE5F0F9),
  child: Center(
    child: request.onSelect == null
        ? Text(
            'Test map · ${request.pins.where((p) => p.place.hasCoordinates).length} pins',
          )
        : TextButton(
            key: const Key('test-map-pin'),
            onPressed: () => request.onSelect!(14.58, 121.08),
            child: const Text('Select test pin'),
          ),
  ),
);
