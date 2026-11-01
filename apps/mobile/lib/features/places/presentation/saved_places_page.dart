import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/data/local_repositories.dart';
import '../../../core/widgets/section_surface.dart';
import '../../maps/presentation/online_pin_picker.dart';
import '../data/saved_place_repository.dart';
import '../domain/place_intent.dart';
import 'search_attribution.dart';

class SavedPlacesPage extends ConsumerStatefulWidget {
  const SavedPlacesPage({super.key});
  @override
  ConsumerState<SavedPlacesPage> createState() => _SavedPlacesPageState();
}

class _SavedPlacesPageState extends ConsumerState<SavedPlacesPage> {
  List<SavedPlace>? _places;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(savedPlaceRepositoryProvider);
    if (repository == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final places = await repository.read();
      if (mounted) setState(() => _places = places);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(SavedPlace place, SavedPlaceRepository repository) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SavedPlaceEditor(place: place, repository: repository),
      ),
    );
    if (mounted && changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(savedPlaceRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved places')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (repository == null)
                      const Text(
                        'Saved places are unavailable on this device or in this preview.',
                      )
                    else if (_failed) ...[
                      const Text('Saved places could not be loaded.'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ),
                    ] else if (_places == null || _places!.isEmpty)
                      const Text(
                        'No saved places yet. Save a location from the map.',
                      )
                    else
                      SectionSurface(
                        child: Column(
                          children: [
                            for (final place in _places!)
                              ListTile(
                                leading: const Icon(Icons.bookmark_outline),
                                title: Text(place.place.label),
                                subtitle: Text(
                                  place.place.isGoogle &&
                                          !place.place.hasCoordinates
                                      ? 'Internet is required to refresh this Google pin'
                                      : place.place.address ?? 'Saved pin',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => _edit(place, repository),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class SavedPlaceEditor extends StatefulWidget {
  const SavedPlaceEditor({
    required this.place,
    required this.repository,
    super.key,
  });
  final SavedPlace place;
  final SavedPlaceRepository repository;
  @override
  State<SavedPlaceEditor> createState() => _SavedPlaceEditorState();
}

class _SavedPlaceEditorState extends State<SavedPlaceEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.place.place.label,
  );
  late PlaceIntent _location = widget.place.place;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<PlaceIntent>(
      MaterialPageRoute(
        builder: (_) => OnlinePinPicker(
          initial: _location,
          title: 'Edit location',
          allowSave: false,
        ),
      ),
    );
    if (mounted && result != null) setState(() => _location = result);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final location = _location;
    final place = location.withLabel(_name.text.trim());
    try {
      await widget.repository.update(
        SavedPlace(id: widget.place.id, place: place),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save changes. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved place?'),
        content: const Text(
          'Existing errands and endpoints will keep their current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.delete(widget.place.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not delete this place. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit saved place')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Place name'),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a place name.'
                    : null,
              ),
              const SizedBox(height: 24),
              SearchAttribution(
                credits: [
                  ..._location.attributions,
                  if (_location.source.startsWith('osm/'))
                    '© OpenStreetMap contributors',
                ],
              ),
              Text('Location', style: context.type.titleMedium),
              const SizedBox(height: 8),
              Text(
                _location.isGoogle && !_location.hasCoordinates
                    ? 'Internet is required to refresh this Google pin. Your label is saved.'
                    : _location.address ??
                          (_location.hasCoordinates
                              ? 'Saved pin'
                              : 'Location unavailable'),
              ),
              if (_location.hasCoordinates)
                Text(
                  '${_location.latitude!.toStringAsFixed(6)}, ${_location.longitude!.toStringAsFixed(6)}',
                  style: context.type.bodySmall,
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _chooseLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Change location'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: context.colors.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save changes'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _saving ? null : _delete,
                child: const Text('Delete saved place'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
