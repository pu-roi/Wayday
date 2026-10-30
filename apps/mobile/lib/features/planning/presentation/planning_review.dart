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
    required this.onClarify,
    required this.onDefer,
    required this.onChanged,
    super.key,
  });
  final PlanningController model;
  final Widget tripDetails, footer;
  final ValueChanged<Errand> onEdit, onLocation, onClarify, onDefer;
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
                if (model.clarifications.storageError != null) ...[
                  Text(model.clarifications.storageError!),
                  TextButton(
                    onPressed: () async {
                      try {
                        await model.clarifications.retrySave();
                      } catch (_) {}
                    },
                    child: const Text('Retry saving answers'),
                  ),
                ],
                if (model.error != null) Text(model.error!),
                SectionSurface(
                  child: Column(
                    children: [
                      for (var i = 0; i < model.reviewErrands.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 20, endIndent: 20),
                        _errand(model.reviewErrands[i], i + 1),
                      ],
                    ],
                  ),
                ),
                for (final n
                    in (model.interpretation?.additions ?? <ErrandNeed>[])
                        .where((n) => !model.additions.contains(n.id))) ...[
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
                              model.addAddition(n);
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
    final original = model.reviewInput(e), need = model.effectiveNeed(e);
    return ReviewErrandTile(
      key: ValueKey(e.id),
      errand: e,
      index: index,
      need: need,
      currentOrder: e.afterErrandIds.isEmpty
          ? null
          : e.afterErrandIds
                .map(
                  (id) =>
                      model.reviewOrder.items
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
      clarified: model.questionResolved(e),
      answer: model.answerFor(e),
      deferral: model.deferred[e.id],
      onClarify: () => onClarify(e),
      onDefer: () => onDefer(e),
      onInclude: () async {
        try {
          await model.clarifications.include(model.day.date, e);
        } catch (error) {
          model.error = error.toString();
          onChanged();
        }
      },
      onRulesApproval: (v) async {
        try {
          await model.clarifications.approveRules(model.questionContext(e), v);
        } catch (_) {}
      },
      onApproval: (value) {
        if (value) {
          model.approved.add(e.id);
        } else {
          model.approved.remove(e.id);
        }
        onChanged();
      },
      onRemoveExtra: model.additions.contains(e.id)
          ? () => model.removeAddition(e.id)
          : null,
      onEdit: () => onEdit(e),
      onLocation: () => onLocation(e),
    );
  }
}
