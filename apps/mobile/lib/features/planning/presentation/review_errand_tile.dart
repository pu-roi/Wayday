import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import '../domain/errand_location_review.dart';
import 'review_changes.dart';

class ReviewErrandTile extends StatefulWidget {
  const ReviewErrandTile({
    required this.errand,
    required this.index,
    required this.need,
    required this.changes,
    required this.approved,
    required this.onApproval,
    required this.onEdit,
    required this.onLocation,
    required this.clarified,
    required this.currentOrder,
    super.key,
  });
  final Errand errand;
  final int index;
  final ErrandNeed? need;
  final List<ReviewChange> changes;
  final bool approved, clarified;
  final String? currentOrder;
  final ValueChanged<bool> onApproval;
  final VoidCallback onEdit, onLocation;
  @override
  State<ReviewErrandTile> createState() => _ReviewErrandTileState();
}

class _ReviewErrandTileState extends State<ReviewErrandTile> {
  bool kept = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.errand, need = widget.need;
    final changes = widget.clarified ? <ReviewChange>[] : widget.changes;
    final question = outstandingQuestion(need, clarified: widget.clarified);
    final missingLocation = needsActualLocation(e, need);
    final status = widget.approved
        ? 'Suggestion selected'
        : kept
        ? 'Current settings kept'
        : '${changes.length} suggested ${changes.length == 1 ? 'change' : 'changes'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: context.colors.secondaryContainer,
            foregroundColor: context.wayday.link,
            child: Text('${widget.index}', style: context.type.labelMedium),
          ),
          title: Text(
            e.title,
            style: context.type.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${reviewTiming(e)} · ${e.durationMinutes} min${e.durationConfirmed ? '' : ' estimate'}${e.optional ? ' · If there’s time' : ''}',
                style: context.type.bodySmall,
              ),
              if (needsPlaceRecommendation(e, need))
                Text(
                  'Place recommendations next',
                  style: context.type.bodySmall,
                ),
              if (changes.isNotEmpty)
                Text(
                  status,
                  style: context.type.bodySmall?.copyWith(
                    color: context.wayday.link,
                  ),
                ),
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.notes.trim().isNotEmpty) _detail('Notes', e.notes),
                  if (widget.currentOrder != null)
                    _detail('After', widget.currentOrder!),
                  if (e.placeIntent.hasCoordinates)
                    _detail('Place', e.placeIntent.label),
                  if (need != null && !need.meeting && !widget.clarified) ...[
                    _detail(
                      'Find',
                      need.query.isEmpty ? need.category : need.query,
                    ),
                    if (need.items.isNotEmpty)
                      _detail('Items', need.items.join(', ')),
                  ],
                  for (final change in changes)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(change.label, style: context.type.labelLarge),
                          Text(
                            'Current: ${change.current}',
                            style: context.type.bodyMedium,
                          ),
                          Text(
                            'Suggested: ${change.suggested}',
                            style: context.type.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (changes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: widget.approved
                            ? null
                            : () {
                                setState(() => kept = false);
                                widget.onApproval(true);
                              },
                        child: Text(
                          changes.length == 1
                              ? 'Use suggestion'
                              : 'Use suggestions',
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => kept = true);
                          widget.onApproval(false);
                        },
                        child: const Text('Keep current'),
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit errand'),
              ),
            ),
          ],
        ),
        if (question != null || missingLocation)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (question != null)
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.help_outline),
                    label: Text(question, textAlign: TextAlign.start),
                  ),
                if (missingLocation)
                  OutlinedButton.icon(
                    onPressed: widget.onLocation,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Choose actual location'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text('$label: $value', style: context.type.bodyMedium),
  );
}
