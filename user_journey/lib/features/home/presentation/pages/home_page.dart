import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/copy/copy_context.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/toast.dart';
import '../../../lesson/presentation/open_lesson.dart';
import '../../domain/home.dart';
import '../bloc/home_cubit.dart';

/// Minimal Home (SPEC §9.2): avatar, streak, health points, today's task and the JOURNEY link.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<HomeCubit>();
    if (cubit.state is! HomeReady) cubit.load();
  }

  Future<void> _openJourney() async {
    await context.push(AppRoutes.journey);
    if (mounted) context.read<HomeCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<HomeCubit, HomeState>(
          listenWhen: (previous, current) =>
              current is HomeReady &&
              current.refreshError != null &&
              current.errorId != (previous is HomeReady ? previous.errorId : -1),
          listener: (context, state) {
            final failure = (state as HomeReady).refreshError!;
            showToast(context, copy(failure.messageKey));
          },
          builder: (context, state) => switch (state) {
            HomeLoading() => const _HomeSkeleton(),
            HomeFailure(:final failure) => ErrorView(
              failure: failure,
              copy: copy,
              onRetry: () => context.read<HomeCubit>().load(),
            ),
            HomeReady(:final data) => RefreshIndicator(
              onRefresh: () => context.read<HomeCubit>().refresh(),
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.gutter),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _Header(data: data),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copy('home.today_task.title'),
                          style: const TextStyle(fontSize: AppSizes.headingFont, fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('home-journey-link'),
                        onPressed: _openJourney,
                        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              copy('home.today_task.journey_link'),
                              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TaskCard(
                    task: data.todayTask,
                    allDoneText: copy('home.today_task.all_done'),
                    onTap: () =>
                        data.todayTask == null ? _openJourney() : openLesson(context, data.todayTask!.lessonId),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final initial = data.displayName.isEmpty ? '' : data.displayName.characters.first.toUpperCase();
    return Row(
      children: [
        Semantics(
          label: copy('home.header.profile'),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surface,
            child: Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
        ),
        const Spacer(),
        _Stat(
          key: const ValueKey('home-streak'),
          icon: Icons.local_fire_department_rounded,
          color: AppColors.streak,
          value: data.streakDays,
          label: copy('home.header.streak'),
        ),
        const SizedBox(width: 20),
        _Stat(
          key: const ValueKey('home-health-points'),
          icon: Icons.monitor_heart_rounded,
          color: AppColors.healthAccent,
          value: data.healthPointsTotal,
          label: copy('home.header.health_points'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 6),
        Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.allDoneText, required this.onTap});

  final TodayTask? task;
  final String allDoneText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('home-task-card'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task != null) ...[
                      Text(task!.statusTitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      task?.lessonTitle ?? allDoneText,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded, size: 40, color: AppColors.buttonFill),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton: grey placeholders in the Home layout.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double w, double h, {double r = 8}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(r)),
    );
    return Padding(
      key: const ValueKey('home-skeleton'),
      padding: const EdgeInsets.all(AppSizes.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [box(44, 44, r: 22), const Spacer(), box(56, 24), const SizedBox(width: 20), box(56, 24)]),
          const SizedBox(height: 32),
          box(160, 26),
          const SizedBox(height: 16),
          box(double.infinity, 96, r: 16),
        ],
      ),
    );
  }
}
