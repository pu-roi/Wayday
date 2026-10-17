import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../domain/errand.dart';
import '../domain/errand_interpreter.dart';
import '../../places/domain/place_intent.dart';
import '../../places/presentation/saved_places_controller.dart';

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

class _ErrandEditorState extends ConsumerState<ErrandEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.errand.title);
  late final _notes = TextEditingController(text: widget.errand.notes);
  late final _duration = TextEditingController(
    text: '${widget.errand.durationMinutes}',
  );
  late PlaceIntent _placeIntent = widget.errand.placeIntent;
  late bool _durationConfirmed = widget.errand.durationConfirmed;
  late final _confirmed = {...widget.errand.confirmedFields};
  late String _place = widget.errand.place;
  late TimingRule _timing = widget.errand.timing;
  late int? _minute = widget.errand.minute;
  late bool _optional = widget.errand.optional;
  String? _timeError;
  @override
  void dispose() {
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
          timing: _timing,
          minute: _minute,
          clearTime: _timing == TimingRule.anytime,
          optional: _optional,
          placeIntent: _placeIntent,
          durationMinutes: int.parse(_duration.text),
          durationConfirmed: _durationConfirmed,
          confirmedFields: _confirmed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit errand'),
      actions: [
        TextButton(onPressed: _save, child: const Text('Save')),
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
                onChanged: (_) => setState(() {}),
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
              _suggestionDetails(),
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
                subtitle: const Text('Open map'),
                trailing: Icon(Icons.map_outlined, color: context.wayday.link),
                onTap: () async {
                  final place = await choosePlace(
                    context,
                    title: 'Errand location',
                    initial: _place,
                    initialIntent: _placeIntent,
                  );
                  if (place != null && mounted) {
                    setState(() {
                      _place = place.label;
                      _placeIntent = place;
                      _confirmed.add('place');
                    });
                  }
                },
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
              Text('When', style: context.type.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<TimingRule>(
                initialValue: _timing,
                isExpanded: true,
                items: TimingRule.values
                    .map(
                      (rule) => DropdownMenuItem(
                        value: rule,
                        child: Text(rule.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _timing = value;
                      _confirmed.add('timing');
                      _timeError = null;
                    });
                  }
                },
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
                        _confirmed.add('timing');
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
                onChanged: (value) => setState(() {
                  _optional = value;
                  _confirmed.add('optional');
                }),
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

  Widget _suggestionDetails() {
    final suggestion = interpretErrand(
      _title.text,
      savedPlaces: ref.watch(savedPlacesProvider),
    );
    if (!suggestion.hasDetails && suggestion.questions.isEmpty) {
      return const SizedBox.shrink();
    }
    final place = !_confirmed.contains('place') && _place.isEmpty
        ? suggestion.place
        : null;
    final timing =
        !_confirmed.contains('timing') && _timing == TimingRule.anytime
        ? suggestion.timing
        : null;
    final duration = !_confirmed.contains('duration') && !_durationConfirmed
        ? suggestion.durationMinutes
        : null;
    final optional = !_confirmed.contains('optional')
        ? suggestion.optional
        : null;
    final canApply =
        place != null || timing != null || duration != null || optional != null;
    return ExpansionTile(
      key: const Key('errand-suggestions'),
      tilePadding: EdgeInsets.zero,
      title: const Text('Review suggested details'),
      subtitle: const Text('Optional · your edited details stay'),
      children: [
        if (place != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              place.kind == PlaceKind.saved
                  ? place.label
                  : 'Any suitable ${place.label} location',
            ),
            subtitle: Text(
              place.kind == PlaceKind.saved
                  ? 'Your saved place'
                  : 'Choose a branch later',
            ),
          ),
        if (timing != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${timing.label} ${formatMinute(suggestion.minute!)}'),
          ),
        if (duration != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('$duration minutes for this visit'),
          ),
        if (optional == true)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('If there’s time'),
          ),
        for (final question in suggestion.questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(question),
          ),
        if (canApply)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                if (place != null) {
                  _placeIntent = place;
                  _place = place.label;
                  _confirmed.add('place');
                }
                if (timing != null) {
                  _timing = timing;
                  _minute = suggestion.minute;
                  _confirmed.add('timing');
                }
                if (duration != null) {
                  _duration.text = '$duration';
                  _durationConfirmed = true;
                  _confirmed.add('duration');
                }
                if (optional != null) {
                  _optional = optional;
                  _confirmed.add('optional');
                }
              }),
              child: const Text('Use suggested details'),
            ),
          ),
      ],
    );
  }
}
