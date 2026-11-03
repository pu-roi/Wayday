import 'package:flutter/material.dart';
import '../data/trip_navigation.dart';
import 'trip_session.dart';

Future<TripMapProvider?> showTripProviders(
  BuildContext context,
  TripSession model, {
  required bool alternativeEnabled,
}) {
  final issue = model.alternativeIssue;
  return showModalBottomSheet<TripMapProvider>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Map & navigation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Google'),
            subtitle: const Text('Google Maps and navigation'),
            trailing: model.provider == TripMapProvider.google
                ? const Icon(Icons.check)
                : null,
            onTap: model.busy
                ? null
                : () => Navigator.pop(context, TripMapProvider.google),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('OpenStreetMap'),
            subtitle: const Text('OpenFreeMap maps · Geoapify routing'),
            trailing: model.provider == TripMapProvider.openStreetMap
                ? const Icon(Icons.check)
                : null,
            enabled: alternativeEnabled && issue == null && !model.busy,
            onTap: alternativeEnabled && issue == null && !model.busy
                ? () => Navigator.pop(context, TripMapProvider.openStreetMap)
                : null,
          ),
          if (issue != null) Text(issue),
          if (!alternativeEnabled)
            const Text(
              'OpenStreetMap navigation is not available in this build.',
            ),
          const SizedBox(height: 12),
          const Text(
            'This choice applies to this trip only. New trips start with Google. Alternative guidance needs internet and provides approximate traffic; lane and speed-limit coverage are unavailable.',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    ),
  );
}
