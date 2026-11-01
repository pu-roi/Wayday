import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Question state has its own visual meaning; the pencil remains errand editing.
class ReviewQuestionState extends StatelessWidget {
  const ReviewQuestionState({
    required this.question,
    required this.optional,
    required this.onTap,
    this.summary,
    this.busy = false,
    this.awaitingApproval = false,
    super.key,
  });
  final String? question, summary;
  final bool optional, busy, awaitingApproval;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final answered = summary != null && question == null && !awaitingApproval;
    final attention = !answered && !optional;
    return Semantics(
      liveRegion: busy,
      child: TextButton.icon(
        // Reopening may attach to the same pending answer. The sheet and
        // coordinator prevent another submission while that work is running.
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: attention
              ? context.wayday.attention
              : context.colors.secondary,
          alignment: Alignment.centerLeft,
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                answered
                    ? Icons.check_circle_outline
                    : Icons.chat_bubble_outline,
                size: 20,
              ),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (busy) const Text('Answer is processing…'),
            ...[
              if (!answered && !optional)
                Text(
                  awaitingApproval
                      ? 'Review suggested rules'
                      : 'Needs your answer',
                  style: context.type.labelMedium,
                ),
              Text(
                optional && question != null ? 'Optional: $question' : question ?? summary ?? '',
                textAlign: TextAlign.start,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
