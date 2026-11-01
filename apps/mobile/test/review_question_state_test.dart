import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/presentation/review_question_state.dart';

void main() {
  testWidgets(
    'required questions differ from editing and only saved answers look complete',
    (tester) async {
      Widget page({
        bool saved = false,
        bool optional = false,
        bool busy = false,
      }) => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ReviewQuestionState(
            question: saved ? null : 'Anong lugar ang napagkasunduan ninyo?',
            optional: optional,
            summary: saved ? 'Confirmed preference' : null,
            busy: busy,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpWidget(page());
      expect(find.text('Needs your answer'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await tester.pumpWidget(page(saved: true));
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Needs your answer'), findsNothing);
      await tester.pumpWidget(page(optional: true));
      expect(find.textContaining('Optional:'), findsOneWidget);
      expect(find.text('Needs your answer'), findsNothing);
      await tester.pumpWidget(page(busy: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull,
      );
    },
  );
}
