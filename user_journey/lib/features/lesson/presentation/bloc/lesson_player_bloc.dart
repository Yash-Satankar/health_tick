import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/lesson.dart';
import '../../domain/lesson_exit.dart';

part 'lesson_player_bloc.freezed.dart';

// ---------------------------------------------------------------- events (SPEC §8.4)

sealed class LessonPlayerEvent {
  const LessonPlayerEvent();
}

/// Loads the lesson and starts an attempt (also used to restart after CONTENT_CHANGED).
final class LessonStarted extends LessonPlayerEvent {
  const LessonStarted();
}

final class OptionToggled extends LessonPlayerEvent {
  const OptionToggled(this.optionId);
  final String optionId;
}

final class TextChanged extends LessonPlayerEvent {
  const TextChanged(this.text);
  final String text;
}

/// The bottom CTA (also "Continue" on the completion screen).
final class CtaPressed extends LessonPlayerEvent {
  const CtaPressed();
}

/// The Back arrow and Android system back.
final class BackPressed extends LessonPlayerEvent {
  const BackPressed();
}

final class ExitConfirmed extends LessonPlayerEvent {
  const ExitConfirmed();
}

final class RetryPressed extends LessonPlayerEvent {
  const RetryPressed();
}

final class SaveToggled extends LessonPlayerEvent {
  const SaveToggled();
}

final class FeedbackSubmitted extends LessonPlayerEvent {
  const FeedbackSubmitted({required this.reasonIds, this.comment});
  final List<String> reasonIds;
  final String? comment;
}

// ---------------------------------------------------------------- state

enum LessonStatus { loading, ready, loadFailure, completed }

/// A user's (unsaved) answer on one question page.
@immutable
class PageAnswer {
  const PageAnswer({this.optionIds = const {}, this.text = ''});

  final Set<String> optionIds;
  final String text;

  PageAnswer copyWith({Set<String>? optionIds, String? text}) =>
      PageAnswer(optionIds: optionIds ?? this.optionIds, text: text ?? this.text);

  @override
  bool operator ==(Object other) => other is PageAnswer && setEquals(other.optionIds, optionIds) && other.text == text;
  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(optionIds), text);
}

/// One-shot UI effects, identified by `effectId` so each is handled once.
@immutable
sealed class LessonEffect {
  const LessonEffect();
}

/// A toast built from copy keys and/or a literal message from the API.
final class ToastEffect extends LessonEffect {
  const ToastEffect({this.titleKey, this.messageKey, this.message});
  final String? titleKey;
  final String? messageKey;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ToastEffect && other.titleKey == titleKey && other.messageKey == messageKey && other.message == message;
  @override
  int get hashCode => Object.hash(titleKey, messageKey, message);
}

final class ShowExitSheetEffect extends LessonEffect {
  const ShowExitSheetEffect();
  @override
  bool operator ==(Object other) => other is ShowExitSheetEffect;
  @override
  int get hashCode => 11;
}

/// CONTENT_CHANGED: a dialog explaining the lesson was updated, with a restart button.
final class ContentChangedEffect extends LessonEffect {
  const ContentChangedEffect(this.message);
  final String? message;
  @override
  bool operator ==(Object other) => other is ContentChangedEffect && other.message == message;
  @override
  int get hashCode => Object.hash(12, message);
}

final class FeedbackSentEffect extends LessonEffect {
  const FeedbackSentEffect();
  @override
  bool operator ==(Object other) => other is FeedbackSentEffect;
  @override
  int get hashCode => 13;
}

/// Pop the lesson route with [exit] (optionally after showing [messageKey]).
final class CloseEffect extends LessonEffect {
  const CloseEffect(this.exit, {this.messageKey});
  final LessonExit? exit;
  final String? messageKey;
  @override
  bool operator ==(Object other) => other is CloseEffect && other.exit == exit && other.messageKey == messageKey;
  @override
  int get hashCode => Object.hash(exit, messageKey);
}

@freezed
abstract class LessonPlayerState with _$LessonPlayerState {
  const LessonPlayerState._();

  const factory LessonPlayerState({
    @Default(LessonStatus.loading) LessonStatus status,
    Lesson? lesson,
    String? attemptId,
    @Default(0) int pageIndex,
    @Default(<String, PageAnswer>{}) Map<String, PageAnswer> answers,
    String? showingFeedbackFor,
    AnswerFeedback? feedback,
    @Default(0) int hpCounter,
    @Default(false) bool submitting,
    Failure? inlineError,
    LessonCompletion? completion,
    @Default(false) bool isSaved,
    Failure? loadFailure,
    @Default(false) bool feedbackSubmitting,
    Failure? feedbackError,
    LessonEffect? effect,
    @Default(0) int effectId,
  }) = _LessonPlayerState;

  LessonPage? get page {
    final pages = lesson?.pages;
    if (pages == null || pageIndex < 0 || pageIndex >= pages.length) return null;
    return pages[pageIndex];
  }

  bool get isLastPage => lesson != null && pageIndex == lesson!.pageCount - 1;

  bool get isShowingFeedback => showingFeedbackFor != null;

  PageAnswer answerFor(String pageId) => answers[pageId] ?? const PageAnswer();

  /// Progress bar value: (pageIndex + 1) / pageCount.
  double get progress => lesson == null || lesson!.pageCount == 0 ? 0 : (pageIndex + 1) / lesson!.pageCount;

  /// Free-text answers given earlier in this attempt, by answer key (for `{{answer.key}}`).
  Map<String, String> get freeTextAnswers {
    final result = <String, String>{};
    for (final page in lesson?.pages ?? const <LessonPage>[]) {
      final key = page.question?.answerKey;
      final text = answers[page.id]?.text.trim();
      if (key != null && text != null && text.isNotEmpty) result[key] = text;
    }
    return result;
  }
}

// ---------------------------------------------------------------- bloc

class LessonPlayerBloc extends Bloc<LessonPlayerEvent, LessonPlayerState> {
  LessonPlayerBloc({required this.lessonId, required this.repository}) : super(const LessonPlayerState()) {
    on<LessonStarted>(_onStarted);
    on<OptionToggled>(_onOptionToggled);
    on<TextChanged>(_onTextChanged);
    on<CtaPressed>(_onCta);
    on<BackPressed>(_onBack);
    on<ExitConfirmed>(_onExitConfirmed);
    on<RetryPressed>(_onRetry);
    on<SaveToggled>(_onSaveToggled);
    on<FeedbackSubmitted>(_onFeedbackSubmitted);
  }

  final String lessonId;
  final LessonRepository repository;

  LessonPlayerState _withEffect(LessonPlayerState s, LessonEffect effect) =>
      s.copyWith(effect: effect, effectId: s.effectId + 1);

  Future<void> _onStarted(LessonStarted event, Emitter<LessonPlayerState> emit) async {
    emit(LessonPlayerState(effectId: state.effectId));
    try {
      final lesson = await repository.getLesson(lessonId);
      final attemptId = await repository.startAttempt(lessonId);
      emit(state.copyWith(status: LessonStatus.ready, lesson: lesson, attemptId: attemptId, isSaved: lesson.isSaved));
    } catch (error) {
      final failure = mapError(error);
      if (failure is ServerFailure && (failure.isLessonLocked || failure.isNotFound)) {
        // A message, then pop back (SPEC §9.6).
        emit(_withEffect(state, CloseEffect(null, messageKey: failure.messageKey)));
        return;
      }
      emit(state.copyWith(status: LessonStatus.loadFailure, loadFailure: failure));
    }
  }

  void _onOptionToggled(OptionToggled event, Emitter<LessonPlayerState> emit) {
    final page = state.page;
    final question = page?.question;
    if (page == null || question == null || !question.isChoice || state.isShowingFeedback || state.submitting) return;
    final current = state.answerFor(page.id).optionIds;
    Set<String> next;
    if (question.responseType == ResponseType.singleChoice) {
      next = {event.optionId};
    } else if (current.contains(event.optionId)) {
      next = {...current}..remove(event.optionId);
    } else {
      final max = question.effectiveMaxSelections;
      if (max != null && current.length >= max) return;
      next = {...current, event.optionId};
    }
    emit(
      state.copyWith(
        answers: {
          ...state.answers,
          page.id: state.answerFor(page.id).copyWith(optionIds: next),
        },
      ),
    );
  }

  void _onTextChanged(TextChanged event, Emitter<LessonPlayerState> emit) {
    final page = state.page;
    if (page?.question?.responseType != ResponseType.freeText) return;
    emit(
      state.copyWith(
        answers: {
          ...state.answers,
          page!.id: state.answerFor(page.id).copyWith(text: event.text),
        },
      ),
    );
  }

  Future<void> _onCta(CtaPressed event, Emitter<LessonPlayerState> emit) async {
    if (state.submitting) return;
    if (state.status == LessonStatus.completed) {
      emit(_withEffect(state, CloseEffect(_exit(LessonExitReason.completed))));
      return;
    }
    final page = state.page;
    if (state.status != LessonStatus.ready || page == null) return;

    // CTA on the feedback card: advance.
    if (state.isShowingFeedback) {
      await _advance(emit);
      return;
    }
    // CTA on a content page: next page, or complete on the last one.
    if (!page.isQuestion) {
      await _advance(emit);
      return;
    }
    // CTA on a question page: validate locally, then PUT the answer.
    final question = page.question!;
    final answer = state.answerFor(page.id);
    if (question.isChoice) {
      final count = answer.optionIds.length;
      final max = question.effectiveMaxSelections;
      if (count < question.effectiveMinSelections || (max != null && count > max)) {
        emit(_withEffect(state, const ToastEffect(messageKey: 'lesson.choice.validation_message')));
        return;
      }
    } else {
      final length = answer.text.trim().runes.length;
      if (length < question.effectiveMinLength || length > question.effectiveMaxLength) {
        emit(
          _withEffect(
            state,
            ToastEffect(titleKey: 'lesson.free_text.validation_title', message: question.validationMessage),
          ),
        );
        return;
      }
    }

    emit(state.copyWith(submitting: true, inlineError: null));
    try {
      final result = question.isChoice
          ? await repository.submitChoice(state.attemptId!, page.id, answer.optionIds.toList())
          : await repository.submitText(state.attemptId!, page.id, answer.text.trim());
      if (result.feedback != null) {
        emit(state.copyWith(submitting: false, showingFeedbackFor: page.id, feedback: result.feedback));
      } else {
        emit(state.copyWith(submitting: false));
        await _advance(emit);
      }
    } catch (error) {
      // Inline error above the CTA with Retry; the user's place is kept.
      emit(state.copyWith(submitting: false, inlineError: mapError(error)));
    }
  }

  /// Next page (+1 health point on the counter) or complete on the last page.
  Future<void> _advance(Emitter<LessonPlayerState> emit) async {
    if (!state.isLastPage) {
      emit(
        state.copyWith(
          pageIndex: state.pageIndex + 1,
          hpCounter: state.hpCounter + 1,
          showingFeedbackFor: null,
          feedback: null,
          inlineError: null,
        ),
      );
      return;
    }
    emit(state.copyWith(submitting: true, inlineError: null));
    try {
      final completion = await repository.complete(state.attemptId!);
      emit(
        state.copyWith(
          submitting: false,
          status: LessonStatus.completed,
          completion: completion,
          showingFeedbackFor: null,
          feedback: null,
        ),
      );
    } catch (error) {
      final failure = mapError(error);
      if (failure is ServerFailure && failure.isContentChanged) {
        emit(_withEffect(state.copyWith(submitting: false), ContentChangedEffect(failure.serverMessage)));
      } else {
        emit(state.copyWith(submitting: false, inlineError: failure));
      }
    }
  }

  void _onBack(BackPressed event, Emitter<LessonPlayerState> emit) {
    if (state.submitting) return;
    switch (state.status) {
      case LessonStatus.loading:
      case LessonStatus.loadFailure:
        emit(_withEffect(state, const CloseEffect(null)));
      case LessonStatus.completed:
        emit(_withEffect(state, CloseEffect(_exit(LessonExitReason.completed))));
      case LessonStatus.ready:
        if (state.isShowingFeedback) {
          // Back from the feedback card: return to the question with the selection kept.
          emit(state.copyWith(showingFeedbackFor: null, feedback: null, inlineError: null));
        } else if (state.pageIndex > 0) {
          emit(
            state.copyWith(
              pageIndex: state.pageIndex - 1,
              hpCounter: state.hpCounter > 0 ? state.hpCounter - 1 : 0,
              inlineError: null,
            ),
          );
        } else {
          emit(_withEffect(state, const ShowExitSheetEffect()));
        }
    }
  }

  void _onExitConfirmed(ExitConfirmed event, Emitter<LessonPlayerState> emit) {
    final attemptId = state.attemptId;
    if (attemptId != null) {
      // Fire-and-forget (SPEC §9.6); failures are irrelevant to the user.
      unawaited(repository.abandon(attemptId).catchError((Object _) {}));
    }
    emit(_withEffect(state, CloseEffect(_exit(LessonExitReason.abandoned))));
  }

  Future<void> _onRetry(RetryPressed event, Emitter<LessonPlayerState> emit) async {
    if (state.status == LessonStatus.loadFailure) {
      await _onStarted(const LessonStarted(), emit);
    } else if (state.inlineError != null) {
      await _onCta(const CtaPressed(), emit);
    }
  }

  Future<void> _onSaveToggled(SaveToggled event, Emitter<LessonPlayerState> emit) async {
    if (state.lesson == null) return;
    final target = !state.isSaved;
    emit(state.copyWith(isSaved: target)); // optimistic
    try {
      final saved = await repository.setSaved(lessonId, saved: target);
      final next = state.copyWith(isSaved: saved);
      emit(
        saved
            ? _withEffect(
                next,
                const ToastEffect(titleKey: 'lesson.saved.toast.title', messageKey: 'lesson.saved.toast.message'),
              )
            : next,
      );
    } catch (error) {
      emit(_withEffect(state.copyWith(isSaved: !target), ToastEffect(messageKey: mapError(error).messageKey)));
    }
  }

  Future<void> _onFeedbackSubmitted(FeedbackSubmitted event, Emitter<LessonPlayerState> emit) async {
    if (state.feedbackSubmitting) return;
    emit(state.copyWith(feedbackSubmitting: true, feedbackError: null));
    try {
      await repository.sendFeedback(
        lessonId,
        reasonIds: event.reasonIds,
        comment: event.comment,
        pageId: state.page?.id,
      );
      emit(_withEffect(state.copyWith(feedbackSubmitting: false), const FeedbackSentEffect()));
    } catch (error) {
      emit(state.copyWith(feedbackSubmitting: false, feedbackError: mapError(error)));
    }
  }

  LessonExit? _exit(LessonExitReason reason) {
    final lesson = state.lesson;
    if (lesson == null) return null;
    return LessonExit(
      reason: reason,
      nodeId: lesson.nodeId,
      unlockedNodeId: reason == LessonExitReason.completed ? state.completion?.unlockedNodeId : null,
    );
  }
}
