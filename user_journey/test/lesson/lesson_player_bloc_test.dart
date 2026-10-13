import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/features/lesson/domain/lesson.dart';
import 'package:user_journey/features/lesson/domain/lesson_exit.dart';
import 'package:user_journey/features/lesson/presentation/bloc/lesson_player_bloc.dart';

import 'lesson_fixtures.dart';

class MockLessonRepository extends Mock implements LessonRepository {}

final lesson = sampleLesson();

LessonPlayerState ready({
  int pageIndex = 0,
  Map<String, PageAnswer> answers = const {},
  int hp = 0,
  String? showingFeedbackFor,
  AnswerFeedback? feedback,
}) => LessonPlayerState(
  status: LessonStatus.ready,
  lesson: lesson,
  attemptId: 'attempt-1',
  pageIndex: pageIndex,
  answers: answers,
  hpCounter: hp,
  showingFeedbackFor: showingFeedbackFor,
  feedback: feedback,
);

void main() {
  late MockLessonRepository repo;
  LessonPlayerBloc build() => LessonPlayerBloc(lessonId: 'lesson-1', repository: repo);

  setUp(() {
    repo = MockLessonRepository();
    when(() => repo.abandon(any())).thenAnswer((_) async {});
  });

  group('Started', () {
    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'loads the lesson and starts an attempt',
      setUp: () {
        when(() => repo.getLesson('lesson-1')).thenAnswer((_) async => lesson);
        when(() => repo.startAttempt('lesson-1')).thenAnswer((_) async => 'attempt-1');
      },
      build: build,
      act: (b) => b.add(const LessonStarted()),
      expect: () => [const LessonPlayerState(), ready()],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'LESSON_LOCKED → message, then pop back',
      setUp: () => when(
        () => repo.getLesson(any()),
      ).thenThrow(const AppException(ServerFailure('LESSON_LOCKED', statusCode: 403))),
      build: build,
      act: (b) => b.add(const LessonStarted()),
      verify: (b) => expect(b.state.effect, const CloseEffect(null, messageKey: 'error.locked.message')),
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'load failure → loadFailure; Retry loads again',
      setUp: () {
        var calls = 0;
        when(() => repo.getLesson(any())).thenAnswer((_) async {
          if (calls++ == 0) throw const AppException(NetworkFailure());
          return lesson;
        });
        when(() => repo.startAttempt(any())).thenAnswer((_) async => 'attempt-1');
      },
      build: build,
      act: (b) async {
        b.add(const LessonStarted());
        await Future<void>.delayed(Duration.zero);
        b.add(const RetryPressed());
      },
      expect: () => [
        const LessonPlayerState(),
        const LessonPlayerState(status: LessonStatus.loadFailure, loadFailure: NetworkFailure()),
        const LessonPlayerState(),
        ready(),
      ],
    );
  });

  group('CTA', () {
    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'on a content page goes to the next page and adds 1 to the counter',
      build: build,
      seed: ready,
      act: (b) => b.add(const CtaPressed()),
      expect: () => [ready(pageIndex: 1, hp: 1)],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'on a choice question with nothing selected shows the choice validation toast',
      build: build,
      seed: () => ready(pageIndex: 1),
      act: (b) => b.add(const CtaPressed()),
      verify: (b) {
        expect(b.state.effect, const ToastEffect(messageKey: 'lesson.choice.validation_message'));
        verifyNever(() => repo.submitChoice(any(), any(), any()));
      },
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'invalid free text shows the title + the question validation message',
      build: build,
      seed: () => ready(pageIndex: 3, answers: {'p3': const PageAnswer(text: '   ')}),
      act: (b) => b.add(const CtaPressed()),
      verify: (b) => expect(
        b.state.effect,
        const ToastEffect(
          titleKey: 'lesson.free_text.validation_title',
          message: 'Writing your thoughts will help you remember and build habits.',
        ),
      ),
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'a graded answer shows the feedback card; CTA on the feedback card advances',
      setUp: () => when(
        () => repo.submitChoice('attempt-1', 'p1', ['o-a']),
      ).thenAnswer((_) async => const AnswerResult(pageId: 'p1', isCorrect: false, feedback: wrongFeedback)),
      build: build,
      seed: () => ready(
        pageIndex: 1,
        hp: 1,
        answers: {
          'p1': const PageAnswer(optionIds: {'o-a'}),
        },
      ),
      act: (b) async {
        b.add(const CtaPressed());
        await Future<void>.delayed(Duration.zero);
        b.add(const CtaPressed());
      },
      expect: () => [
        ready(
          pageIndex: 1,
          hp: 1,
          answers: {
            'p1': const PageAnswer(optionIds: {'o-a'}),
          },
        ).copyWith(submitting: true),
        ready(
          pageIndex: 1,
          hp: 1,
          answers: {
            'p1': const PageAnswer(optionIds: {'o-a'}),
          },
          showingFeedbackFor: 'p1',
          feedback: wrongFeedback,
        ),
        ready(
          pageIndex: 2,
          hp: 2,
          answers: {
            'p1': const PageAnswer(optionIds: {'o-a'}),
          },
        ),
      ],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'an ungraded multiple-choice answer advances directly',
      setUp: () =>
          when(() => repo.submitChoice(any(), 'p2', any())).thenAnswer((_) async => const AnswerResult(pageId: 'p2')),
      build: build,
      seed: () => ready(
        pageIndex: 2,
        hp: 2,
        answers: {
          'p2': const PageAnswer(optionIds: {'m-1'}),
        },
      ),
      act: (b) => b.add(const CtaPressed()),
      verify: (b) {
        expect(b.state.pageIndex, 3);
        expect(b.state.hpCounter, 3);
        expect(b.state.isShowingFeedback, isFalse);
      },
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'a failed submit shows an inline error and keeps the place; Retry resubmits',
      setUp: () {
        var calls = 0;
        when(() => repo.submitText(any(), 'p3', any())).thenAnswer((_) async {
          if (calls++ == 0) throw const AppException(TimeoutFailure());
          return const AnswerResult(pageId: 'p3');
        });
      },
      build: build,
      seed: () => ready(pageIndex: 3, hp: 3, answers: {'p3': const PageAnswer(text: 'Walk daily')}),
      act: (b) async {
        b.add(const CtaPressed());
        await Future<void>.delayed(Duration.zero);
        b.add(const RetryPressed());
      },
      expect: () => [
        ready(pageIndex: 3, hp: 3, answers: {'p3': const PageAnswer(text: 'Walk daily')}).copyWith(submitting: true),
        ready(
          pageIndex: 3,
          hp: 3,
          answers: {'p3': const PageAnswer(text: 'Walk daily')},
        ).copyWith(inlineError: const TimeoutFailure()),
        ready(pageIndex: 3, hp: 3, answers: {'p3': const PageAnswer(text: 'Walk daily')}).copyWith(submitting: true),
        ready(pageIndex: 3, hp: 3, answers: {'p3': const PageAnswer(text: 'Walk daily')}),
        ready(pageIndex: 4, hp: 4, answers: {'p3': const PageAnswer(text: 'Walk daily')}),
      ],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'CTA on the last page completes; Continue pops with completed + unlockedNodeId',
      setUp: () => when(() => repo.complete('attempt-1')).thenAnswer((_) async => sampleCompletion),
      build: build,
      seed: () => ready(pageIndex: 4, hp: 4),
      act: (b) async {
        b.add(const CtaPressed());
        await Future<void>.delayed(Duration.zero);
        b.add(const CtaPressed());
      },
      verify: (b) {
        expect(b.state.status, LessonStatus.completed);
        expect(b.state.completion, sampleCompletion);
        expect(
          b.state.effect,
          const CloseEffect(LessonExit(reason: LessonExitReason.completed, nodeId: 'node-1', unlockedNodeId: 'node-2')),
        );
      },
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'CONTENT_CHANGED on complete shows the restart dialog with the server message',
      setUp: () => when(() => repo.complete(any())).thenThrow(
        const AppException(ServerFailure('CONTENT_CHANGED', statusCode: 409, serverMessage: 'The lesson changed')),
      ),
      build: build,
      seed: () => ready(pageIndex: 4),
      act: (b) => b.add(const CtaPressed()),
      verify: (b) {
        expect(b.state.effect, const ContentChangedEffect('The lesson changed'));
        expect(b.state.submitting, isFalse);
        expect(b.state.status, LessonStatus.ready);
      },
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'a failed complete keeps the place with an inline error',
      setUp: () => when(() => repo.complete(any())).thenThrow(const AppException(NetworkFailure())),
      build: build,
      seed: () => ready(pageIndex: 4),
      act: (b) => b.add(const CtaPressed()),
      verify: (b) {
        expect(b.state.inlineError, const NetworkFailure());
        expect(b.state.pageIndex, 4);
      },
    );
  });

  group('Back (SPEC 8.4)', () {
    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'from the feedback card returns to the question with the selection kept',
      build: build,
      seed: () => ready(
        pageIndex: 1,
        hp: 1,
        answers: {
          'p1': const PageAnswer(optionIds: {'o-a'}),
        },
        showingFeedbackFor: 'p1',
        feedback: wrongFeedback,
      ),
      act: (b) => b.add(const BackPressed()),
      expect: () => [
        ready(
          pageIndex: 1,
          hp: 1,
          answers: {
            'p1': const PageAnswer(optionIds: {'o-a'}),
          },
        ),
      ],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'from page N > 0 goes to N − 1 and subtracts 1 from the counter',
      build: build,
      seed: () => ready(pageIndex: 2, hp: 2),
      act: (b) => b.add(const BackPressed()),
      expect: () => [ready(pageIndex: 1, hp: 1)],
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'from page 0 shows the exit sheet; ExitConfirmed abandons (fire-and-forget) and pops abandoned',
      build: build,
      seed: ready,
      act: (b) async {
        b.add(const BackPressed());
        await Future<void>.delayed(Duration.zero);
        expect(b.state.effect, const ShowExitSheetEffect());
        b.add(const ExitConfirmed());
      },
      verify: (b) {
        verify(() => repo.abandon('attempt-1')).called(1);
        expect(b.state.effect, const CloseEffect(LessonExit(reason: LessonExitReason.abandoned, nodeId: 'node-1')));
      },
    );
  });

  group('selection and input', () {
    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'single choice replaces; multiple choice toggles and respects maxSelections',
      build: build,
      seed: () => ready(pageIndex: 2),
      act: (b) => b
        ..add(const OptionToggled('m-1'))
        ..add(const OptionToggled('m-2'))
        ..add(const OptionToggled('m-3')) // max 2 → ignored
        ..add(const OptionToggled('m-1')), // deselect
      verify: (b) => expect(b.state.answerFor('p2').optionIds, {'m-2'}),
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'free-text answers feed {{answer.key}} interpolation',
      build: build,
      seed: () => ready(pageIndex: 3),
      act: (b) => b.add(const TextChanged('  Walk daily ')),
      verify: (b) => expect(b.state.freeTextAnswers, {'big_goal': 'Walk daily'}),
    );
  });

  group('menu', () {
    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'SaveToggled saves (optimistic) and shows the bookmark toast',
      setUp: () => when(() => repo.setSaved('lesson-1', saved: true)).thenAnswer((_) async => true),
      build: build,
      seed: ready,
      act: (b) => b.add(const SaveToggled()),
      verify: (b) {
        expect(b.state.isSaved, isTrue);
        expect(
          b.state.effect,
          const ToastEffect(titleKey: 'lesson.saved.toast.title', messageKey: 'lesson.saved.toast.message'),
        );
      },
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'a failed save reverts the toggle',
      setUp: () =>
          when(() => repo.setSaved(any(), saved: any(named: 'saved'))).thenThrow(const AppException(NetworkFailure())),
      build: build,
      seed: ready,
      act: (b) => b.add(const SaveToggled()),
      verify: (b) => expect(b.state.isSaved, isFalse),
    );

    blocTest<LessonPlayerBloc, LessonPlayerState>(
      'FeedbackSubmitted sends the current page id; failure shows an inline error, success a toast',
      setUp: () {
        var calls = 0;
        when(
          () => repo.sendFeedback(
            any(),
            reasonIds: any(named: 'reasonIds'),
            comment: any(named: 'comment'),
            pageId: any(named: 'pageId'),
          ),
        ).thenAnswer((_) async {
          if (calls++ == 0) throw const AppException(ServerFailure('FEEDBACK_INVALID', statusCode: 422));
        });
      },
      build: build,
      seed: () => ready(pageIndex: 1),
      act: (b) async {
        b.add(const FeedbackSubmitted(reasonIds: ['r-others'], comment: 'broken image'));
        await Future<void>.delayed(Duration.zero);
        expect(b.state.feedbackError, const ServerFailure('FEEDBACK_INVALID', statusCode: 422));
        b.add(const FeedbackSubmitted(reasonIds: ['r-others'], comment: 'broken image'));
      },
      verify: (b) {
        verify(
          () => repo.sendFeedback('lesson-1', reasonIds: ['r-others'], comment: 'broken image', pageId: 'p1'),
        ).called(2);
        expect(b.state.effect, const FeedbackSentEffect());
        expect(b.state.feedbackError, isNull);
      },
    );
  });
}
