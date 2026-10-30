import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/place_picker.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/selection_controls.dart';
import '../../../core/widgets/time_entry_sheet.dart';
import '../domain/errand.dart';
import '../../places/domain/place_intent.dart';
import '../../places/domain/place_search.dart';
import '../../places/data/combined_place_search.dart';

sealed class ErrandEditResult {
  const ErrandEditResult();
}

class SavedErrand extends ErrandEditResult {
  const SavedErrand(this.errand);
  final Errand errand;
}

class RemovedErrand extends ErrandEditResult {
  const RemovedErrand();
}

Future<ErrandEditResult?> editErrand(
  BuildContext context,
  Errand errand, {
  List<Errand> errands = const [],
  bool allowRemoval = true,
}) => Navigator.of(context, rootNavigator: true).push<ErrandEditResult>(
  MaterialPageRoute(
    builder: (_) => ErrandEditor(
      errand: errand,
      errands: errands,
      allowRemoval: allowRemoval,
    ),
  ),
);

class ErrandEditor extends ConsumerStatefulWidget {
  const ErrandEditor({
    required this.errand,
    this.errands = const [],
    this.allowRemoval = true,
    super.key,
  });
  final Errand errand;
  final List<Errand> errands;
  final bool allowRemoval;
  @override
  ConsumerState<ErrandEditor> createState() => _ErrandEditorState();
}

class _ErrandEditorState extends ConsumerState<ErrandEditor>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.errand.title);
  late final _notes = TextEditingController(text: widget.errand.notes);
  late final _duration = TextEditingController(
    text: '${widget.errand.durationMinutes}',
  );
  late bool _durationConfirmed = widget.errand.durationConfirmed;
  late final _confirmed = {...widget.errand.confirmedFields};
  late String _place = widget.errand.place;
  late PlaceIntent _placeIntent = widget.errand.placeIntent;
  late TimingRule _timing = widget.errand.timing;
  late int? _minute = widget.errand.minute;
  late bool _optional = widget.errand.optional;
  late final Set<String> _after = {...widget.errand.afterErrandIds};
  final _whenFocus = FocusNode();
  final _detailsEnd = GlobalKey();
  Timer? _detailsScrollTimer;
  bool _detailsOpen = false;
  String? _durationError;
  String? _timeError;
  final _lookupOwner = Object();
  late final CombinedPlaceSearch _placeSearch;
  Timer? _lookupTimer;
  int _lookupRevision = 0;
  bool _finding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _placeSearch = ref.read(combinedPlaceSearchProvider);
  }

  void _cancelLookup() {
    _lookupRevision++;
    _lookupTimer?.cancel();
    _lookupTimer = null;
    _placeSearch.cancel(_lookupOwner, only: {'geoapify'});
    _finding = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      setState(_cancelLookup);
    }
  }

  void _resolvePin(PlaceIntent place) {
    final unnamedManual =
        place.source == 'manual' && place.label == 'Dropped pin';
    final unnamedDevice =
        place.source == 'device' && place.label == 'Current location';
    if ((!unnamedManual && !unnamedDevice) ||
        !place.hasCoordinates ||
        place.isGoogle) {
      return;
    }
    final revision = _lookupRevision;
    setState(() => _finding = true);
    _lookupTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && revision == _lookupRevision) setState(_cancelLookup);
    });
    _placeSearch.reverse(_lookupOwner, place.latitude!, place.longitude!, (
      _,
      status,
      results,
    ) {
      if (!mounted ||
          revision != _lookupRevision ||
          !identical(_placeIntent, place)) {
        return;
      }
      if (status.phase == SourcePhase.waiting ||
          status.phase == SourcePhase.loading) {
        return;
      }
      _lookupTimer?.cancel();
      setState(() {
        _finding = false;
        if (status.phase == SourcePhase.complete && results.isNotEmpty) {
          final result = results.first;
          _placeIntent = PlaceIntent(
            kind: PlaceKind.specific,
            label: result.name,
            latitude: place.latitude,
            longitude: place.longitude,
            source: place.source,
            provider: result.provider,
            retrievedAt: result.retrievedAt?.toIso8601String(),
            attributions: result.attributions,
          );
          _place = result.name;
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelLookup();
    _detailsScrollTimer?.cancel();
    _title.dispose();
    _notes.dispose();
    _duration.dispose();
    _whenFocus.dispose();
    super.dispose();
  }

  void _toggleDetails() {
    _detailsScrollTimer?.cancel();
    if (_detailsOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _detailsOpen = false);
      return;
    }
    final duration = WaydayMotion.duration(context);
    setState(() => _detailsOpen = true);
    _detailsScrollTimer = Timer(duration, () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _detailsEnd.currentContext;
        if (!mounted || !_detailsOpen || target == null || !target.mounted) {
          return;
        }
        Scrollable.ensureVisible(
          target,
          alignment: 1,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: duration,
          curve: WaydayMotion.curve,
        );
      });
    });
  }

  void _save() {
    final valid = _form.currentState?.validate() ?? false;
    final duration = int.tryParse(_duration.text);
    if (duration == null || duration < 1 || duration > 1440) {
      setState(() {
        _detailsOpen = true;
        _durationError = 'Enter between 1 and 1,440 minutes.';
      });
      return;
    }
    if (_timing != TimingRule.anytime && _minute == null) {
      setState(() => _timeError = 'Choose a time for this errand.');
      return;
    }
    if (!valid) return;
    Navigator.pop(
      context,
      SavedErrand(
        widget.errand.copyWith(
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          place: _place,
          placeIntent: _placeIntent,
          durationMinutes: int.parse(_duration.text),
          durationConfirmed: _durationConfirmed,
          confirmedFields: {
            ..._confirmed,
            if (_title.text.trim() != widget.errand.title) 'title',
            if (_notes.text.trim() != widget.errand.notes) 'notes',
            if (_timing != widget.errand.timing ||
                _minute != widget.errand.minute)
              'timing',
            if (_optional != widget.errand.optional) 'optional',
            if (!setEquals(_after, widget.errand.afterErrandIds.toSet()))
              'dependencies',
          },
          timing: _timing,
          minute: _minute,
          clearTime: _timing == TimingRule.anytime,
          optional: _optional,
          afterErrandIds: _after.toList(),
        ),
      ),
    );
  }

  bool _wouldCycle(Errand candidate) {
    final byId = {for (final item in widget.errands) item.id: item};
    final seen = <String>{};
    bool reaches(String id) {
      if (id == widget.errand.id) return true;
      if (!seen.add(id)) return false;
      return byId[id]?.afterErrandIds.any(reaches) ?? false;
    }

    return reaches(candidate.id);
  }

  Future<void> _chooseDependencies() async {
    final selected = {..._after};
    final candidates = widget.errands
        .where((e) => e.id != widget.errand.id)
        .toList();
    final known = candidates.map((e) => e.id).toSet();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('After another errand', style: context.type.titleLarge),
                const Text(
                  'Select one or more errands that must be completed before this one.',
                ),
                if (candidates.isEmpty && selected.isEmpty)
                  const Text('No other errands available.'),
                for (final item in candidates)
                  CheckboxListTile(
                    title: Text(item.title),
                    value: selected.contains(item.id),
                    subtitle: !selected.contains(item.id) && _wouldCycle(item)
                        ? const Text('Would create a circular dependency')
                        : null,
                    onChanged: !selected.contains(item.id) && _wouldCycle(item)
                        ? null
                        : (value) => update(() {
                            if (value == true) {
                              selected.add(item.id);
                            } else {
                              selected.remove(item.id);
                            }
                          }),
                  ),
                for (final id
                    in selected.where((id) => !known.contains(id)).toList())
                  CheckboxListTile(
                    title: const Text('Errand no longer available'),
                    subtitle: const Text(
                      'Remove this dependency to correct it.',
                    ),
                    value: true,
                    onChanged: (_) => update(() => selected.remove(id)),
                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _after
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit errand'),
      actions: [
        TextButton(
          onPressed: _finding ? null : _save,
          child: const Text('Save'),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _form,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) {
                _detailsScrollTimer?.cancel();
              }
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  key: const Key('errand-title'),
                  controller: _title,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.type.titleLarge,
                  decoration: const InputDecoration(
                    labelText: 'What do you need to do?',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Give this errand a name.'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('errand-notes'),
                  controller: _notes,
                  minLines: 4,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                    hintText:
                        'Vegetables, fruits, meat…\nOr anything to remember at this stop.',
                  ),
                ),
                const SizedBox(height: 28),
                Text('Where', style: context.type.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: context.wayday.link,
                  ),
                  title: Text(_place.isEmpty ? 'Choose a place' : _place),
                  subtitle: Text(_finding ? 'Finding address…' : 'Open map'),
                  trailing: Icon(
                    Icons.map_outlined,
                    color: context.wayday.link,
                  ),
                  onTap: () async {
                    setState(() {
                      _cancelLookup();
                    });
                    final place = await choosePlace(
                      context,
                      title: 'Errand location',
                      initial: _place,
                      initialPlace: _placeIntent,
                    );
                    if (!mounted) return;
                    if (place != null) {
                      setState(() {
                        _place = place.label;
                        _placeIntent = place;
                        _confirmed.add('place');
                      });
                      _resolvePin(place);
                    }
                  },
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  focusNode: _whenFocus,
                  title: const Text('When'),
                  subtitle: Text(
                    _timing == TimingRule.anytime
                        ? 'Anytime'
                        : '${_timing.label}${_minute == null ? ' · Choose a time' : ' · ${formatMinute(_minute!)}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final choice = await chooseSingleChoice<TimingRule>(
                      context,
                      title: 'When',
                      options: [
                        for (final rule in TimingRule.values)
                          SelectionOption(value: rule, label: rule.label),
                      ],
                      selectedValue: _timing,
                      returnFocusNode: _whenFocus,
                    );
                    if (!context.mounted || choice == null) return;
                    if (choice == TimingRule.anytime) {
                      setState(() {
                        _timing = choice;
                        _timeError = null;
                      });
                      return;
                    }
                    final time = await chooseTime(
                      context,
                      title: choice.label,
                      initialMinute: _minute ?? 540,
                    );
                    if (mounted && time != null) {
                      setState(() {
                        _timing = choice;
                        _minute = time;
                        _timeError = null;
                      });
                    }
                  },
                ),
                if (_timing != TimingRule.anytime)
                  ListTile(
                    key: const Key('errand-time'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _minute == null
                          ? 'Choose a time'
                          : formatMinute(_minute!),
                    ),
                    trailing: const Icon(Icons.schedule_rounded),
                    onTap: () async {
                      final time = await chooseTime(
                        context,
                        title: _timing.label,
                        initialMinute: _minute ?? 540,
                      );
                      if (mounted && time != null) {
                        setState(() {
                          _minute = time;
                          _timeError = null;
                        });
                      }
                    },
                  ),
                if (_timeError != null)
                  Text(
                    _timeError!,
                    style: context.type.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                const SizedBox(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('If there’s time'),
                  subtitle: const Text(
                    'This errand can wait if the day is full.',
                  ),
                  value: _optional,
                  onChanged: (value) => setState(() => _optional = value),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      expanded: _detailsOpen,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('More details'),
                        subtitle: Text(
                          '${_duration.text} min${_durationConfirmed ? '' : ' estimated'}${_after.isEmpty ? '' : ' · ${_after.length} prerequisite${_after.length == 1 ? '' : 's'}'}${_after.any((id) => !widget.errands.any((e) => e.id == id && e.id != widget.errand.id)) ? ' · Errand no longer available' : ''}',
                        ),
                        trailing: AnimatedRotation(
                          key: const Key('errand-details-arrow'),
                          turns: _detailsOpen ? .5 : 0,
                          duration: WaydayMotion.duration(
                            context,
                            closing: !_detailsOpen,
                          ),
                          curve: WaydayMotion.curve,
                          child: const Icon(Icons.expand_more_rounded),
                        ),
                        onTap: _toggleDetails,
                      ),
                    ),
                    SmoothDisclosure(
                      expanded: _detailsOpen,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const Key('errand-duration'),
                              controller: _duration,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Visit duration',
                                errorText: _durationError,
                                suffixText: 'minutes',
                                helperText: _durationConfirmed
                                    ? 'Your estimate for this visit.'
                                    : '15 minutes assumed · adjust for this visit.',
                              ),
                              onChanged: (_) => setState(() {
                                _durationError = null;
                                _durationConfirmed = true;
                                _confirmed.add('duration');
                              }),
                              validator: (value) {
                                final minutes = int.tryParse(value ?? '');
                                return minutes == null ||
                                        minutes < 1 ||
                                        minutes > 1440
                                    ? 'Enter between 1 and 1,440 minutes.'
                                    : null;
                              },
                            ),
                            ListTile(
                              key: _detailsEnd,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('After another errand'),
                              subtitle: Text(
                                _after.isEmpty
                                    ? 'None'
                                    : _after
                                          .map((id) {
                                            for (final item in widget.errands) {
                                              if (item.id == id &&
                                                  item.id != widget.errand.id) {
                                                return item.title;
                                              }
                                            }
                                            return 'Errand no longer available';
                                          })
                                          .join(', '),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _chooseDependencies,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.allowRemoval) const SizedBox(height: 32),
                if (widget.allowRemoval)
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, const RemovedErrand()),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove errand'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
