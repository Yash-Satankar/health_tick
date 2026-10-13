import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/copy/app_copy.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../app_config/domain/bootstrap.dart';
import '../bloc/lesson_player_bloc.dart';

/// Exit confirmation (SPEC §9.6). Returns true when the user confirms.
Future<bool> showExitSheet(BuildContext context, AppCopy copy) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        key: const ValueKey('exit-sheet'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy('lesson.exit.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              copy('lesson.exit.message'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              key: const ValueKey('exit-confirm'),
              onPressed: () => Navigator.of(sheetContext).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.textSecondary),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
              ),
              child: Text(copy('lesson.exit.confirm')),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              key: const ValueKey('exit-cancel'),
              label: copy('lesson.exit.cancel'),
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// ⋮ menu: Save Lesson toggle and Send feedback (SPEC §9.6).
Future<void> showLessonMenu(
  BuildContext context, {
  required AppCopy copy,
  required LessonPlayerBloc bloc,
  required List<FeedbackReason> reasons,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => BlocProvider.value(
      value: bloc,
      child: SafeArea(
        child: Padding(
          key: const ValueKey('lesson-menu'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlocBuilder<LessonPlayerBloc, LessonPlayerState>(
                buildWhen: (a, b) => a.isSaved != b.isSaved,
                builder: (context, state) => ListTile(
                  key: const ValueKey('menu-save'),
                  leading: Icon(
                    state.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: AppColors.textPrimary,
                  ),
                  title: Text(copy(state.isSaved ? 'lesson.menu.saved' : 'lesson.menu.save')),
                  trailing: state.isSaved ? const Icon(Icons.check_rounded, color: AppColors.completedCheck) : null,
                  onTap: () => bloc.add(const SaveToggled()),
                ),
              ),
              ListTile(
                key: const ValueKey('menu-feedback'),
                leading: const Icon(Icons.flag_outlined, color: AppColors.textPrimary),
                title: Text(copy('lesson.menu.feedback')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showFeedbackDialog(context, copy: copy, bloc: bloc, reasons: reasons);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showFeedbackDialog(
  BuildContext context, {
  required AppCopy copy,
  required LessonPlayerBloc bloc,
  required List<FeedbackReason> reasons,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: FeedbackDialog(copy: copy, reasons: reasons),
    ),
  );
}

/// "Faced some issue ?" dialog: reasons from bootstrap, an "Other" text field, footer and SUBMIT.
/// SUBMIT is disabled until the input is valid; inline error on failure; closes on success (SPEC §9.6).
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key, required this.copy, required this.reasons});

  final AppCopy copy;
  final List<FeedbackReason> reasons;

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final Set<String> _selected = {};
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _needsText => widget.reasons.any((r) => r.requiresText && _selected.contains(r.id));
  bool get _hasText => _comment.text.trim().isNotEmpty;
  bool get _isValid => (_selected.isNotEmpty || _hasText) && (!_needsText || _hasText);

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    return BlocConsumer<LessonPlayerBloc, LessonPlayerState>(
      listenWhen: (a, b) => b.effectId != a.effectId && b.effect is FeedbackSentEffect,
      listener: (context, state) => Navigator.of(context).pop(),
      builder: (context, state) => AlertDialog(
        key: const ValueKey('feedback-dialog'),
        backgroundColor: AppColors.surface,
        title: Text(copy('lesson.feedback.title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy('lesson.feedback.subtitle'), style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              for (final reason in widget.reasons)
                CheckboxListTile(
                  key: ValueKey('reason-${reason.key}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selected.contains(reason.id),
                  title: Text(reason.label),
                  onChanged: (checked) => setState(() {
                    checked == true ? _selected.add(reason.id) : _selected.remove(reason.id);
                  }),
                ),
              TextField(
                key: const ValueKey('feedback-comment'),
                controller: _comment,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: copy('lesson.feedback.other_placeholder'),
                  border: const OutlineInputBorder(),
                  errorText: _needsText && !_hasText ? copy('lesson.feedback.other_required') : null,
                ),
              ),
              Text(
                copy('lesson.feedback.footer'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (state.feedbackError != null) ...[
                const SizedBox(height: 8),
                Text(
                  copy(state.feedbackError!.messageKey),
                  key: const ValueKey('feedback-error'),
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          PrimaryButton(
            key: const ValueKey('feedback-submit'),
            label: copy('lesson.feedback.submit'),
            loading: state.feedbackSubmitting,
            onPressed: _isValid
                ? () => context.read<LessonPlayerBloc>().add(
                    FeedbackSubmitted(reasonIds: _selected.toList(), comment: _hasText ? _comment.text.trim() : null),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
