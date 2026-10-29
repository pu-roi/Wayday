import '../../today/domain/day.dart';
import '../domain/planning_models.dart';

typedef ReviewChange = ({String label, String current, String suggested});

String reviewTiming(Errand e) => e.timing == TimingRule.anytime
    ? 'Anytime'
    : '${e.timing == TimingRule.at ? 'At' : e.timing.label} ${e.minute == null ? '—' : formatMinute(e.minute!)}';

/// Compare the effective proposal, including the domain's explicit-field guards.
List<ReviewChange> reviewChanges(
  Errand original,
  ErrandNeed need,
  List<Errand> errands,
) {
  final proposed = need.apply(original);
  String after(Errand e) => e.afterErrandIds.isEmpty
      ? 'No ordering rule'
      : 'After ${e.afterErrandIds.map((id) => errands.where((x) => x.id == id).firstOrNull?.title ?? 'another suggested errand').join(', ')}';
  return [
    if (proposed.durationMinutes != original.durationMinutes)
      (
        label: 'Visit time',
        current: '${original.durationMinutes} min',
        suggested: '${proposed.durationMinutes} min',
      ),
    if (reviewTiming(proposed) != reviewTiming(original))
      (
        label: 'When',
        current: reviewTiming(original),
        suggested: reviewTiming(proposed),
      ),
    if (proposed.optional != original.optional)
      (
        label: 'Priority',
        current: original.optional ? 'If there’s time' : 'Required',
        suggested: proposed.optional ? 'If there’s time' : 'Required',
      ),
    if (!original.afterErrandIds.toSet().containsAll(proposed.afterErrandIds) ||
        !proposed.afterErrandIds.toSet().containsAll(original.afterErrandIds))
      (label: 'Order', current: after(original), suggested: after(proposed)),
  ];
}
