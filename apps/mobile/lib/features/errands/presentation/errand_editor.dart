import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/selection_controls.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../domain/errand.dart';
import '../../places/domain/place_intent.dart';
import '../../places/domain/place_search.dart';
import '../../places/data/combined_place_search.dart';

sealed class ErrandEditResult {
  const ErrandEditResult();
}

class SavedErrand extends ErrandEditResult {
  const SavedErrand(this.errand);
  final Errand errand;
}

class RemovedErrand extends ErrandEditResult {
  const RemovedErrand();
}

Future<ErrandEditResult?> editErrand(BuildContext context, Errand errand) =>
    Navigator.of(context, rootNavigator: true).push<ErrandEditResult>(
      MaterialPageRoute(builder: (_) => ErrandEditor(errand: errand)),
    );

class ErrandEditor extends ConsumerStatefulWidget {
  const ErrandEditor({required this.errand, super.key});
  final Errand errand;
  @override
  ConsumerState<ErrandEditor> createState() => _ErrandEditorState();
}

class _ErrandEditorState extends ConsumerState<ErrandEditor>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.errand.title);
  late final _notes = TextEditingController(text: widget.errand.notes);
  late final _duration = TextEditingController(
    text: '${widget.errand.durationMinutes}',
  );
  late bool _durationConfirmed = widget.errand.durationConfirmed;
  late final _confirmed = {...widget.errand.confirmedFields};
  late String _place = widget.errand.place;
  late PlaceIntent _placeIntent = widget.errand.placeIntent;
  late TimingRule _timing = widget.errand.timing;
  late int? _minute = widget.errand.minute;
  late bool _optional = widget.errand.optional;
  String? _timeError;
  final _lookupOwner = Object();
  late final CombinedPlaceSearch _placeSearch;
  Timer? _lookupTimer;
  int _lookupRevision = 0;
  bool _finding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placeSearch = ref.read(combinedPlaceSearchProvider);
  }

  void _cancelLookup() {
    _lookupRevision++;
    _lookupTimer?.cancel();
    _lookupTimer = null;
    _placeSearch.cancel(_lookupOwner, only: {'geoapify'});
    _finding = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      setState(_cancelLookup);
    }
  }

  void _resolvePin(PlaceIntent place) {
    if (place.source != 'manual' ||
        place.label != 'Dropped pin' ||
        !place.hasCoordinates ||
        place.isGoogle) {
      return;
    }
    final revision = _lookupRevision;
    setState(() => _finding = true);
    _lookupTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && revision == _lookupRevision) setState(_cancelLookup);
    });
    _placeSearch.reverse(_lookupOwner, place.latitude!, place.longitude!, (
      _,
      status,
      results,
    ) {
      if (!mounted ||
          revision != _lookupRevision ||
          !identical(_placeIntent, place)) {
        return;
      }
      if (status.phase == SourcePhase.waiting ||
          status.phase == SourcePhase.loading) {
        return;
      }
      _lookupTimer?.cancel();
      setState(() {
        _finding = false;
        if (status.phase == SourcePhase.complete && results.isNotEmpty) {
          final result = results.first;
          _placeIntent = PlaceIntent(
            kind: PlaceKind.specific,
            label: result.name,
            latitude: place.latitude,
            longitude: place.longitude,
            source: 'manual',
            provider: result.provider,
            retrievedAt: result.retrievedAt?.toIso8601String(),
            attributions: result.attributions,
          );
          _place = result.name;
        }
      });
    });
  }

  Future<void> _namePlace() async {
    setState(_cancelLookup);
    final original = _placeIntent;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NamePlaceDialog(),
    );
    if (!mounted ||
        name == null ||
        name.isEmpty ||
        !identical(original, _placeIntent)) {
      return;
    }
    setState(() {
      _place = name;
      _placeIntent = original.withLabel(
        name,
        labelSource: original.isGoogle ? 'google_ui_kit/user_label' : null,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelLookup();
    _title.dispose();
    _notes.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    final valid = _form.currentState?.validate() ?? false;
    if (_timing != TimingRule.anytime && _minute == null) {
      setState(() => _timeError = 'Choose a time for this errand.');
      return;
    }
    if (!valid) return;
    Navigator.pop(
      context,
      SavedErrand(
        widget.errand.copyWith(
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          place: _place,
          placeIntent: _placeIntent,
          durationMinutes: int.parse(_duration.text),
          durationConfirmed: _durationConfirmed,
          confirmedFields: _confirmed,
          timing: _timing,
          minute: _minute,
          clearTime: _timing == TimingRule.anytime,
          optional: _optional,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit errand'),
      actions: [
        TextButton(
          onPressed: _finding ? null : _save,
          child: const Text('Save'),
        ),
        const SizedBox(width: 12),
      ],
    ),
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
                key: const Key('errand-title'),
                controller: _title,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: context.type.titleLarge,
                decoration: const InputDecoration(
                  labelText: 'What do you need to do?',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Give this errand a name.'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('errand-notes'),
                controller: _notes,
                minLines: 4,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                  hintText:
                      'Vegetables, fruits, meat…\nOr anything to remember at this stop.',
                ),
              ),
              const SizedBox(height: 28),
              Text('Where', style: context.type.titleMedium),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.location_on_outlined,
                  color: context.wayday.link,
                ),
                title: Text(_place.isEmpty ? 'Choose a place' : _place),
                subtitle: Text(_finding ? 'Finding address…' : 'Open map'),
                trailing: Icon(Icons.map_outlined, color: context.wayday.link),
                onTap: () async {
                  setState(() {
                    _cancelLookup();
                  });
                  final place = await choosePlace(
                    context,
                    title: 'Errand location',
                    initial: _place,
                    initialPlace: _placeIntent,
                    otherSourcesOnly: true,
                  );
                  if (!mounted) return;
                  if (place != null) {
                    setState(() {
                      _place = place.label;
                      _placeIntent = place;
                      _confirmed.add('place');
                    });
                    _resolvePin(place);
                  }
                },
              ),
              if (_placeIntent.isGoogle ||
                  (_placeIntent.source == 'manual' &&
                      _placeIntent.hasCoordinates))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _namePlace,
                    child: const Text('Name this location'),
                  ),
                ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('errand-duration'),
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Visit duration',
                  suffixText: 'minutes',
                  helperText: _durationConfirmed
                      ? 'Your estimate for this visit.'
                      : '15 minutes assumed · adjust for this visit.',
                ),
                onChanged: (_) => setState(() {
                  _durationConfirmed = true;
                  _confirmed.add('duration');
                }),
                validator: (value) {
                  final minutes = int.tryParse(value ?? '');
                  return minutes == null || minutes < 1 || minutes > 1440
                      ? 'Enter between 1 and 1,440 minutes.'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              SelectionRadioGroup<TimingRule>(
                label: 'When',
                selectedValue: _timing,
                options: [
                  for (final rule in TimingRule.values)
                    SelectionOption(value: rule, label: rule.label),
                ],
                onChanged: (value) => setState(() {
                  _timing = value;
                  _timeError = null;
                }),
              ),
              if (_timing != TimingRule.anytime) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _minute == null ? 'Choose a time' : formatMinute(_minute!),
                  ),
                  trailing: const Icon(Icons.schedule_rounded),
                  onTap: () async {
                    final value = await chooseTime(
                      context,
                      title: _timing.label,
                      initialMinute: _minute ?? 540,
                    );
                    if (value != null && mounted) {
                      setState(() {
                        _minute = value;
                        _timeError = null;
                      });
                    }
                  },
                ),
                if (_timeError != null)
                  Text(
                    _timeError!,
                    style: context.type.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('If there’s time'),
                subtitle: const Text(
                  'This errand can wait if the day is full.',
                ),
                value: _optional,
                onChanged: (value) => setState(() => _optional = value),
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, const RemovedErrand()),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove errand'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NamePlaceDialog extends StatefulWidget {
  const _NamePlaceDialog();
  @override
  State<_NamePlaceDialog> createState() => _NamePlaceDialogState();
}

class _NamePlaceDialogState extends State<_NamePlaceDialog> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Name this location'),
    content: TextField(
      controller: input,
      autofocus: true,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Your label'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, input.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}
