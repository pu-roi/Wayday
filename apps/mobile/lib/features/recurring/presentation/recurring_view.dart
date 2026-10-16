import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_surface.dart';
import '../../errands/domain/errand.dart';
import '../../errands/presentation/errand_editor.dart';
import '../../errands/presentation/errand_list.dart';
import '../../today/presentation/today_controller.dart';
import '../domain/errand_group.dart';
import 'group_editor.dart';
import 'recurring_controller.dart';

class RecurringView extends ConsumerStatefulWidget {
  const RecurringView({super.key});
  @override
  ConsumerState<RecurringView> createState() => _RecurringViewState();
}

class _RecurringViewState extends ConsumerState<RecurringView> {
  final _collapsed = <String>{};
  void _edit(BuildContext context, ErrandGroup group, {bool isNew = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => GroupEditor(group: group, isNew: isNew),
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    ErrandGroup group,
    Errand item,
  ) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final result = await editErrand(context, item);
    if (!context.mounted) return;
    final controller = ref.read(recurringProvider.notifier);
    switch (result) {
      case SavedErrand(:final errand):
        controller.save(
          ErrandGroup(
            id: group.id,
            name: group.name,
            repeat: group.repeat,
            day: group.day,
            items: [
              for (final old in group.items)
                if (old.id == errand.id) errand else old,
            ],
          ),
        );
      case RemovedErrand():
        if (group.items.length == 1) {
          showFeedback(
            context,
            'Keep one errand, or delete the whole list.',
            advisory: true,
          );
          return;
        }
        final previous = ref.read(recurringProvider);
        controller.save(
          ErrandGroup(
            id: group.id,
            name: group.name,
            repeat: group.repeat,
            day: group.day,
            items: group.items.where((old) => old.id != item.id).toList(),
          ),
        );
        showFeedback(
          context,
          'Errand removed from the list.',
          onUndo: () => controller.restore(previous),
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(recurringProvider);
    final today = ref.watch(todayProvider);
    void create() => _edit(
      context,
      ErrandGroup(
        id: ref.read(recurringProvider.notifier).reserveGroupId(),
        name: '',
        items: [],
      ),
      isNew: true,
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text('Recurring', style: context.type.headlineLarge),
        actions: [
          IconButton(
            tooltip: 'New recurring list',
            onPressed: create,
            icon: Icon(Icons.note_add_outlined, color: context.wayday.link),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                child: Text(
                  'Your familiar errands, all in one place.',
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A list worth keeping.',
                        style: context.type.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Group your regular errands, then bring them into Today whenever you need them.',
                        style: context.type.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final group in groups)
                Padding(
                  key: ValueKey(group.id),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SectionSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    if (!_collapsed.remove(group.id)) {
                                      _collapsed.add(group.id);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                group.name,
                                                style: context.type.titleMedium,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AnimatedRotation(
                                              turns:
                                                  _collapsed.contains(group.id)
                                                  ? 0
                                                  : .5,
                                              duration: WaydayMotion.duration(
                                                context,
                                              ),
                                              curve: WaydayMotion.curve,
                                              child: Icon(
                                                Icons.expand_more_rounded,
                                                size: 20,
                                                color: context
                                                    .colors
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          group.schedule,
                                          style: context.type.bodySmall
                                              ?.copyWith(
                                                color: context
                                                    .colors
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit ${group.name}',
                                onPressed: () => _edit(context, group),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                            ],
                          ),
                        ),
                        SmoothDisclosure(
                          key: ValueKey('group-${group.id}'),
                          expanded: !_collapsed.contains(group.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              AnimatedErrandList(
                                items: group.items,
                                onEdit: (errand) =>
                                    _editItem(context, ref, group, errand),
                              ),
                              const SizedBox(height: 8),
                              const Divider(indent: 20, endIndent: 20),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed:
                                        group.items.isEmpty ||
                                            group.items.every(
                                              (item) => today.errands.any(
                                                (copy) =>
                                                    copy.sourceGroupId ==
                                                        group.id &&
                                                    copy.sourceItemId ==
                                                        item.id,
                                              ),
                                            )
                                        ? null
                                        : () {
                                            final count = ref
                                                .read(todayProvider.notifier)
                                                .addGroup(
                                                  groupId: group.id,
                                                  errands: group.items,
                                                );
                                            showFeedback(
                                              context,
                                              '$count ${count == 1 ? 'errand' : 'errands'} added to Today.',
                                            );
                                          },
                                    icon: Icon(
                                      group.items.isNotEmpty &&
                                              group.items.every(
                                                (item) => today.errands.any(
                                                  (copy) =>
                                                      copy.sourceGroupId ==
                                                          group.id &&
                                                      copy.sourceItemId ==
                                                          item.id,
                                                ),
                                              )
                                          ? Icons.check_rounded
                                          : Icons.playlist_add_rounded,
                                      size: 20,
                                    ),
                                    label: Text(
                                      group.items.isNotEmpty &&
                                              group.items.every(
                                                (item) => today.errands.any(
                                                  (copy) =>
                                                      copy.sourceGroupId ==
                                                          group.id &&
                                                      copy.sourceItemId ==
                                                          item.id,
                                                ),
                                              )
                                          ? 'Added to Today'
                                          : 'Add to Today',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: create,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New recurring list'),
              ),
              const SizedBox(height: 16),
              Text(
                'Example lists · Changes reset when the app restarts.',
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
