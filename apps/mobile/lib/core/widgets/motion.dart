import 'package:flutter/material.dart';

abstract final class WaydayMotion {
  static const enter = Duration(milliseconds: 260);
  static const exit = Duration(milliseconds: 180);
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, {bool closing = false}) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : closing
      ? exit
      : enter;
}

/// Reveals related content without replacing its state or keyboard focus.
class SmoothDisclosure extends StatefulWidget {
  const SmoothDisclosure({
    required this.expanded,
    required this.child,
    super.key,
  });
  final bool expanded;
  final Widget child;

  @override
  State<SmoothDisclosure> createState() => _SmoothDisclosureState();
}

class _SmoothDisclosureState extends State<SmoothDisclosure>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.expanded ? 1 : 0,
  );
  late final _progress = CurvedAnimation(
    parent: _controller,
    curve: WaydayMotion.curve,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = WaydayMotion.duration(context);
    _controller.reverseDuration = WaydayMotion.duration(context, closing: true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.expanded ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant SmoothDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, child) => Offstage(
      offstage: _controller.isDismissed,
      child: SizeTransition(
        sizeFactor: _progress,
        alignment: Alignment.topCenter,
        child: child,
      ),
    ),
    child: ExcludeFocus(
      excluding: !widget.expanded,
      child: ExcludeSemantics(
        excluding: !widget.expanded,
        child: TickerMode(enabled: widget.expanded, child: widget.child),
      ),
    ),
  );
}
