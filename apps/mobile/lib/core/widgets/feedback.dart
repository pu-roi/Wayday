import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'motion.dart';

void showFeedback(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
  bool advisory = false,
  ScaffoldMessengerState? messenger,
}) {
  final host = messenger ?? ScaffoldMessenger.of(context);
  // Replace stale feedback instead of building a queue of old confirmations.
  host.removeCurrentSnackBar();
  host.showSnackBar(
    SnackBar(
      duration: Duration(seconds: onUndo == null ? 4 : 6),
      persist: onUndo != null && MediaQuery.accessibleNavigationOf(context),
      content: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              advisory
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: context.colors.onSecondaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      action: onUndo == null
          ? null
          : SnackBarAction(label: 'Undo', onPressed: onUndo),
    ),
    snackBarAnimationStyle: AnimationStyle(
      duration: WaydayMotion.duration(context),
      reverseDuration: WaydayMotion.duration(context, closing: true),
    ),
  );
}
