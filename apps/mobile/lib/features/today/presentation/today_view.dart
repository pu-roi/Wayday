import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/section_surface.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../../errands/presentation/errand_editor.dart';
import '../../errands/presentation/errand_list.dart';
import '../domain/day.dart';
import '../../review/presentation/day_review_view.dart';
import 'today_controller.dart';

IconData profileIcon(TravelProfile profile) => switch (profile) {
  TravelProfile.walk => Icons.directions_walk_rounded,
  TravelProfile.bike => Icons.pedal_bike_rounded,
  TravelProfile.motor => Icons.two_wheeler_rounded,
  TravelProfile.sedan => Icons.directions_car_outlined,
  TravelProfile.truck => Icons.local_shipping_outlined,
};

class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key});
  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  bool _expanded = true;
  bool _showAll = false;
  void _clear() {
    final previous = ref.read(todayProvider);
    final controller = ref.read(todayProvider.notifier);
    controller.clear();
    showFeedback(
      context,
      'Errands cleared.',
      onUndo: () => controller.restore(previous),
    );
  }

  Future<void> _edit(Errand errand) async {
    final result = await editErrand(context, errand);
    if (!mounted) return;
    final controller = ref.read(todayProvider.notifier);
    switch (result) {
      case SavedErrand(:final errand):
        controller.update(errand);
      case RemovedErrand():
        final previous = ref.read(todayProvider);
        controller.remove(errand.id);
        showFeedback(
          context,
          'Errand removed.',
          onUndo: () => controller.restore(previous),
        );
      case null:
        break;
    }
  }

  Future<void> _place(bool start) async {
    final day = ref.read(todayProvider);
    final value = await choosePlace(
      context,
      title: start ? 'Starting point' : 'Final destination',
      initial: start ? day.from : day.to,
      initialIntent: start ? day.fromPlace : day.toPlace,
    );
    if (value != null && mounted) {
      ref
          .read(todayProvider.notifier)
          .setEndpoint(start: start, value: value.label, place: value);
    }
  }

  Future<void> _time(bool start) async {
    final day = ref.read(todayProvider);
    final value = await chooseTime(
      context,
      title: start ? 'Leave at' : 'Home by',
      initialMinute: start ? day.departure : day.deadline,
    );
    if (value == null || !mounted) return;
    if ((start && value >= day.deadline) ||
        (!start && value <= day.departure)) {
      showFeedback(
        context,
        'Choose a home-by time after your departure.',
        advisory: true,
      );
      return;
    }
    ref
        .read(todayProvider.notifier)
        .setTimes(
          departure: start ? value : null,
          deadline: start ? null : value,
        );
  }

  void _travel() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How are you getting around?',
                style: context.type.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final profile in TravelProfile.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(profileIcon(profile)),
                  title: Text(profile.label),
                  subtitle: switch (profile) {
                    TravelProfile.sedan => const Text('Low ground clearance'),
                    TravelProfile.truck => const Text('High ground clearance'),
                    _ => null,
                  },
                  trailing: ref.read(todayProvider).profile == profile
                      ? Icon(Icons.check_rounded, color: context.wayday.link)
                      : null,
                  onTap: () {
                    ref.read(todayProvider.notifier).setProfile(profile);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _planning() async {
    final saved = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const DayReviewView()));
    if (saved == true && mounted) {
      showFeedback(context, 'Reviewed day saved on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text('Today', style: context.type.headlineLarge),
        actions: [
          if (day.errands.isNotEmpty) ...[
            TextButton.icon(
              key: const Key('clear-errands'),
              onPressed: _clear,
              icon: const Icon(Icons.clear_all_rounded, size: 20),
              label: const Text('Clear'),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('trip-date'),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatFullDate(DateTime.parse(day.date)),
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(day.date),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null && mounted) {
                        ref.read(todayProvider.notifier).setDate(date);
                      }
                    },
                  ),
                ),
              ),
              SectionSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EndpointRow(
                      start: true,
                      value: day.from,
                      onTap: () => _place(true),
                    ),
                    const Divider(indent: 20, endIndent: 20),
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.format_list_bulleted_rounded,
                              size: 20,
                              color: context.wayday.link,
                            ),
                            const SizedBox(width: 14),
                            Text('Errands', style: context.type.titleMedium),
                            const SizedBox(width: 8),
                            Text(
                              '${day.errands.length}',
                              style: context.type.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 48,
                              width: 48,
                              child: AnimatedRotation(
                                turns: _expanded ? .5 : 0,
                                duration: WaydayMotion.duration(context),
                                curve: WaydayMotion.curve,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SmoothDisclosure(
                      key: const Key('today-errands-disclosure'),
                      expanded: _expanded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SmoothDisclosure(
                            expanded: day.errands.isEmpty,
                            child: SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  4,
                                ),
                                child: Text(
                                  'Start with one errand. Add details later.',
                                  key: const Key('today-empty-prompt'),
                                  textAlign: TextAlign.left,
                                  style: context.type.bodyMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          AnimatedErrandList(
                            items: day.errands
                                .take(_showAll ? day.errands.length : 5)
                                .toList(),
                            onEdit: _edit,
                          ),
                          SmoothDisclosure(
                            expanded: day.errands.length > 5,
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _showAll = !_showAll),
                              child: Text(
                                _showAll
                                    ? 'Show fewer'
                                    : 'Show all ${day.errands.length} errands',
                              ),
                            ),
                          ),
                          ErrandComposer(
                            key: const Key('today-composer'),
                            onAdd: (value) {
                              ref.read(todayProvider.notifier).add(value);
                              setState(() => _showAll = true);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(indent: 20, endIndent: 20),
                    EndpointRow(
                      start: false,
                      value: day.to,
                      onTap: () => _place(false),
                    ),
                    const Divider(),
                    TripSettings(
                      day: day,
                      onLeave: () => _time(true),
                      onDeadline: () => _time(false),
                      onTravel: _travel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go('/recurring'),
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  label: const Text('Add from a recurring list'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your lists stay on this device.',
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: day.errands.isEmpty ? null : _planning,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route_rounded, size: 20),
                      SizedBox(width: 10),
                      Flexible(child: Text('Plan my day')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EndpointRow extends StatelessWidget {
  const EndpointRow({
    required this.start,
    required this.value,
    required this.onTap,
    super.key,
  });
  final bool start;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          Icon(
            start ? Icons.trip_origin_rounded : Icons.location_on_outlined,
            size: 22,
            color: context.wayday.link,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  start ? 'From' : 'To',
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty
                      ? (start
                            ? 'Choose a starting point'
                            : 'Choose a destination')
                      : value,
                  style: context.type.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: Key(start ? 'from-map' : 'to-map'),
            onPressed: onTap,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Map'),
          ),
        ],
      ),
    ),
  );
}

class TripSettings extends StatelessWidget {
  const TripSettings({
    required this.day,
    required this.onLeave,
    required this.onDeadline,
    required this.onTravel,
    super.key,
  });
  final DayPlan day;
  final VoidCallback onLeave;
  final VoidCallback onDeadline;
  final VoidCallback onTravel;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.secondaryContainer.withValues(alpha: .45),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 17;
        final controls = [
          _TripProperty(
            label: 'Leave',
            value: formatMinute(day.departure),
            onTap: onLeave,
            stacked: stacked,
          ),
          _TripProperty(
            label: 'Home by',
            value: formatMinute(day.deadline),
            onTap: onDeadline,
            stacked: stacked,
          ),
          _TripProperty(
            label: 'Travel',
            value: day.profile.label,
            onTap: onTravel,
            stacked: stacked,
          ),
        ];
        return stacked
            ? Column(children: controls)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: controls
                    .map((control) => Expanded(child: control))
                    .toList(),
              );
      },
    ),
  );
}

class _TripProperty extends StatelessWidget {
  const _TripProperty({
    required this.label,
    required this.value,
    required this.onTap,
    required this.stacked,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool stacked;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: stacked
          ? Row(
              children: [
                Text(
                  label,
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Flexible(child: Text(value, style: context.type.labelLarge)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: context.type.labelLarge?.copyWith(
                    color: context.wayday.link,
                  ),
                ),
              ],
            ),
    ),
  );
}
