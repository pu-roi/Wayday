import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../../today/domain/day.dart';
import '../data/reusable_trip_repository.dart';
import '../domain/trip_departure.dart';
import 'planning_view.dart';

class TripNameDialog extends StatefulWidget {
  const TripNameDialog({super.key});
  @override
  State<TripNameDialog> createState() => _TripNameDialogState();
}

class _TripNameDialogState extends State<TripNameDialog> {
  final name = TextEditingController();
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save for reuse'),
    content: TextField(
      controller: name,
      autofocus: true,
      maxLength: 80,
      decoration: InputDecoration(
        labelText: 'Trip name',
        helperText: 'Included errands and chosen places are saved.',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          if (name.text.trim().isEmpty) {
            setState(() => error = 'Enter a name');
          } else {
            Navigator.pop(context, name.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class SavedTripsSection extends ConsumerWidget {
  const SavedTripsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ref
          .watch(reusableTripsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(reusableTripsProvider),
              child: const Text('Saved trips could not load. Retry'),
            ),
            data: (trips) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (trips.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No saved trips yet.',
                        style: context.type.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save a plan from Your plan to reuse its errands and chosen places.',
                        style: context.type.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                for (final trip in trips)
                  ExpansionTile(
                    key: PageStorageKey('saved-trip-${trip.id}'),
                    maintainState: true,
                    tilePadding: EdgeInsets.zero,
                    title: Text(trip.name, style: context.type.titleMedium),
                    subtitle: Text(
                      '${trip.day.errands.length} errands · ${trip.day.profile.label}',
                      style: context.type.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      for (final e in trip.day.errands)
                        ListTile(
                          dense: true,
                          title: Text(e.title),
                          subtitle: Text(trip.choices[e.id]!.label),
                        ),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              final run =
                                  await showModalBottomSheet<ReusableTrip>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) => ReuseTripSheet(trip: trip),
                                  );
                              if (run != null && context.mounted) {
                                await Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PlanningView(reusable: run),
                                  ),
                                );
                              }
                            },
                            child: const Text('Use trip'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final remove = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete saved trip?'),
                                  content: Text(trip.name),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (remove != true) return;
                              try {
                                await ref
                                    .read(reusableTripRepositoryProvider)
                                    .delete(trip.id);
                                ref.invalidate(reusableTripsProvider);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'The saved trip could not be deleted.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
    ],
  );
}

class ReuseTripSheet extends StatefulWidget {
  const ReuseTripSheet({required this.trip, super.key});
  final ReusableTrip trip;
  @override
  State<ReuseTripSheet> createState() => _ReuseTripSheetState();
}

class _ReuseTripSheetState extends State<ReuseTripSheet> {
  DateTime date = DateTime.now();
  late int departure = widget.trip.day.departure,
      deadline = widget.trip.day.deadline;
  String? error;
  Future<void> time(bool start) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TimeEntrySheet(
        title: start ? 'Departure' : 'Finish the day by',
        initialMinute: start ? departure : deadline,
      ),
    );
    if (value != null && mounted) {
      setState(() {
        if (start) {
          departure = value;
        } else {
          deadline = value;
        }
        error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.trip.name, style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Keep your chosen places. Refresh the route and schedule without Gemini.',
          ),
          ListTile(
            title: const Text('Date'),
            subtitle: Text(calendarDate(date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 2, 12, 31),
              );
              if (selected != null && mounted) {
                setState(() {
                  date = selected;
                  error = null;
                });
              }
            },
          ),
          ListTile(
            title: const Text('Departure'),
            subtitle: Text(formatMinute(departure)),
            onTap: () => time(true),
          ),
          ListTile(
            title: const Text('Finish the day by'),
            subtitle: Text(formatMinute(deadline)),
            onTap: () => time(false),
          ),
          if (widget.trip.day.errands.any(
            (e) => e.timing != TimingRule.anytime,
          ))
            const Text(
              'Saved appointment times stay unchanged. Review them for this date.',
            ),
          if (error != null) Text(error!),
          FilledButton(
            onPressed: () {
              final run = widget.trip.copyForRun(
                date: calendarDate(date),
                departure: departure,
                deadline: deadline,
              );
              if (departure >= deadline || tripDepartureHasPassed(run.day)) {
                setState(
                  () => error =
                      'Choose a future departure and a later finish time.',
                );
                return;
              }
              Navigator.pop(context, run);
            },
            child: const Text('Review trip'),
          ),
        ],
      ),
    ),
  );
}
