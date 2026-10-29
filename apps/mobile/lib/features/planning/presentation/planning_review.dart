import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/section_surface.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import 'planning_controller.dart';
import 'review_changes.dart';
import 'review_errand_tile.dart';

class PlanningReview extends StatelessWidget {
  const PlanningReview({
    required this.model,
    required this.tripDetails,
    required this.footer,
    required this.onEdit,
    required this.onLocation,
    required this.onChanged,
    super.key,
  });
  final PlanningController model;
  final Widget tripDetails, footer;
  final ValueChanged<Errand> onEdit, onLocation;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Your settings stay unless you choose a suggestion.',
                  style: context.type.bodyMedium,
                ),
                const SizedBox(height: 16),
                tripDetails,
                const SizedBox(height: 16),
                if (model.interpretationStale) ...[
                  const Text(
                    'Notes changed. Read them again before finding places.',
                  ),
                  OutlinedButton(
                    onPressed: model.understand,
                    child: const Text('Read updated notes with Gemini'),
                  ),
                  const SizedBox(height: 16),
                ],
                SectionSurface(
                  child: Column(
                    children: [
                      for (var i = 0; i < model.day.errands.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 20, endIndent: 20),
                        _errand(model.day.errands[i], i + 1),
                      ],
                    ],
                  ),
                ),
                for (final n
                    in model.interpretation?.additions ?? <ErrandNeed>[]) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    expansionAnimationStyle:
                        MediaQuery.disableAnimationsOf(context)
                        ? AnimationStyle.noAnimation
                        : null,
                    title: Text(n.proposedTitle ?? n.query),
                    subtitle: Text(
                      model.additions.contains(n.id)
                          ? 'Extra errand selected'
                          : 'Suggested extra errand',
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          [
                            n.query,
                            if (n.items.isNotEmpty)
                              'Items: ${n.items.join(', ')}',
                            '${n.durationMinutes} min estimate · ${n.optional == true ? 'If there’s time' : 'Required'}',
                            reviewTiming(
                              n.apply(
                                Errand(
                                  id: n.id,
                                  title: n.proposedTitle ?? n.query,
                                ),
                              ),
                            ),
                            if (n.after.isNotEmpty)
                              'After ${n.after.map((id) => model.day.errands.where((e) => e.id == id).firstOrNull?.title ?? model.interpretation?.additions.where((e) => e.id == id).firstOrNull?.proposedTitle ?? 'another suggested errand').join(', ')}',
                          ].join('\n'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            if (model.additions.contains(n.id)) {
                              model.additions.remove(n.id);
                            } else {
                              model.additions.add(n.id);
                            }
                            onChanged();
                          },
                          icon: Icon(
                            model.additions.contains(n.id)
                                ? Icons.remove
                                : Icons.add,
                            size: 18,
                          ),
                          label: Text(
                            model.additions.contains(n.id)
                                ? 'Remove extra errand'
                                : 'Add extra errand',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          footer,
        ],
      ),
    ),
  );

  Widget _errand(Errand e, int index) {
    final original = model.reviewInput(e), need = model.needs[e.id];
    return ReviewErrandTile(
      key: ValueKey(e.id),
      errand: original,
      index: index,
      need: need,
      currentOrder: original.afterErrandIds.isEmpty
          ? null
          : original.afterErrandIds
                .map(
                  (id) =>
                      model.day.errands
                          .where((e) => e.id == id)
                          .firstOrNull
                          ?.title ??
                      'unavailable errand',
                )
                .join(', '),
      changes: need == null
          ? []
          : reviewChanges(original, need, [
              ...model.day.errands,
              for (final n in model.interpretation?.additions ?? <ErrandNeed>[])
                Errand(id: n.id, title: n.proposedTitle ?? n.query),
            ]),
      approved: model.approved.contains(e.id),
      clarified: model.clarified.contains(e.id),
      onApproval: (value) {
        if (value) {
          model.approved.add(e.id);
        } else {
          model.approved.remove(e.id);
        }
        onChanged();
      },
      onEdit: () => onEdit(e),
      onLocation: () => onLocation(e),
    );
  }
}
