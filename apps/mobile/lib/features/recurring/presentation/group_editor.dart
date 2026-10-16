import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_surface.dart';
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
  bool _scheduleOpen = false;
  String? _itemsError;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
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
                    DropdownButtonFormField<RepeatPattern>(
                      initialValue: _repeat,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'How often'),
                      items: RepeatPattern.values
                          .map(
                            (pattern) => DropdownMenuItem(
                              value: pattern,
                              child: Text(pattern.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _repeat = value;
                            if (value != RepeatPattern.monthly && _day > 7) {
                              _day = 6;
                            }
                          });
                        }
                      },
                    ),
                    if (_repeat != RepeatPattern.asNeeded) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey(_repeat),
                        initialValue: _day,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _repeat == RepeatPattern.monthly
                              ? 'Day of month'
                              : 'Day',
                        ),
                        items: [
                          for (
                            var day = 1;
                            day <= (_repeat == RepeatPattern.monthly ? 31 : 7);
                            day++
                          )
                            DropdownMenuItem(
                              value: day,
                              child: Text(
                                _repeat == RepeatPattern.monthly
                                    ? 'Day $day'
                                    : weekdays[day - 1],
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _day = value);
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
