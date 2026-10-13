import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/copy/app_copy.dart';
import '../../../../core/copy/copy_context.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/toast.dart';
import '../../../lesson/presentation/open_lesson.dart';
import '../../domain/journey.dart';
import '../bloc/journey_cubit.dart';
import '../widgets/journey_path_view.dart';

/// Journey page (SPEC §9.3).
class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key});

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<JourneyCubit>();
    cubit.state is JourneyLoaded ? cubit.silentRefresh() : cubit.load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onNodeTap(JourneyNode node) {
    final cubit = context.read<JourneyCubit>();
    if (node.isCheckpoint) {
      // A checkpoint opens its lesson directly, without a popover (SPEC §4.5).
      final lesson = node.lessons.firstOrNull;
      if (lesson != null) openLesson(context, lesson.id);
      return;
    }
    cubit.selectNode(node.id);
  }

  void _onLockedTap() {
    showToast(context, context.readCopy('journey.locked.message'));
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home)),
        title: Text(copy('journey.title')),
        titleSpacing: 0,
        actions: [
          _OutlinedAction(
            key: const ValueKey('journey-reload'),
            label: copy('journey.reload'),
            onPressed: () => context.read<JourneyCubit>().reload(),
          ),
          const SizedBox(width: 8),
          _OutlinedAction(
            key: const ValueKey('journey-search'),
            label: copy('journey.search'),
            icon: Icons.search_rounded,
            onPressed: () => context.push(AppRoutes.search),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocConsumer<JourneyCubit, JourneyState>(
        listenWhen: (previous, current) {
          if (current is! JourneyLoaded) return false;
          final prev = previous is JourneyLoaded ? previous : null;
          return current.errorId != (prev?.errorId ?? 0) || current.scrollToTopId != (prev?.scrollToTopId ?? 0);
        },
        listener: (context, state) {
          final loaded = state as JourneyLoaded;
          if (loaded.transientError != null) showToast(context, copy(loaded.transientError!.messageKey));
          if (_scroll.hasClients && loaded.transientError == null) {
            _scroll.animateTo(0, duration: AppDurations.ensureVisible, curve: Curves.easeOut);
          }
        },
        builder: (context, state) => switch (state) {
          JourneyLoading() => const LoadingView(key: ValueKey('journey-loading')),
          JourneyFailure(:final failure) => ErrorView(
            failure: failure,
            copy: copy,
            onRetry: () => context.read<JourneyCubit>().load(),
          ),
          JourneyLoaded(:final journey) when journey.statuses.isEmpty => ErrorView(
            key: const ValueKey('journey-empty'),
            failure: const UnexpectedFailure(),
            copy: copy,
            message: copy('error.not_found.message'),
            onRetry: () => context.read<JourneyCubit>().reload(),
          ),
          JourneyLoaded() => Stack(
            children: [
              JourneyPathView(
                journey: state.journey,
                copy: copy,
                lockedAsset: context.bootstrap?.lockedNodeAsset,
                selectedNodeId: state.selectedNodeId,
                pulseNodeId: state.pulseNodeId,
                scrollController: _scroll,
                onNodeTap: _onNodeTap,
                onLockedTap: _onLockedTap,
                onClosePopover: () => context.read<JourneyCubit>().clearSelection(),
                onOpenLesson: (lessonId) => openLesson(context, lessonId),
              ),
              _ReloadOverlay(visible: state.activity == JourneyActivity.reloading, copy: copy),
            ],
          ),
        },
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.textSecondary),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 4)],
        Text(label),
      ],
    ),
  );
}

/// Translucent overlay with spinner, title and subtitle while reloading (200 ms fade).
class _ReloadOverlay extends StatelessWidget {
  const _ReloadOverlay({required this.visible, required this.copy});

  final bool visible;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppDurations.reloadFade,
      child: ColoredBox(
        key: const ValueKey('journey-reload-overlay'),
        color: AppColors.scrim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The spinner must not keep ticking while the overlay is hidden.
                TickerMode(enabled: visible, child: const CircularProgressIndicator()),
                const SizedBox(height: 20),
                Text(
                  copy('journey.reloading.title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  copy('journey.reloading.subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
