import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/data/local_repositories.dart';
import '../../../core/widgets/feedback.dart';
import '../../places/data/combined_place_search.dart';
import '../../places/data/google_search.dart';
import '../../places/data/google_pin_cache.dart';
import '../../places/domain/place_search.dart';
import '../../places/presentation/search_attribution.dart';
import '../../places/domain/place_intent.dart';
import '../../places/presentation/place_search_controller.dart';
import '../../places/presentation/place_search_panel.dart';
import '../data/location_reader.dart';
import 'place_map.dart';

class OnlinePinPicker extends ConsumerStatefulWidget {
  const OnlinePinPicker({
    required this.initial,
    this.title = 'Choose a location',
    this.allowSave = true,
    super.key,
  });
  final PlaceIntent? initial;
  final String title;
  final bool allowSave;
  @override
  ConsumerState<OnlinePinPicker> createState() => _OnlinePinPickerState();
}

class _OnlinePinPickerState extends ConsumerState<OnlinePinPicker>
    with WidgetsBindingObserver {
  late final _query = TextEditingController(text: widget.initial?.label ?? '');
  final _searchFocus = FocusNode();
  late final PlaceSearchController _search;
  late final SearchLocationController _location;
  late final GooglePinCache _googlePins;
  PlaceIntent? _point, _focus;
  List<SavedPlace> _saved = [];
  int _focusRevision = 0, _locationAttempt = 0;
  bool _searchOpen = false,
      _locating = false,
      _saving = false,
      _moving = false,
      _savedError = false;
  String? _locationInfo;
  double? _zoom;
  SearchCategory? _areaCategory;
  bool _focusIsCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus = widget.initial;
    if (widget.initial?.hasCoordinates == true ||
        widget.initial?.isGoogle == true) {
      _point = widget.initial;
    }
    _googlePins = ref.read(googlePinCacheProvider)..addListener(_refresh);
    _search =
        PlaceSearchController(
            ref.read(combinedPlaceSearchProvider),
            google: ref.read(googleSearchProvider),
            sourceChoice: ref.read(searchSourceChoiceProvider),
            pins: _googlePins,
          )
          ..onGoogleSelection = _choose
          ..addListener(_refresh);
    _location = ref.read(searchLocationProvider)..addListener(_locationChanged);
    _searchFocus.addListener(_onFocus);
    _loadSaved();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (_searchFocus.hasFocus) {
      _openSearch();
      _search.change(_query.text);
    }
  }

  void _openSearch() {
    if (_searchOpen) return;
    setState(() => _searchOpen = true);
    _location.refresh();
    _locationChanged();
  }

  void _locationChanged() {
    if (!mounted) return;
    if (_searchOpen) {
      final fix = _location.usableFix;
      _search.updateDeviceLocation(
        fix == null
            ? null
            : SearchOrigin.device(
                fix.latitude,
                fix.longitude,
                approximate: fix.approximate,
                accuracy: fix.accuracy,
              ),
      );
    }
    setState(() {});
  }

  Future<void> _useSearchLocation() async {
    _search.useNearMe();
    await _location.refresh(requestPermission: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _search.suspend();
      _cancelLocation();
    }
  }

  void _backToMap() {
    _areaCategory = _search.category;
    _closeSearch();
  }

  void _searchArea() {
    final category = _areaCategory;
    _openSearch();
    _search.searchThisArea();
    _search.change(_query.text);
    if (category != null) {
      _search.chooseCategory(category);
    } else {
      _search.submit();
    }
  }

  void _hideKeyboard() {
    _searchFocus.unfocus();
    // Android normally consumes Back in the IME. Also handle Back dispatched
    // to Flutter (including when the keyboard is already hidden) without
    // dismissing the search session or changing its query/results.
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Future<void> _loadSaved() async {
    final repository = ref.read(savedPlaceRepositoryProvider);
    if (repository == null) return;
    try {
      final places = await repository.read();
      if (mounted) {
        setState(() {
          _saved = places;
          _savedError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _savedError = true);
    }
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _search.dismiss();
    setState(() => _searchOpen = false);
  }

  void _choose(PlaceIntent place) {
    _cancelLocation();
    _areaCategory = null;
    setState(() {
      _point = place;
      _focus = place.hasCoordinates ? place : null;
      _focusIsCurrentLocation = false;
      _focusRevision++;
      _query.text = place.label;
      _moving = false;
      _locationInfo = null;
    });
    _closeSearch();
  }

  void _moveStarted() {
    _cancelLocation();
    if (mounted) setState(() => _moving = true);
  }

  void _select(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return;
    }
    _cancelLocation();
    final selected = _point;
    final samePoint =
        selected?.hasCoordinates == true &&
        (selected!.latitude! - latitude).abs() < .000001 &&
        (selected.longitude! - longitude).abs() < .000001;
    setState(() {
      _moving = false;
      if (!samePoint) {
        _locationInfo = null;
        // Retain an explicitly entered personal name, never a moved business identity.
        final named = selected ?? widget.initial;
        final alias = named?.source == 'user' || named?.source == 'manual'
            ? named?.label
            : null;
        _point = PlaceIntent(
          kind: PlaceKind.specific,
          label: alias?.isNotEmpty == true ? alias! : 'Dropped pin',
          latitude: latitude,
          longitude: longitude,
          source: 'manual',
        );
      }
      _focus = _point;
      _focusIsCurrentLocation = false;
    });
  }

  void _cancelLocation() {
    _locationAttempt++;
    if (_locating) setState(() => _locating = false);
  }

  Future<void> _locate() async {
    _closeSearch();
    final attempt = ++_locationAttempt;
    setState(() {
      _locating = true;
      _locationInfo = null;
    });
    try {
      final fix = await _location.refresh(requestPermission: true);
      if (!mounted || attempt != _locationAttempt) return;
      if (fix == null) {
        setState(
          () => _locationInfo =
              _location.message ??
              'No location fix yet. Try again or move the map.',
        );
        return;
      }
      if (!fix.latitude.isFinite ||
          !fix.longitude.isFinite ||
          fix.latitude.abs() > 90 ||
          fix.longitude.abs() > 180) {
        throw const LocationUnavailable(
          'Location returned an invalid position. Move the map instead.',
        );
      }
      setState(() {
        _point = PlaceIntent(
          kind: PlaceKind.specific,
          label: 'Current location',
          latitude: fix.latitude,
          longitude: fix.longitude,
          source: 'device',
        );
        _focus = _point;
        _focusIsCurrentLocation = true;
        _focusRevision++;
        _moving = false;
        _locationInfo =
            'Accuracy about ${fix.accuracy.round()} m. Check the pin before confirming.';
      });
    } on LocationUnavailable catch (error) {
      if (mounted && attempt == _locationAttempt) {
        setState(() => _locationInfo = error.message);
      }
    } catch (_) {
      if (mounted && attempt == _locationAttempt) {
        setState(
          () =>
              _locationInfo = 'No location fix yet. Try again or move the map.',
        );
      }
    } finally {
      if (mounted && attempt == _locationAttempt) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _save() async {
    final place = _point;
    final repository = ref.read(savedPlaceRepositoryProvider);
    if (place == null ||
        !place.hasCoordinates ||
        repository == null ||
        _saving ||
        _moving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await repository.add(
        SavedPlace(
          id: 'place-${DateTime.now().microsecondsSinceEpoch}',
          place: place,
        ),
      );
      if (!mounted) return;
      await _loadSaved();
      if (mounted) showFeedback(context, 'Place saved on this device.');
    } catch (_) {
      if (mounted) {
        showFeedback(
          context,
          'Place could not be saved. Try again.',
          advisory: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationAttempt++;
    _search.dispose();
    _googlePins.removeListener(_refresh);
    _location.removeListener(_locationChanged);
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final canConfirm =
        point != null &&
        point.label.trim().isNotEmpty &&
        (!point.isGoogle || point.hasCoordinates) &&
        !_moving &&
        !_locating;
    return PopScope<PlaceIntent>(
      canPop: !_searchOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _searchOpen) _hideKeyboard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: _searchOpen
              ? IconButton(
                  tooltip: 'Close search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _backToMap,
                )
              : BackButton(onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TextFormField(
                  key: const Key('place-name'),
                  controller: _query,
                  focusNode: _searchFocus,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    _openSearch();
                    _search.change(value);
                  },
                  onFieldSubmitted: (_) {
                    _search.change(_query.text);
                    _search.submit();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search places, landmarks, or addresses',
                    counterText: '',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchOpen
                        ? IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _query.clear();
                              _search.change('');
                              _searchFocus.requestFocus();
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ref.watch(placeMapBuilderProvider)(
                        PlaceMapRequest(
                          centerPicker: true,
                          philippinesOverview: true,
                          iconOnlyAttribution: true,
                          focus: _focus,
                          focusRevision: _focusRevision,
                          focusZoom: _focusIsCurrentLocation ? 18 : 16,
                          animateFocus: _focusIsCurrentLocation,
                          onSelect: _select,
                          onViewportChanged: (latitude, longitude, zoom) {
                            _search.updateArea(
                              SearchArea(latitude, longitude, zoom),
                            );
                          },
                          onMoveStarted: _moveStarted,
                          onZoomChanged: (zoom) {
                            if (zoom.isFinite && mounted && zoom != _zoom) {
                              setState(() => _zoom = zoom);
                            }
                          },
                          onMoveCancelled: () =>
                              setState(() => _moving = false),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 56,
                      child: Material(
                        key: const Key('map-location-control'),
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: _locating
                            ? TextButton.icon(
                                onPressed: _cancelLocation,
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Cancel location'),
                              )
                            : SizedBox(
                                width: 48,
                                height: 48,
                                child: IconButton(
                                  tooltip: 'Use my location',
                                  onPressed: _locate,
                                  icon: const Icon(Icons.my_location_rounded),
                                ),
                              ),
                      ),
                    ),
                    if (_zoom != null)
                      Positioned(
                        right: 16,
                        bottom: 112,
                        child: Semantics(
                          label: 'Map zoom level ${_zoom!.toStringAsFixed(1)}',
                          excludeSemantics: true,
                          child: Material(
                            key: const Key('map-zoom-label'),
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      'Z: ${_zoom!.toStringAsFixed(1)}',
                                      style: context.type.bodySmall,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_searchOpen &&
                        (_areaCategory != null ||
                            _query.text.trim().length >= 2))
                      Positioned(
                        top: 12,
                        left: 20,
                        right: 20,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: FilledButton.tonal(
                            onPressed: _searchArea,
                            child: const Text('Search this area'),
                          ),
                        ),
                      ),
                    if (_searchOpen)
                      Positioned.fill(
                        child: PlaceSearchPanel(
                          search: _search,
                          saved: _saved,
                          savedError: _savedError,
                          locating: _location.phase == LocationPhase.loading,
                          locationMessage: _location.message,
                          onUseLocation: _useSearchLocation,
                          onOpenSettings: _location.canOpenSettings
                              ? _location.openSettings
                              : null,
                          onRetrySaved: _loadSaved,
                          onSelect: _choose,
                          onClose: _backToMap,
                          onNameOnly: () =>
                              _choose(PlaceIntent(label: _query.text.trim())),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_searchOpen) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .22,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (point?.isGoogle == true)
                            TextFormField(
                              key: ValueKey(
                                'google-label-${point!.providerPlaceId}',
                              ),
                              initialValue: point.label,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'Your label',
                                counterText: '',
                              ),
                              onChanged: (text) => setState(
                                () => _point = point.withLabel(text.trim()),
                              ),
                            )
                          else
                            Text(
                              point?.label ?? 'Move the map to set your pin',
                              style: context.type.titleMedium,
                            ),
                          if (point?.address != null) Text(point!.address!),
                          if (point != null)
                            SearchAttribution(
                              credits: [
                                ...point.attributions,
                                if (point.source.startsWith('osm/'))
                                  '© OpenStreetMap contributors',
                              ],
                            ),
                          if (point?.isGoogle == true &&
                              !point!.hasCoordinates) ...[
                            const Text(
                              'Internet is required to refresh this Google pin. Your label is still saved.',
                            ),
                            TextButton(
                              onPressed: () {
                                _openSearch();
                                _search.refreshGoogleReference(point);
                              },
                              child: const Text('Refresh Google pin'),
                            ),
                          ] else if (point != null && !point.hasCoordinates)
                            const Text('Name only · No map pin'),
                          if (_locating) const Text('Finding your location…'),
                          if (_locationInfo != null)
                            Text(
                              _locationInfo!,
                              key: const Key('location-message'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: canConfirm
                              ? () => Navigator.pop(context, point)
                              : null,
                          child: const Text('Confirm location'),
                        ),
                      ),
                      if (widget.allowSave &&
                          ref.watch(savedPlaceRepositoryProvider) != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Save to my places',
                          onPressed:
                              canConfirm && point.hasCoordinates && !_saving
                              ? _save
                              : null,
                          icon: const Icon(Icons.bookmark_add_outlined),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
