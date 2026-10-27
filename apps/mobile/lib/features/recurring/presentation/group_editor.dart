import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_surface.dart';
import '../../../core/widgets/selection_controls.dart';
import '../../errands/domain/errand.dart';
import '../../errands/presentation/errand_editor.dart';
import '../../errands/presentation/errand_list.dart';
import '../domain/errand_group.dart';
import 'recurring_controller.dart';

class GroupEditor extends ConsumerStatefulWidget {
  const GroupEditor({required this.group, this.isNew = false, super.key});
  final ErrandGroup group;
  final bool isNew;
  @override
  ConsumerState<GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ConsumerState<GroupEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group.name);
  late List<Errand> _items = [...widget.group.items];
  late RepeatPattern _repeat = widget.group.repeat;
  late int _day = widget.group.day;
  late final _monthDay = TextEditingController(text: '${widget.group.day}');
  final _monthDayFocus = FocusNode();
  final _monthDayAnchor = GlobalKey();
  final _weekdayFocus = FocusNode();
  final _scroll = ScrollController();
  bool _scheduleOpen = false;
  String? _itemsError;
  @override
  void dispose() {
    _name.dispose();
    _monthDay.dispose();
    _monthDayFocus.dispose();
    _weekdayFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final scrollDuration = WaydayMotion.duration(context);
    // A long list can dispose the field; its monthly draft still needs validation.
    final invalidMonthDay =
        _repeat == RepeatPattern.monthly &&
        _validateMonthDay(_monthDay.text) != null;
    final validForm = _form.currentState?.validate() ?? false;
    if (invalidMonthDay) {
      setState(() => _scheduleOpen = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (scrollDuration == Duration.zero) {
        _scroll.jumpTo(0);
      } else {
        await _scroll.animateTo(
          0,
          duration: scrollDuration,
          curve: WaydayMotion.curve,
        );
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _form.currentState?.validate();
      _monthDayFocus.requestFocus();
      final fieldContext = _monthDayAnchor.currentContext;
      if (fieldContext != null && fieldContext.mounted) {
        await Scrollable.ensureVisible(
          fieldContext,
          alignment: .5,
          duration: scrollDuration,
        );
      }
      return;
    }
    if (!validForm) return;
    if (_repeat == RepeatPattern.monthly) _day = int.parse(_monthDay.text);
    if (_items.isEmpty) {
      setState(() => _itemsError = 'Add at least one errand to this list.');
      return;
    }
    ref
        .read(recurringProvider.notifier)
        .save(
          ErrandGroup(
            id: widget.group.id,
            name: _name.text.trim(),
            items: _items,
            repeat: _repeat,
            day: _day,
          ),
        );
    Navigator.pop(context);
  }

  String? _validateMonthDay(String? value) {
    final day = int.tryParse(value ?? '');
    return day == null || day < 1 || day > 31
        ? 'Use a day from 1 to 31.'
        : null;
  }

  void _changeRepeat(RepeatPattern value) {
    if (_monthDayFocus.hasFocus) _monthDayFocus.unfocus();
    setState(() {
      _repeat = value;
      if (value != RepeatPattern.monthly && _day > 7) _day = 6;
      _monthDay.text = '$_day';
    });
  }

  Future<void> _edit(Errand item) async {
    final result = await editErrand(context, item);
    if (!mounted) return;
    switch (result) {
      case SavedErrand(:final errand):
        setState(
          () => _items = [
            for (final old in _items)
              if (old.id == errand.id) errand else old,
          ],
        );
      case RemovedErrand():
        final previous = [..._items];
        setState(() => _items.removeWhere((old) => old.id == item.id));
        showFeedback(
          context,
          'Errand removed from this draft.',
          onUndo: () {
            if (mounted) setState(() => _items = previous);
          },
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.isNew ? 'New list' : 'Edit list'),
      actions: [
        TextButton(onPressed: _save, child: const Text('Save list')),
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
            controller: _scroll,
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                key: const Key('group-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: context.type.titleLarge,
                decoration: const InputDecoration(
                  labelText: 'List name',
                  hintText: 'e.g. Weekend errands',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Give your list a name.'
                    : null,
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.repeat_rounded, color: context.wayday.link),
                title: const Text('Repeat'),
                subtitle: Text(
                  ErrandGroup(
                    id: '',
                    name: '',
                    items: [],
                    repeat: _repeat,
                    day: _day,
                  ).schedule,
                ),
                trailing: AnimatedRotation(
                  turns: _scheduleOpen ? .5 : 0,
                  duration: WaydayMotion.duration(context),
                  curve: WaydayMotion.curve,
                  child: const Icon(Icons.expand_more_rounded),
                ),
                onTap: () => setState(() => _scheduleOpen = !_scheduleOpen),
              ),
              SmoothDisclosure(
                expanded: _scheduleOpen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    SelectionRadioGroup<RepeatPattern>(
                      label: 'How often',
                      selectedValue: _repeat,
                      options: [
                        for (final pattern in RepeatPattern.values)
                          SelectionOption(value: pattern, label: pattern.label),
                      ],
                      onChanged: _changeRepeat,
                    ),
                    if (_repeat == RepeatPattern.monthly) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        key: _monthDayAnchor,
                        child: TextFormField(
                          key: const Key('repeat-month-day'),
                          controller: _monthDay,
                          focusNode: _monthDayFocus,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Day of month',
                            helperText: 'Choose a day from 1 to 31.',
                            counterText: '',
                          ),
                          validator: _validateMonthDay,
                          onChanged: (value) {
                            final day = int.tryParse(value);
                            if (day != null && day >= 1 && day <= 31) {
                              setState(() => _day = day);
                            }
                          },
                          onTap: () => _monthDay.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _monthDay.text.length,
                          ),
                        ),
                      ),
                    ] else if (_repeat != RepeatPattern.asNeeded) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        key: const Key('repeat-weekday'),
                        focusNode: _weekdayFocus,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Day'),
                        subtitle: Text(weekdays[_day - 1]),
                        trailing: const Icon(Icons.expand_more_rounded),
                        onTap: () async {
                          final day = await chooseSingleChoice<int>(
                            context,
                            title: 'Day',
                            options: [
                              for (var day = 1; day <= weekdays.length; day++)
                                SelectionOption(
                                  value: day,
                                  label: weekdays[day - 1],
                                ),
                            ],
                            selectedValue: _day,
                            returnFocusNode: _weekdayFocus,
                          );
                          if (day != null && mounted) {
                            setState(() => _day = day);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Add this list to Today when you’re ready. It won’t be added automatically.',
                      style: context.type.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Text('Errands', style: context.type.titleMedium),
                    ),
                    SmoothDisclosure(
                      expanded: _items.isEmpty,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          'The little things you do together.',
                          style: context.type.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    AnimatedErrandList(items: [..._items], onEdit: _edit),
                    ErrandComposer(
                      key: const Key('group-composer'),
                      onAdd: (title) => setState(() {
                        _items.add(
                          Errand(
                            id: ref
                                .read(recurringProvider.notifier)
                                .reserveItemId(),
                            title: title,
                          ),
                        );
                        _itemsError = null;
                      }),
                    ),
                  ],
                ),
              ),
              if (_itemsError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _itemsError!,
                    style: context.type.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Each errand starts as Anytime. Tap a row when you want to add details.',
                style: context.type.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              if (!widget.isNew) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    final controller = ref.read(recurringProvider.notifier);
                    final previous = ref.read(recurringProvider);
                    controller.remove(widget.group.id);
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    showFeedback(
                      context,
                      'Recurring list deleted.',
                      messenger: messenger,
                      onUndo: () => controller.restore(previous),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete list'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
