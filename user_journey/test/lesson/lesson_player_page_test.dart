import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/core/markup/markup_parser.dart';
import 'package:user_journey/core/theme/tokens.dart';
import 'package:user_journey/features/lesson/domain/lesson.dart';
import 'package:user_journey/features/lesson/presentation/bloc/lesson_player_bloc.dart';
import 'package:user_journey/features/lesson/presentation/pages/lesson_player_page.dart';
import 'package:user_journey/features/lesson/presentation/widgets/block_view.dart';

import '../helpers/harness.dart';
import 'lesson_fixtures.dart';
import 'lesson_player_bloc_test.dart' show MockLessonRepository;

/// Finds text inside RichText (MarkupText renders Text.rich).
Finder richText(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
  description: 'RichText containing "$text"',
);

Future<MockLessonRepository> pumpLesson(WidgetTester tester, {Lesson? lessonOverride}) async {
  usePhoneScreen(tester);
  final repo = MockLessonRepository();
  when(() => repo.getLesson(any())).thenAnswer((_) async => lessonOverride ?? sampleLesson());
  when(() => repo.startAttempt(any())).thenAnswer((_) async => 'attempt-1');
  when(() => repo.abandon(any())).thenAnswer((_) async {});
  await pumpScreen(
    tester,
    const SizedBox(),
    initialLocation: '/player',
    extraRoutes: {
      '/player': BlocProvider(
        create: (_) => LessonPlayerBloc(lessonId: 'lesson-1', repository: repo)..add(const LessonStarted()),
        child: const LessonPlayerView(),
      ),
    },
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> tapCta(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('lesson-cta')));
  await tester.pumpAndSettle();
}

void main() {
  group('blocks', () {
    testWidgets('every block type renders, with markup, interpolation and highlight', (tester) async {
      await pumpLesson(tester);
      expect(find.text("THAT'S IMPRACTICAL!"), findsOneWidget);
      expect(richText("It's going to be different this time!"), findsOneWidget);
      expect(richText('Hello Yash!'), findsOneWidget); // {{user.name}} from bootstrap
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('•'), findsWidgets);
      expect(richText("We're a team of psychologists"), findsOneWidget);
      expect(find.text('ZONE-1'), findsOneWidget);
      expect(find.byKey(const ValueKey('img-/static/assets/lesson_dominoes.png')), findsNWidgets(3));

      // highlight style
      final highlighted = <TextSpan>[];
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        rt.text.visitChildren((span) {
          if (span is TextSpan && span.text != null && span.style?.backgroundColor == AppColors.highlight) {
            highlighted.add(span);
          }
          return true;
        });
      }
      expect(highlighted.single.text, 'Only to give up after 2 to 3 weeks!');
      expect(highlighted.single.style!.color, AppColors.highlightText);

      // accordion expands on tap
      expect(richText('Cucumber'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('accordion-b-acc')));
      await tester.tap(find.byKey(const ValueKey('accordion-b-acc')));
      await tester.pumpAndSettle();
      expect(richText('Cucumber'), findsOneWidget);
    });

    testWidgets('BlockView renders malformed markup as plain text', (tester) async {
      useFakeImages();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlockView(block: ParagraphBlock('x', '**unbalanced'), resolver: TokenResolver()),
          ),
        ),
      );
      expect(richText('**unbalanced'), findsOneWidget);
    });
  });

  group('questions and feedback', () {
    testWidgets('progress bar and counter follow the page index', (tester) async {
      await pumpLesson(tester);
      LinearProgressIndicator bar() => tester.widget(find.byKey(const ValueKey('lesson-progress')));
      expect(bar().value, closeTo(1 / 5, 0.001));
      String hp() => tester.widget<Text>(find.byKey(const ValueKey('lesson-hp'))).data!;
      expect(hp(), '0');
      await tapCta(tester);
      expect(bar().value, closeTo(2 / 5, 0.001));
      expect(hp(), '1');
    });

    testWidgets('single choice: validation toast, wrong answer → feedback card → Back keeps selection', (tester) async {
      final repo = await pumpLesson(tester);
      when(
        () => repo.submitChoice(any(), 'p1', any()),
      ).thenAnswer((_) async => const AnswerResult(pageId: 'p1', isCorrect: false, feedback: wrongFeedback));
      await tapCta(tester); // → p1
      await tapCta(tester); // nothing selected
      expect(find.text('Please choose an answer to continue.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('option-o-a')));
      await tester.pump();
      await tapCta(tester);
      expect(find.byKey(const ValueKey('feedback-card')), findsOneWidget);
      expect(find.text('Not quite, but I appreciate your effort.'), findsOneWidget);
      expect(richText("It's - The number of calories in a food per gram of its weight"), findsOneWidget);
      expect(richText('(Remember, water has 0 calories)'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget); // CTA keeps the page's label

      await tester.tap(find.byKey(const ValueKey('lesson-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feedback-card')), findsNothing);
      final selected = tester.widget<Semantics>(
        find.ancestor(of: find.byKey(const ValueKey('option-o-a')), matching: find.byType(Semantics)).first,
      );
      expect(selected.properties.selected, isTrue);
    });

    testWidgets('multiple choice renders checkboxes; ungraded answer advances directly', (tester) async {
      final repo = await pumpLesson(tester);
      when(
        () => repo.submitChoice(any(), any(), any()),
      ).thenAnswer((_) async => const AnswerResult(pageId: 'p1', isCorrect: true, feedback: wrongFeedback));
      await tapCta(tester);
      await tester.tap(find.byKey(const ValueKey('option-o-b')));
      await tester.pump();
      await tapCta(tester);
      await tapCta(tester); // feedback → p2
      when(() => repo.submitChoice(any(), 'p2', any())).thenAnswer((_) async => const AnswerResult(pageId: 'p2'));
      await tester.tap(find.byKey(const ValueKey('option-m-1')));
      await tester.tap(find.byKey(const ValueKey('option-m-2')));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      await tapCta(tester);
      expect(find.byKey(const ValueKey('feedback-card')), findsNothing);
      expect(find.byKey(const ValueKey('free-text')), findsOneWidget);
    });

    testWidgets('free text: invalid shows title + message; the answer is interpolated on the next page', (
      tester,
    ) async {
      final repo = await pumpLesson(tester);
      when(() => repo.submitChoice(any(), any(), any())).thenAnswer((_) async => const AnswerResult(pageId: 'x'));
      when(() => repo.submitText(any(), 'p3', any())).thenAnswer((_) async => const AnswerResult(pageId: 'p3'));
      await tapCta(tester);
      await tester.tap(find.byKey(const ValueKey('option-o-b')));
      await tapCta(tester);
      await tester.tap(find.byKey(const ValueKey('option-m-3')));
      await tapCta(tester);
      expect(find.text('DONE'), findsOneWidget);

      await tapCta(tester); // empty
      expect(richText('Hello! Writing your thoughts will help you remember and build habits.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('free-text')), 'Walk 10 minutes daily');
      await tapCta(tester);
      verify(() => repo.submitText('attempt-1', 'p3', 'Walk 10 minutes daily')).called(1);
      expect(richText('Your big goal : Walk 10 minutes daily'), findsOneWidget);
    });

    testWidgets('a failed submit shows the inline error with Retry; the place is kept', (tester) async {
      final repo = await pumpLesson(tester);
      when(() => repo.submitChoice(any(), any(), any())).thenThrow(Exception('boom'));
      await tapCta(tester);
      await tester.tap(find.byKey(const ValueKey('option-o-a')));
      await tapCta(tester);
      expect(find.byKey(const ValueKey('lesson-inline-error')), findsOneWidget);
      expect(find.text('Something unexpected happened. (api)'), findsOneWidget);
      when(
        () => repo.submitChoice(any(), any(), any()),
      ).thenAnswer((_) async => const AnswerResult(pageId: 'p1', isCorrect: false, feedback: wrongFeedback));
      await tester.tap(find.byKey(const ValueKey('lesson-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feedback-card')), findsOneWidget);
    });
  });

  testWidgets('lesson load failure (API down) shows ErrorView; Retry recovers', (tester) async {
    usePhoneScreen(tester);
    final repo = MockLessonRepository();
    var calls = 0;
    when(() => repo.getLesson(any())).thenAnswer((_) async {
      if (calls++ == 0) throw const AppException(NetworkFailure());
      return sampleLesson();
    });
    when(() => repo.startAttempt(any())).thenAnswer((_) async => 'attempt-1');
    await pumpScreen(
      tester,
      const SizedBox(),
      initialLocation: '/player',
      extraRoutes: {
        '/player': BlocProvider(
          create: (_) => LessonPlayerBloc(lessonId: 'lesson-1', repository: repo)..add(const LessonStarted()),
          child: const LessonPlayerView(),
        ),
      },
    );
    await tester.pumpAndSettle();
    expect(find.text("You're offline (api)"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('error-retry')));
    await tester.pumpAndSettle();
    expect(find.text("THAT'S IMPRACTICAL!"), findsOneWidget);
  });

  group('exit, menu, completion', () {
    testWidgets('Back on page 0 opens the exit sheet; cancel keeps the lesson; confirm abandons', (tester) async {
      final repo = await pumpLesson(tester);
      await tester.tap(find.byKey(const ValueKey('lesson-back')));
      await tester.pumpAndSettle();
      expect(find.text('You have not completed this section yet'), findsOneWidget);
      expect(find.text('Your progress will be lost.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exit-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exit-sheet')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('lesson-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exit-confirm')));
      await tester.pumpAndSettle();
      verify(() => repo.abandon('attempt-1')).called(1);
    });

    testWidgets('Android system back behaves like the Back arrow', (tester) async {
      await pumpLesson(tester);
      await tapCta(tester);
      expect(find.text('NEXT'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text("THAT'S IMPRACTICAL!"), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exit-sheet')), findsOneWidget);
    });

    testWidgets('⋮ menu: Save toggles to "saved" with a check and shows the bookmark toast', (tester) async {
      final repo = await pumpLesson(tester);
      when(() => repo.setSaved(any(), saved: true)).thenAnswer((_) async => true);
      await tester.tap(find.byKey(const ValueKey('lesson-menu-button')));
      await tester.pumpAndSettle();
      expect(find.text('Save Lesson'), findsOneWidget);
      expect(find.text('Send feedback'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu-save')));
      await tester.pumpAndSettle();
      expect(find.text('Lesson saved'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('menu-save')), matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
      expect(richText('DONE! Bookmark Added 😁'), findsOneWidget);
    });

    testWidgets('feedback dialog: SUBMIT disabled until valid; Others needs text; error then success', (tester) async {
      final repo = await pumpLesson(tester);
      await tester.tap(find.byKey(const ValueKey('lesson-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-feedback')));
      await tester.pumpAndSettle();
      expect(find.text('Faced some issue ?'), findsOneWidget);
      expect(find.text('This will help improve the content of our course.'), findsOneWidget);
      FilledButton submit() => tester.widget<FilledButton>(
        find.descendant(of: find.byKey(const ValueKey('feedback-submit')), matching: find.byType(FilledButton)),
      );
      expect(submit().onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('reason-others')));
      await tester.pump();
      expect(find.text('Please tell us a little more in the text box.'), findsOneWidget);
      expect(submit().onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('feedback-comment')), 'Image did not load');
      await tester.pump();
      expect(submit().onPressed, isNotNull);

      var calls = 0;
      when(
        () => repo.sendFeedback(
          any(),
          reasonIds: any(named: 'reasonIds'),
          comment: any(named: 'comment'),
          pageId: any(named: 'pageId'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw Exception('down');
      });
      await tester.tap(find.byKey(const ValueKey('feedback-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feedback-error')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('feedback-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feedback-dialog')), findsNothing);
      expect(find.text('Thanks! Your feedback has been sent.'), findsOneWidget);
    });

    testWidgets('completion screen: headline, message, server points and Continue', (tester) async {
      final repo = await pumpLesson(
        tester,
        lessonOverride: Lesson(
          id: 'lesson-1',
          title: 't',
          nodeId: 'node-1',
          nodeType: 'lesson',
          isSaved: false,
          pages: [sampleLesson().pages.first],
        ),
      );
      when(() => repo.complete(any())).thenAnswer((_) async => sampleCompletion);
      await tapCta(tester);
      expect(find.byKey(const ValueKey('completion-view')), findsOneWidget);
      expect(find.text('You have won the day 😎'), findsOneWidget);
      expect(find.text('You just understood all the important points.'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.byKey(const ValueKey('img-/static/assets/ui_completion_medal.png')), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('CONTENT_CHANGED shows a dialog whose button restarts the lesson', (tester) async {
      final repo = await pumpLesson(
        tester,
        lessonOverride: Lesson(
          id: 'lesson-1',
          title: 't',
          nodeId: 'node-1',
          nodeType: 'lesson',
          isSaved: false,
          pages: [sampleLesson().pages.first],
        ),
      );
      when(() => repo.complete(any())).thenThrow(
        const AppException(
          ServerFailure(
            'CONTENT_CHANGED',
            statusCode: 409,
            serverMessage: 'The lesson content changed during this attempt',
          ),
        ),
      );
      await tapCta(tester);
      expect(find.byKey(const ValueKey('content-changed-dialog')), findsOneWidget);
      expect(find.text('The lesson content changed during this attempt'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('content-changed-restart')));
      await tester.pumpAndSettle();
      verify(() => repo.startAttempt('lesson-1')).called(2);
    });
  });
}
