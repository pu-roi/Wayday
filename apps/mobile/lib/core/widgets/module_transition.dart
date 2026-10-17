import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';

/// A short fade-through keeps global navigation calm and the shell stationary.
/// Reduced motion removes both the movement and the transition wait.
Page<void> modulePage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<void>(
  key: state.pageKey,
  transitionDuration: WaydayMotion.duration(context),
  reverseTransitionDuration: WaydayMotion.duration(context, closing: true),
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final arrival = animation.drive(
      CurveTween(curve: const Interval(.15, 1, curve: Curves.easeOutCubic)),
    );
    return FadeTransition(
      key: const Key('module-transition'),
      opacity: arrival,
      child: SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(.025, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: WaydayMotion.curve)),
        ),
        child: child,
      ),
    );
  },
);
