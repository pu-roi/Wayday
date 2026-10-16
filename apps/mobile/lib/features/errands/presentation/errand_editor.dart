import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../domain/errand.dart';

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

class ErrandEditor extends StatefulWidget {
  const ErrandEditor({required this.errand, super.key});
  final Errand errand;
  @override
  State<ErrandEditor> createState() => _ErrandEditorState();
}

class _ErrandEditorState extends State<ErrandEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.errand.title);
  late final _notes = TextEditingController(text: widget.errand.notes);
  late String _place = widget.errand.place;
  late TimingRule _timing = widget.errand.timing;
  late int? _minute = widget.errand.minute;
  late bool _optional = widget.errand.optional;
  String? _timeError;
  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
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
                subtitle: const Text('Open map'),
                trailing: Icon(Icons.map_outlined, color: context.wayday.link),
                onTap: () async {
                  final place = await choosePlace(
                    context,
                    title: 'Errand location',
                    initial: _place,
                  );
                  if (place != null && mounted) setState(() => _place = place);
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
