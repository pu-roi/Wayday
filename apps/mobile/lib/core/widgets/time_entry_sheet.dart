import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../features/errands/domain/errand.dart';

Future<int?> chooseTime(
  BuildContext context, {
  required String title,
  required int initialMinute,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  builder: (_) => TimeEntrySheet(title: title, initialMinute: initialMinute),
);

class TimeEntrySheet extends StatefulWidget {
  const TimeEntrySheet({
    required this.title,
    required this.initialMinute,
    super.key,
  });
  final String title;
  final int initialMinute;
  @override
  State<TimeEntrySheet> createState() => _TimeEntrySheetState();
}

class _TimeEntrySheetState extends State<TimeEntrySheet> {
  final _form = GlobalKey<FormState>();
  late final _hour = TextEditingController(
    text:
        '${widget.initialMinute ~/ 60 % 12 == 0 ? 12 : widget.initialMinute ~/ 60 % 12}',
  );
  late final _minute = TextEditingController(
    text: '${widget.initialMinute % 60}'.padLeft(2, '0'),
  );
  late bool _pm = widget.initialMinute >= 720;
  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  void _select(int value) {
    final hour = value ~/ 60;
    _hour.text = '${hour % 12 == 0 ? 12 : hour % 12}';
    _minute.text = '${value % 60}'.padLeft(2, '0');
    setState(() => _pm = hour >= 12);
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      (int.parse(_hour.text) % 12 + (_pm ? 12 : 0)) * 60 +
          int.parse(_minute.text),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: context.type.titleLarge),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TimeField(
                      controller: _hour,
                      fieldKey: const Key('time-hour'),
                      label: 'Hour',
                      validator: (value) {
                        final n = int.tryParse(value ?? '');
                        return n == null || n < 1 || n > 12 ? 'Use 1–12' : null;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(':', style: context.type.headlineLarge),
                  ),
                  Expanded(
                    child: _TimeField(
                      controller: _minute,
                      fieldKey: const Key('time-minute'),
                      label: 'Minute',
                      validator: (value) {
                        final n = int.tryParse(value ?? '');
                        return n == null || n < 0 || n > 59
                            ? 'Use 00–59'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('AM')),
                    ButtonSegment(value: true, label: Text('PM')),
                  ],
                  selected: {_pm},
                  onSelectionChanged: (value) =>
                      setState(() => _pm = value.single),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minute in [480, 720, 1080])
                    ActionChip(
                      label: Text(formatMinute(minute)),
                      onPressed: () => _select(minute),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save time'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.controller,
    required this.fieldKey,
    required this.label,
    required this.validator,
  });
  final TextEditingController controller;
  final Key fieldKey;
  final String label;
  final FormFieldValidator<String> validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    style: context.type.headlineLarge,
    maxLength: 2,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, counterText: ''),
    validator: validator,
    onTap: () => controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    ),
  );
}
