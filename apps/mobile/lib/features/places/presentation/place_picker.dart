import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../maps/data/location_reader.dart';
import '../../maps/presentation/place_map.dart';
import '../data/place_search_repository.dart';
import '../domain/place_intent.dart';
import 'saved_places_controller.dart';

Future<PlaceIntent?> choosePlace(
  BuildContext context, {
  required String title,
  required String initial,
  PlaceIntent? initialIntent,
}) => Navigator.of(context, rootNavigator: true).push<PlaceIntent>(
  MaterialPageRoute(
    builder: (_) => PlacePicker(
      title: title,
      initial: initial,
      initialIntent: initialIntent,
    ),
  ),
);

class PlacePicker extends ConsumerStatefulWidget {
  const PlacePicker({
    required this.title,
    required this.initial,
    this.initialIntent,
    super.key,
  });
  final String title, initial;
  final PlaceIntent? initialIntent;
  @override
  ConsumerState<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends ConsumerState<PlacePicker> {
  late final _query = TextEditingController(text: widget.initial);
  Timer? _debounce;
  int _request = 0;
  bool _loading = false, _unavailable = false;
  List<PlaceResult> _results = [];
  @override
  void initState() {
    super.initState();
    if (widget.initial.trim().length >= 2) {
      _debounce = Timer(Duration.zero, _search);
    }
  }

  void _changed(String _) {
    _request++;
    _debounce?.cancel();
    setState(() {
      _results = [];
      _unavailable = false;
      _loading = _query.text.trim().length >= 2;
    });
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _unavailable = false;
    });
    try {
      final results = await ref
          .read(placeSearchRepositoryProvider)
          .search(query);
      if (mounted && request == _request) setState(() => _results = results);
    } catch (_) {
      if (mounted && request == _request) setState(() => _unavailable = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _map({
    PlaceIntent? initial,
    PlaceResult? result,
    bool locate = false,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chosen = await Navigator.of(context).push<PlaceIntent>(
      MaterialPageRoute(
        builder: (_) => PinPicker(
          title: widget.title,
          initial: initial ?? result?.intent ?? widget.initialIntent,
          result: result,
          locateOnOpen: locate,
        ),
      ),
    );
    if (chosen != null && mounted) Navigator.pop(context, chosen);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _request++;
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref
        .watch(savedPlacesProvider)
        .where(
          (p) =>
              _query.text.trim().isEmpty ||
              p.place.label.toLowerCase().contains(
                _query.text.trim().toLowerCase(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: TextField(
                  key: const Key('place-search'),
                  controller: _query,
                  maxLength: 100,
                  onChanged: _changed,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _search();
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search places or landmarks',
                    counterText: '',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _query.clear();
                              _changed('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (saved.isNotEmpty) ...[
                      Text('Saved places', style: context.type.titleSmall),
                      for (final p in saved)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bookmark_outline),
                          title: Text(p.place.label),
                          subtitle: Text(
                            p.place.hasCoordinates
                                ? p.place.address ??
                                      'Saved pin · ${p.place.latitude!.toStringAsFixed(5)}, ${p.place.longitude!.toStringAsFixed(5)}'
                                : 'Map pin still needed',
                          ),
                          onTap: () => p.place.hasCoordinates
                              ? Navigator.pop(context, p.intent)
                              : _map(initial: p.intent),
                          trailing: IconButton(
                            tooltip: 'Remove saved place ${p.place.label}',
                            onPressed: () => ref
                                .read(savedPlacesProvider.notifier)
                                .remove(p.id),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      const Divider(height: 32),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Searching places…'),
                          ],
                        ),
                      )
                    else if (_unavailable) ...[
                      Text(
                        'Place search is unavailable.',
                        style: context.type.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You can still choose on map or use a saved place.',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _search,
                          child: const Text('Retry search'),
                        ),
                      ),
                    ] else if (_query.text.trim().length >= 2 &&
                        _results.isEmpty) ...[
                      Text(
                        'No matching places in this pilot area.',
                        style: context.type.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try the full name, a nearby landmark, or choose on map.',
                      ),
                    ] else if (_query.text.trim().length < 2)
                      const Text(
                        'Search by business, school, landmark or address.',
                      ),
                    for (final p in _results) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(p.name),
                        subtitle: Text(
                          p.address ??
                              '${p.category.replaceAll('_', ' ')} · Address not recorded',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _map(result: p),
                      ),
                      const Divider(height: 1),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Pasig/Ortigas pilot · coverage is incomplete',
                      style: context.type.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '© OpenStreetMap contributors · Hours and entrances are unverified.',
                      style: context.type.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.wayday.link,
                          ),
                          onPressed: () => _map(),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Choose on map'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Use my location',
                        onPressed: () => _map(locate: true),
                        icon: const Icon(Icons.my_location_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinPicker extends ConsumerStatefulWidget {
  const PinPicker({
    required this.title,
    this.initial,
    this.result,
    this.locateOnOpen = false,
    super.key,
  });
  final String title;
  final PlaceIntent? initial;
  final PlaceResult? result;
  final bool locateOnOpen;
  @override
  ConsumerState<PinPicker> createState() => _PinPickerState();
}

class _PinPickerState extends ConsumerState<PinPicker> {
  PlaceIntent? _point, _focus, _anchor;
  int _focusRevision = 0, _locationAttempt = 0, _nearbyAttempt = 0;
  bool _locating = false, _resolving = false;
  String? _locationInfo;
  List<PlaceResult> _nearby = [];
  Timer? _nearbyTimer;
  @override
  void initState() {
    super.initState();
    _focus = widget.initial;
    _anchor = widget.initial;
    _point = widget.initial?.hasCoordinates == true ? widget.initial : null;
    if (widget.locateOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _locate();
      });
    }
  }

  double _distance(PlaceIntent a, PlaceIntent b) {
    final dx =
        (a.longitude! - b.longitude!) * math.cos(a.latitude! * math.pi / 180);
    final dy = a.latitude! - b.latitude!;
    return math.sqrt(dx * dx + dy * dy) * 111320;
  }

  void _select(double lat, double lon) {
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
      return;
    }
    final dropped = PlaceIntent(
      kind: PlaceKind.specific,
      label: 'Dropped pin',
      latitude: lat,
      longitude: lon,
      source: 'user_pin',
    );
    final anchor = _anchor;
    final point =
        anchor?.hasCoordinates == true && _distance(anchor!, dropped) < 1
        ? anchor
        : dropped;
    if (_point?.latitude == lat && _point?.longitude == lon) return;
    setState(() {
      _point = point;
      _nearby = [];
      _resolving = point != anchor;
    });
    _nearbyTimer?.cancel();
    final attempt = ++_nearbyAttempt;
    if (point == anchor) return;
    _nearbyTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final nearby = await ref
            .read(placeSearchRepositoryProvider)
            .nearby(lat, lon);
        if (mounted && attempt == _nearbyAttempt) {
          final areas = nearby
              .where((place) => place.matchKind == 'area')
              .toList();
          final matches = areas.isNotEmpty
              ? areas
              : nearby.where((place) => place.matchKind == 'point').toList();
          setState(() {
            if (matches.length == 1) {
              final match = matches.single;
              _point = PlaceIntent(
                kind: PlaceKind.specific,
                label: match.name,
                latitude: lat,
                longitude: lon,
                source: match.id,
                address: match.address,
                sourceDate: match.sourceDate,
                coordinateKind: match.matchKind == 'area'
                    ? 'selected_in_mapped_area'
                    : 'near_mapped_point',
              );
              _anchor = _point;
            } else {
              _nearby = nearby;
            }
          });
        }
      } catch (_) {
        /* A dropped pin remains usable without landmark lookup. */
      } finally {
        if (mounted && attempt == _nearbyAttempt) {
          setState(() => _resolving = false);
        }
      }
    });
  }

  void _chooseNearby(PlaceResult place) {
    _nearbyTimer?.cancel();
    _nearbyAttempt++;
    setState(() {
      _point = _anchor = _focus = place.intent;
      _focusRevision++;
      _nearby = [];
      _resolving = false;
    });
  }

  void _cancelLocation() {
    _locationAttempt++;
    if (_locating) {
      setState(() {
        _locating = false;
        _locationInfo = 'Location lookup cancelled. You can move the map.';
      });
    }
  }

  Future<void> _locate() async {
    final attempt = ++_locationAttempt;
    setState(() {
      _locating = true;
      _locationInfo = null;
    });
    try {
      final fix = await ref
          .read(locationReaderProvider)()
          .timeout(const Duration(seconds: 12));
      if (!mounted || attempt != _locationAttempt) return;
      final point = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Dropped pin',
        latitude: fix.latitude,
        longitude: fix.longitude,
        source: 'user_pin',
      );
      if (!point.hasCoordinates) {
        throw const LocationUnavailable(
          'Location returned an invalid position. Move the map instead.',
        );
      }
      setState(() {
        _focus = point;
        _focusRevision++;
        _locationInfo =
            'Accuracy about ${fix.accuracy.round()} m. Check the pin before confirming.';
      });
    } on LocationUnavailable catch (e) {
      if (mounted && attempt == _locationAttempt) {
        setState(() => _locationInfo = e.message);
      }
    } catch (_) {
      if (mounted && attempt == _locationAttempt) {
        setState(
          () => _locationInfo =
              'No location fix yet. Try again or move the map to set your pin.',
        );
      }
    } finally {
      if (mounted && attempt == _locationAttempt) {
        setState(() => _locating = false);
      }
    }
  }

  @override
  void dispose() {
    _locationAttempt++;
    _nearbyAttempt++;
    _nearbyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final named = point != null && point.source != 'user_pin';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: (_) {
                      if (_locating) _cancelLocation();
                      _nearbyAttempt++;
                      _nearbyTimer?.cancel();
                      if (_resolving) setState(() => _resolving = false);
                    },
                    child: ref.watch(placeMapBuilderProvider)(
                      PlaceMapRequest(
                        centerPicker: true,
                        focus: _focus,
                        focusRevision: _focusRevision,
                        onSelect: _select,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 40,
                  child: Material(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: _locating
                        ? TextButton.icon(
                            onPressed: _cancelLocation,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Cancel location'),
                          )
                        : IconButton(
                            tooltip: 'Use my location',
                            onPressed: _locate,
                            icon: const Icon(Icons.my_location_rounded),
                          ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .26,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point?.label ?? 'Move the map to set your pin',
                    style: context.type.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    named
                        ? point.address ??
                              'Mapped location · entrance unverified'
                        : _resolving
                        ? 'Finding the place at your pin…'
                        : _nearby.isNotEmpty
                        ? 'Choose a nearby place, or keep this pin.'
                        : 'Move the map beneath the pin, then confirm.',
                  ),
                  for (final place in _nearby)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _chooseNearby(place),
                        icon: const Icon(Icons.place_outlined, size: 20),
                        label: Text(place.name),
                      ),
                    ),
                  if (_locating)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Finding your location… You can still move the map.',
                      ),
                    ),
                  if (_locationInfo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _locationInfo!,
                        key: const Key('location-message'),
                      ),
                    ),
                  if (point != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${point.latitude!.toStringAsFixed(6)}, ${point.longitude!.toStringAsFixed(6)}',
                        key: const Key('pin-coordinates'),
                        style: context.type.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: point == null
                          ? null
                          : () => Navigator.pop(context, point),
                      child: const Text('Confirm location'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Save to my places',
                    onPressed: point == null
                        ? null
                        : () {
                            ref.read(savedPlacesProvider.notifier).save(point);
                            showFeedback(
                              context,
                              'Place saved on this device.',
                            );
                          },
                    icon: const Icon(Icons.bookmark_add_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
