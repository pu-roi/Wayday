import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'motion.dart';

@immutable
class SelectionOption<T> {
  const SelectionOption({required this.value, required this.label});

  final T value;
  final String label;
}

class SelectionRadioGroup<T> extends StatelessWidget {
  const SelectionRadioGroup({
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    super.key,
  });

  final String label;
  final List<SelectionOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(label, style: context.type.titleMedium),
      ),
      const SizedBox(height: 8),
      _SelectionRows<T>(
        options: options,
        selectedValue: selectedValue,
        onChanged: onChanged,
      ),
    ],
  );
}

class _SelectionRows<T> extends StatelessWidget {
  const _SelectionRows({
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<SelectionOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => RadioGroup<T>(
    groupValue: selectedValue,
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
    child: Column(
      children: [
        for (final option in options)
          RadioListTile<T>(
            value: option.value,
            title: Text(option.label),
            selected: option.value == selectedValue,
            activeColor: context.colors.secondary,
            selectedTileColor: context.colors.secondaryContainer,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            minTileHeight: 48,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
      ],
    ),
  );
}

Future<T?> chooseSingleChoice<T>(
  BuildContext context, {
  required String title,
  required List<SelectionOption<T>> options,
  required T selectedValue,
  required FocusNode returnFocusNode,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final result = await showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    requestFocus: true,
    sheetAnimationStyle: AnimationStyle(
      duration: WaydayMotion.duration(context),
      reverseDuration: WaydayMotion.duration(context, closing: true),
    ),
    builder: (_) => _SingleChoiceSheet<T>(
      title: title,
      options: options,
      selectedValue: selectedValue,
    ),
  );
  if (context.mounted &&
      returnFocusNode.context != null &&
      returnFocusNode.canRequestFocus) {
    returnFocusNode.requestFocus();
  }
  return result;
}

class _SingleChoiceSheet<T> extends StatefulWidget {
  const _SingleChoiceSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<SelectionOption<T>> options;
  final T selectedValue;

  @override
  State<_SingleChoiceSheet<T>> createState() => _SingleChoiceSheetState<T>();
}

class _SingleChoiceSheetState<T> extends State<_SingleChoiceSheet<T>> {
  late T _selected = widget.selectedValue;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(widget.title, style: context.type.titleLarge),
          ),
          const SizedBox(height: 16),
          _SelectionRows<T>(
            options: widget.options,
            selectedValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
