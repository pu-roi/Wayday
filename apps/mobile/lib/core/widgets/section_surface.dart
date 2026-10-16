import 'package:flutter/material.dart';
import '../../app/theme.dart';

class SectionSurface extends StatelessWidget {
  const SectionSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: context.colors.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
