import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../today/domain/day.dart';
import '../domain/clarification.dart';
import '../domain/errand_location_review.dart';
import 'planning_controller.dart';

Future<String?> showClarificationSheet(
  BuildContext context,
  PlanningController model,
  Errand errand, {
  bool deferOnly = false,
}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) =>
      ClarificationSheet(model: model, errand: errand, deferOnly: deferOnly),
);

class ClarificationSheet extends StatefulWidget {
  const ClarificationSheet({
    required this.model,
    required this.errand,
    this.deferOnly = false,
    super.key,
  });
  final PlanningController model;
  final Errand errand;
  final bool deferOnly;
  @override
  State<ClarificationSheet> createState() => _ClarificationSheetState();
}

class _ClarificationSheetState extends State<ClarificationSheet> {
  late final ClarificationContext question = widget.model.questionContext(
    widget.errand,
  );
  late final answer = TextEditingController(
    text:
        widget.model.clarifications.draftFor(question) ?? record?.answer ?? '',
  );
  final focus = FocusNode();
  bool submitting = false, watchingOutcome = false, closing = false;
  late bool preview = widget.deferOnly;
  String? localError;
  ClarificationRecord? get record =>
      widget.model.clarifications.record(question);
  void finishIfReady() {
    if (!mounted ||
        closing ||
        !watchingOutcome ||
        record?.applied != true ||
        widget.model.clarifications.storageError != null) {
      return;
    }
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void changed() {
    if (mounted) {
      setState(() {});
      finishIfReady();
    }
  }

  @override
  void initState() {
    super.initState();
    watchingOutcome =
        record?.status == 'processing' ||
        widget.model.clarifications.isRunning(question);
    widget.model.clarifications.addListener(changed);
    if (record?.status == 'processing' &&
        !widget.model.clarifications.isRunning(question)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.model.clarifications.submit(
            question,
            record!.answer,
            savedOnly: true,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    widget.model.clarifications.removeListener(changed);
    answer.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> submit({bool retry = false, bool savedOnly = false}) async {
    if (answer.text.trim().isEmpty) {
      focus.requestFocus();
      return;
    }
    setState(() {
      submitting = true;
      watchingOutcome = true;
      localError = null;
    });
    focus.unfocus();
    await widget.model.clarifications.submit(
      question,
      answer.text,
      retry: retry,
      savedOnly: savedOnly,
    );
    if (!mounted) return;
    setState(() => submitting = false);
    finishIfReady();
    if (record?.applied != true) watchingOutcome = false;
  }

  Future<void> chooseFlexibility() async {
    watchingOutcome = false;
    final need = widget.model.effectiveNeed(widget.errand)!;
    if (need.questionKind == 'preference' && need.questionRequired == false) {
      try {
        await widget.model.clarifications.applyStructured(
          question,
          ClarificationResolution(
            outcome: 'flexible',
            kind: 'preference',
            summary: need.category == 'grocery'
                ? 'General groceries · Choose items at the store'
                : 'Open to suitable places',
            query: need.query.isEmpty ? null : need.query,
            items: need.items,
          ),
          'Let Wayday recommend',
        );
        if (mounted) Navigator.pop(context);
      } catch (_) {}
    } else {
      answer.text = 'Let Wayday recommend. I’ll decide when I get there.';
      await widget.model.clarifications.saveDraft(question, answer.text);
    }
  }

  Future<void> defer() async {
    watchingOutcome = false;
    try {
      final affected = widget.model.clarifications.affectedByDeferral(
        widget.errand.id,
        widget.model.reviewOrder.items,
      );
      await widget.model.clarifications.defer(
        widget.model.day.date,
        affected,
        needsActualLocation(
              widget.errand,
              widget.model.effectiveNeed(widget.errand),
            )
            ? 'Actual location not confirmed.'
            : record?.status == 'unresolved'
            ? record!.resolution!.summary
            : 'Left out while you plan the other errands.',
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => localError = 'This choice could not be saved. Try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = widget.model.clarifications;
    final r = record, busy = submitting || coordinator.isRunning(question);
    final missing = needsActualLocation(
      widget.errand,
      widget.model.effectiveNeed(widget.errand),
    );
    final affected = coordinator.affectedByDeferral(
      widget.errand.id,
      widget.model.reviewOrder.items,
    );
    final error =
        localError ??
        coordinator.storageError ??
        coordinator.errors[question.key];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(
              100,
              MediaQuery.sizeOf(context).height * .86 -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.errand.title,
                        style: context.type.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close answer',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!preview)
                  Text(
                    r?.resolution?.followUp ??
                        (question.question.isEmpty
                            ? 'Where will this errand happen?'
                            : question.question),
                    style: context.type.bodyLarge,
                  ),
                const SizedBox(height: 16),
                if (!preview) ...[
                  TextField(
                    controller: answer,
                    focusNode: focus,
                    enabled: !busy,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 8000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Your answer',
                      hintText: 'English, Filipino or Taglish',
                      counterText: '',
                    ),
                    onChanged: (text) {
                      setState(() {});
                      coordinator.saveDraft(question, text);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (!missing && !busy)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: chooseFlexibility,
                        child: const Text('Let Wayday recommend'),
                      ),
                    ),
                  if (busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                'Understanding your answer…',
                                style: context.type.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(error, style: context.type.bodyMedium),
                      ),
                    ),
                  if (coordinator.storageError != null)
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await coordinator.retrySave();
                          if (context.mounted && record?.applied == true) {
                            watchingOutcome = true;
                            finishIfReady();
                          }
                        } catch (_) {}
                      },
                      child: const Text('Retry saving answer'),
                    ),
                  if ({'failed', 'processing'}.contains(r?.status) &&
                      !busy &&
                      answer.text.trim() == r!.answer.trim()) ...[
                    OutlinedButton(
                      onPressed: () => submit(savedOnly: true),
                      child: const Text('Check saved answer'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => submit(retry: true),
                      child: const Text('Retry understanding answer'),
                    ),
                  ] else
                    FilledButton(
                      onPressed:
                          busy ||
                              coordinator.storageError != null ||
                              (r?.status == 'unresolved' &&
                                  answer.text.trim() == r!.answer.trim()) ||
                              answer.text.trim().isEmpty
                          ? null
                          : submit,
                      child: const Text('Use answer'),
                    ),
                  if ((r?.resolution?.kind ??
                          widget.model
                              .effectiveNeed(widget.errand)
                              ?.questionKind) ==
                      'timing') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => Navigator.pop(context, 'time'),
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text('Choose a time'),
                    ),
                  ],
                  if (missing) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => Navigator.pop(context, 'location'),
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Choose actual location'),
                    ),
                  ],
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => preview = true),
                    child: const Text('Plan the other errands'),
                  ),
                ] else ...[
                  Text(
                    'Leave out of this plan',
                    style: context.type.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'These errands stay in Today. You can include them again in review.',
                  ),
                  const SizedBox(height: 12),
                  for (final e in affected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        e.id == widget.errand.id
                            ? e.title
                            : '${e.title} · Depends on an errand being left out',
                      ),
                    ),
                  if (widget.model.activeErrands.every(
                    (e) => affected.any((x) => x.id == e.id),
                  ))
                    const Text(
                      'Include at least one errand before continuing.',
                    ),
                  const SizedBox(height: 16),
                  if (localError != null) Text(localError!),
                  FilledButton(
                    onPressed: defer,
                    child: const Text('Leave out of this plan'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (widget.deferOnly) {
                        Navigator.pop(context);
                      } else {
                        setState(() => preview = false);
                      }
                    },
                    child: const Text('Keep these errands'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
