import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/copy/app_copy.dart';
import '../../../../core/copy/copy_context.dart';
import '../../../../core/markup/markup_parser.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/toast.dart';
import '../../../../di.dart';
import '../../../app_config/domain/bootstrap.dart';
import '../../domain/lesson.dart';
import '../bloc/lesson_player_bloc.dart';
import '../widgets/block_view.dart';
import '../widgets/completion_view.dart';
import '../widgets/feedback_card.dart';
import '../widgets/lesson_sheets.dart';
import '../widgets/question_view.dart';

/// Lesson player route `/lesson/:lessonId` (SPEC §9.6). Pops a `LessonExit`.
class LessonPlayerPage extends StatelessWidget {
  const LessonPlayerPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LessonPlayerBloc(lessonId: lessonId, repository: sl<LessonRepository>())..add(const LessonStarted()),
    child: const LessonPlayerView(),
  );
}

class LessonPlayerView extends StatelessWidget {
  const LessonPlayerView({super.key});

  Future<void> _handleEffect(BuildContext context, LessonPlayerState state) async {
    final copy = context.readCopy;
    final bloc = context.read<LessonPlayerBloc>();
    switch (state.effect) {
      case ToastEffect(:final titleKey, :final messageKey, :final message):
        showToast(
          context,
          message ?? (messageKey == null ? '' : copy(messageKey)),
          title: titleKey == null ? null : copy(titleKey),
        );
      case ShowExitSheetEffect():
        if (await showExitSheet(context, copy)) bloc.add(const ExitConfirmed());
      case ContentChangedEffect(:final message):
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            key: const ValueKey('content-changed-dialog'),
            backgroundColor: AppColors.surface,
            content: Text(message ?? copy('error.unexpected.message')),
            actions: [
              PrimaryButton(
                key: const ValueKey('content-changed-restart'),
                label: copy('error.retry'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  bloc.add(const LessonStarted());
                },
              ),
            ],
          ),
        );
      case FeedbackSentEffect():
        showToast(context, copy('lesson.feedback.sent.toast'));
      case CloseEffect(:final exit, :final messageKey):
        if (messageKey != null) showToast(context, copy(messageKey));
        if (context.canPop()) context.pop(exit);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    return BlocConsumer<LessonPlayerBloc, LessonPlayerState>(
      listenWhen: (a, b) => b.effectId != a.effectId && b.effect != null,
      listener: _handleEffect,
      builder: (context, state) {
        final bloc = context.read<LessonPlayerBloc>();
        return PopScope(
          canPop: false,
          // Android system back behaves exactly like the Back arrow (SPEC §8.4).
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const BackPressed());
          },
          child: Scaffold(
            body: switch (state.status) {
              LessonStatus.loading => const SafeArea(child: LoadingView(key: ValueKey('lesson-loading'))),
              LessonStatus.loadFailure => SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BackButton(onPressed: () => bloc.add(const BackPressed())),
                    ),
                    Expanded(
                      child: ErrorView(
                        failure: state.loadFailure!,
                        copy: copy,
                        onRetry: () {
                          context.reloadConfigIfFailed();
                          bloc.add(const RetryPressed());
                        },
                      ),
                    ),
                  ],
                ),
              ),
              LessonStatus.completed => CompletionView(
                completion: state.completion!,
                fallbackAsset: context.bootstrap?.completionMedalAsset,
                continueLabel: copy('lesson.completion.continue'),
                onContinue: () => bloc.add(const CtaPressed()),
              ),
              LessonStatus.ready => SafeArea(
                child: _LessonBody(state: state, copy: copy),
              ),
            },
          ),
        );
      },
    );
  }
}

class _LessonBody extends StatelessWidget {
  const _LessonBody({required this.state, required this.copy});

  final LessonPlayerState state;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LessonPlayerBloc>();
    final page = state.page!;
    final resolver = TokenResolver(userName: context.bootstrap?.displayName ?? '', answers: state.freeTextAnswers);
    final bodyKey = ValueKey('page-${page.id}-${state.isShowingFeedback ? 'feedback' : 'content'}');
    return Column(
      children: [
        _TopBar(progress: state.progress, hpCounter: state.hpCounter, onBack: () => bloc.add(const BackPressed())),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppDurations.pageCrossfade,
            // A new key per page gives a fresh scroll view, i.e. the body starts at the top.
            child: SingleChildScrollView(
              key: bodyKey,
              padding: const EdgeInsets.fromLTRB(AppSizes.gutter, 8, AppSizes.gutter, 24),
              child: state.isShowingFeedback
                  ? FeedbackCard(
                      feedback: state.feedback!,
                      answerPrefix: copy('lesson.feedback_card.answer_prefix'),
                      resolver: resolver,
                    )
                  : _PageContent(page: page, state: state, copy: copy, resolver: resolver),
            ),
          ),
        ),
        _BottomBar(page: page, state: state, copy: copy),
      ],
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page, required this.state, required this.copy, required this.resolver});

  final LessonPage page;
  final LessonPlayerState state;
  final AppCopy copy;
  final TokenResolver resolver;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LessonPlayerBloc>();
    final question = page.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in page.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: BlockView(block: block, resolver: resolver),
          ),
        if (page.isQuestion && question!.isChoice)
          ChoiceOptions(
            question: question,
            selected: state.answerFor(page.id).optionIds,
            onToggle: (id) => bloc.add(OptionToggled(id)),
          ),
        if (page.isQuestion && !question!.isChoice)
          FreeTextInput(
            key: ValueKey('free-text-${page.id}'),
            question: question,
            initialText: state.answerFor(page.id).text,
            placeholder: copy('lesson.free_text.placeholder'),
            onChanged: (text) => bloc.add(TextChanged(text)),
          ),
      ],
    );
  }
}

/// Back arrow, progress bar animated over 250 ms, heart-pulse icon with the counter.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress, required this.hpCounter, required this.onBack});

  final double progress;
  final int hpCounter;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, AppSizes.gutter, 4),
      child: Row(
        children: [
          IconButton(key: const ValueKey('lesson-back'), onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: AppDurations.progress,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  key: const ValueKey('lesson-progress'),
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.surface,
                  color: AppColors.healthAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.monitor_heart_rounded, color: AppColors.healthAccent),
          const SizedBox(width: 4),
          Text(
            '$hpCounter',
            key: const ValueKey('lesson-hp'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Full-width CTA with the content's label (spinner while submitting), ⋮ button, inline error + Retry.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.page, required this.state, required this.copy});

  final LessonPage page;
  final LessonPlayerState state;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LessonPlayerBloc>();
    final reasons = context.bootstrap?.feedbackReasons ?? const <FeedbackReason>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.gutter, 4, 8, AppSizes.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.inlineError != null)
            Padding(
              key: const ValueKey('lesson-inline-error'),
              padding: const EdgeInsets.only(bottom: 8, right: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(copy(state.inlineError!.messageKey), style: const TextStyle(color: AppColors.error)),
                  ),
                  TextButton(
                    key: const ValueKey('lesson-retry'),
                    onPressed: () => bloc.add(const RetryPressed()),
                    child: Text(copy('error.retry')),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: const ValueKey('lesson-cta'),
                  label: page.ctaLabel,
                  loading: state.submitting,
                  onPressed: () => bloc.add(const CtaPressed()),
                ),
              ),
              IconButton(
                key: const ValueKey('lesson-menu-button'),
                onPressed: () => showLessonMenu(context, copy: copy, bloc: bloc, reasons: reasons),
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
