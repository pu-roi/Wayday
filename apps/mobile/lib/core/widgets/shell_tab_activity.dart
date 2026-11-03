import 'package:flutter/widgets.dart';

/// A mounted tab can be hidden while retaining its page and platform views.
class ShellTabActivity extends InheritedWidget {
  const ShellTabActivity({
    required this.active,
    required super.child,
    super.key,
  });
  final bool active;

  static bool isActiveOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellTabActivity>()?.active ??
      true;

  @override
  bool updateShouldNotify(ShellTabActivity oldWidget) =>
      active != oldWidget.active;
}
