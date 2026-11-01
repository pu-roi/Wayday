import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/section_surface.dart';
import '../../errands/presentation/errand_editor.dart';
import '../../maps/presentation/place_map.dart';
import '../../maps/presentation/regional_map.dart';
import '../../today/domain/day.dart';
import '../../today/presentation/today_controller.dart';
import '../domain/day_review.dart';

class DayReviewView extends ConsumerStatefulWidget {
  const DayReviewView({super.key});
  @override
  ConsumerState<DayReviewView> createState() => _DayReviewViewState();
}

class _DayReviewViewState extends ConsumerState<DayReviewView> {
  late DayReview _review;
  late DayPlan _original;
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    _original = ref.read(todayProvider);
    _review = DayReview(_original);
  }

  List<MapPin> get _pins => [
    MapPin('A', _review.day.fromPlace),
    for (var i = 0; i < _review.day.errands.length; i++)
      MapPin('${i + 1}', _review.day.errands[i].placeIntent),
    MapPin('Z', _review.day.toPlace),
  ];

  Future<void> _endpoint(bool start) async {
    final day = _review.day;
    final place = await choosePlace(
      context,
      title: start ? 'Starting point' : 'Final destination',
      initial: start ? day.from : day.to,
      initialPlace: start ? day.fromPlace : day.toPlace,
    );
    if (place != null && mounted) {
      setState(() => _review.setPlace(start: start, place: place));
    }
  }

  Future<void> _place(Errand errand) async {
    final place = await choosePlace(
      context,
      title: 'Choose a place',
      initial: errand.place,
      initialPlace: errand.placeIntent,
    );
    if (place != null && mounted) {
      setState(
        () => _review.replace(
          errand.copyWith(
            place: place.label,
            placeIntent: place,
            confirmedFields: {...errand.confirmedFields, 'place'},
          ),
        ),
      );
    }
  }

  Future<void> _edit(Errand errand) async {
    final result = await editErrand(
      context,
      errand,
      errands: _review.day.errands,
    );
    if (!mounted) return;
    switch (result) {
      case SavedErrand(:final errand):
        setState(() => _review.replace(errand));
      case RemovedErrand():
        final previous = _review.day;
        setState(
          () => _review.day = previous.copyWith(
            errands: previous.errands.where((e) => e.id != errand.id).toList(),
          ),
        );
        showFeedback(
          context,
          'Removed from this review.',
          onUndo: () {
            if (mounted) setState(() => _review.day = previous);
          },
        );
      case null:
        break;
    }
  }

  void _move(int from, int to) {
    final issue = _review.move(from, to);
    if (issue != null) {
      showFeedback(context, issue, advisory: true);
    } else {
      setState(() {});
    }
  }

  Future<void> _options(int index) async {
    final item = _review.day.errands[index];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: context.type.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.arrow_upward_rounded),
                  title: const Text('Move earlier'),
                  enabled: index > 0,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _move(index, index - 1);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.arrow_downward_rounded),
                  title: const Text('Move later'),
                  enabled: index < _review.day.errands.length - 1,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _move(index, index + 1);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.optional ? Icons.flag_outlined : Icons.flag_rounded,
                  ),
                  title: Text(
                    item.optional ? 'Make required' : 'Make optional',
                  ),
                  subtitle: Text(
                    item.optional
                        ? 'Keep this visit in your day.'
                        : 'Do this if there’s time. It stays in your list.',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(
                      () => _review.replace(
                        item.copyWith(optional: !item.optional),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Edit details'),
                  subtitle: const Text('Time, visit length and notes'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _edit(item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final issue = _review.orderingIssue;
    if (issue != null) {
      showFeedback(context, issue, advisory: true);
      return;
    }
    if (!identical(ref.read(todayProvider), _original)) {
      setState(() => _stale = true);
      return;
    }
    ref.read(todayProvider.notifier).restore(_review.day);
    Navigator.pop(context, true);
  }

  Widget _endpointRow(bool start) {
    final place = start ? _review.day.fromPlace : _review.day.toPlace;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        start ? Icons.trip_origin_rounded : Icons.location_on_outlined,
        color: context.wayday.link,
      ),
      title: Text(
        place.label.isEmpty
            ? (start ? 'Choose a starting point' : 'Choose a destination')
            : place.label,
        style: context.type.titleMedium,
      ),
      subtitle: Text(
        '${start ? 'Leave at ${formatMinute(_review.day.departure)}' : 'Home by ${formatMinute(_review.day.deadline)}'}${place.hasCoordinates ? '' : ' · Pin needed'}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _endpoint(start),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _review.day;
    return Scaffold(
      appBar: AppBar(title: const Text('Review your day')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            buildDefaultDragHandles: false,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(day.date))} · ${day.profile.label} · ${day.errands.length} errands',
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 200,
                    child: ref.watch(mapPlatformSupportedProvider)
                        ? ref.watch(placeMapBuilderProvider)(
                            PlaceMapRequest(pins: _pins, interactive: false),
                          )
                        : const Center(child: Text('Map available on Android')),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text('Explore map'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Your stops')),
                            body: SafeArea(
                              child: ref.read(placeMapBuilderProvider)(
                                PlaceMapRequest(pins: _pins),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Text(
                  'Your order. Travel times and opening hours are not checked yet.',
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                if (_stale)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SectionSurface(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Today changed while this review was open. Reload it before saving.',
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _original = ref.read(todayProvider);
                                _review = DayReview(_original);
                                _stale = false;
                              }),
                              child: const Text('Reload Today'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                _endpointRow(true),
                const Divider(),
              ],
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _endpointRow(false),
                const SizedBox(height: 12),
                Text(
                  _review.missingPlaces > 0
                      ? '${_review.missingPlaces} places still need a map pin. You can save this draft and finish later.'
                      : 'All places are pinned. Saving keeps your manual order on this device; no route is calculated.',
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            itemCount: day.errands.length,
            onReorderItem: _move,
            itemBuilder: (context, index) {
              final item = day.errands[index];
              return _ReviewStop(
                key: ValueKey(item.id),
                item: item,
                index: index,
                onPlace: () => _place(item),
                onEdit: () => _edit(item),
                onOptions: () => _options(index),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: day.errands.isEmpty || _stale ? null : _confirm,
                  child: const Text('Save manual order'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewStop extends StatelessWidget {
  const _ReviewStop({
    required this.item,
    required this.index,
    required this.onPlace,
    required this.onEdit,
    required this.onOptions,
    super.key,
  });
  final Errand item;
  final int index;
  final VoidCallback onPlace, onEdit, onOptions;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 40,
          child: Column(
            children: [
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 14,
                backgroundColor: context.colors.secondaryContainer,
                child: Text(
                  '${index + 1}',
                  style: context.type.labelMedium?.copyWith(
                    color: context.wayday.link,
                  ),
                ),
              ),
              Expanded(
                child: VerticalDivider(
                  color: context.colors.outlineVariant,
                  thickness: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onEdit,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              item.title,
                              style: context.type.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Options for ${item.title}',
                      onPressed: onOptions,
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                    const SizedBox(width: 8),
                    ReorderableDragStartListener(
                      index: index,
                      child: Semantics(
                        label:
                            'Drag to reorder ${item.title}; move controls in Options',
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.drag_handle_rounded, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onPlace,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: context.wayday.link,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.place.isEmpty
                                  ? 'Choose a place'
                                  : item.place,
                              style: context.type.bodyMedium?.copyWith(
                                color: context.wayday.link,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  '${item.timing == TimingRule.anytime ? 'Anytime' : '${item.timing.label} ${formatMinute(item.minute!)}'} · ${item.durationMinutes} min${item.durationConfirmed ? '' : ' assumed'}',
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  item.optional ? 'Optional · if there’s time' : 'Required',
                  style: context.type.bodySmall?.copyWith(
                    color: context.wayday.link,
                  ),
                ),
                if (!item.placeIntent.hasCoordinates)
                  Text(
                    'Map pin needed',
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
