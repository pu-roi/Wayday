import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/motion.dart';
import '../domain/errand.dart';

class AnimatedErrandList extends StatefulWidget {
  const AnimatedErrandList({
    required this.items,
    required this.onEdit,
    super.key,
  });
  final List<Errand> items;
  final ValueChanged<Errand> onEdit;

  @override
  State<AnimatedErrandList> createState() => _AnimatedErrandListState();
}

class _AnimatedErrandListState extends State<AnimatedErrandList> {
  final _list = GlobalKey<AnimatedListState>();
  late final List<Errand> _items = [...widget.items];

  @override
  void didUpdateWidget(covariant AnimatedErrandList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.items.map((item) => item.id).toSet();
    for (var index = _items.length - 1; index >= 0; index--) {
      if (!ids.contains(_items[index].id)) _remove(index);
    }
    for (var index = 0; index < widget.items.length; index++) {
      final next = widget.items[index];
      if (index < _items.length && _items[index].id == next.id) {
        _items[index] = next;
        continue;
      }
      final moved = _items.indexWhere((item) => item.id == next.id);
      if (moved != -1) _remove(moved);
      _items.insert(index, next);
      _list.currentState!.insertItem(
        index,
        duration: WaydayMotion.duration(context),
      );
    }
  }

  void _remove(int index) {
    final removed = _items.removeAt(index);
    _list.currentState!.removeItem(
      index,
      (context, animation) => ExcludeSemantics(
        child: IgnorePointer(
          child: _transition(
            animation,
            ErrandRow(index: index + 1, errand: removed, onTap: () {}),
          ),
        ),
      ),
      duration: WaydayMotion.duration(context, closing: true),
    );
  }

  Widget _transition(Animation<double> animation, Widget child) {
    final progress = animation.drive(CurveTween(curve: WaydayMotion.curve));
    return SizeTransition(
      sizeFactor: progress,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: progress, child: child),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedList(
    key: _list,
    initialItemCount: _items.length,
    shrinkWrap: true,
    primary: false,
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    itemBuilder: (context, index, animation) {
      final item = _items[index];
      return _transition(
        animation,
        ErrandRow(
          key: ValueKey(item.id),
          index: index + 1,
          errand: item,
          onTap: () => widget.onEdit(item),
        ),
      );
    },
  );
}

class ErrandRow extends StatelessWidget {
  const ErrandRow({
    required this.index,
    required this.errand,
    required this.onTap,
    super.key,
  });
  final int index;
  final Errand errand;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final detail = errand.timing == TimingRule.anytime
        ? (errand.optional ? 'If there’s time' : 'Anytime')
        : '${errand.timing == TimingRule.at ? 'At' : errand.timing.label} ${formatMinute(errand.minute ?? 0)}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: context.type.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.wayday.link,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errand.title,
                    style: context.type.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (errand.notes.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Semantics(
                label: 'Has notes',
                child: Icon(
                  Icons.notes_rounded,
                  size: 16,
                  color: context.wayday.link,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class ErrandComposer extends StatefulWidget {
  const ErrandComposer({required this.onAdd, super.key});
  final ValueChanged<String> onAdd;
  @override
  State<ErrandComposer> createState() => _ErrandComposerState();
}

class _ErrandComposerState extends State<ErrandComposer>
    with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _field = GlobalKey();
  late final AnimationController _follow;
  bool _open = false;
  bool _scrollPending = false;

  @override
  void initState() {
    super.initState();
    _follow = AnimationController(vsync: this)..addListener(_keepVisible);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _follow.dispose();
    super.dispose();
  }

  void _save() {
    if (_text.text.trim().isEmpty) return;
    widget.onAdd(_text.text.trim());
    _text.clear();
    _focus.requestFocus();
    _follow.duration = WaydayMotion.duration(context);
    _follow.forward(from: 0);
    _keepVisible();
  }

  void _keepVisible() {
    if (_scrollPending) return;
    _scrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollPending = false;
      final fieldContext = _field.currentContext;
      if (!mounted || !_open || !_focus.hasFocus || fieldContext == null) {
        return;
      }
      // Follow the row's size animation instead of jumping after it finishes.
      Scrollable.ensureVisible(
        fieldContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SmoothDisclosure(
        expanded: !_open,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() => _open = true);
                // Wait until disclosure has enabled this field's focus scope.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_open) return;
                  _focus.requestFocus();
                  _follow.duration = WaydayMotion.duration(context);
                  _follow.forward(from: 0);
                  _keepVisible();
                });
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add errand'),
            ),
          ),
        ),
      ),
      SmoothDisclosure(
        expanded: _open,
        child: Padding(
          key: _field,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                key: const Key('quick-add'),
                controller: _text,
                focusNode: _focus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onEditingComplete: () {},
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'What do you need to do?',
                  hintText: 'e.g. Pick up laundry',
                  suffixIcon: IconButton(
                    tooltip: 'Add errand to list',
                    onPressed: _save,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _text.clear();
                    _focus.unfocus();
                    setState(() => _open = false);
                  },
                  child: const Text('Done adding'),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
