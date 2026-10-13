import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../home/presentation/bloc/home_cubit.dart';
import '../../journey/domain/journey.dart';
import '../../journey/presentation/bloc/journey_cubit.dart';
import '../domain/lesson_exit.dart';

/// Opens the lesson player and, on return, refreshes Home and the Journey. Unless the node is a
/// checkpoint, the Journey reopens that node's popover; a newly unlocked node is pulsed (SPEC §8.3, §9.6).
Future<LessonExit?> openLesson(BuildContext context, String lessonId) async {
  final journeyCubit = context.read<JourneyCubit>();
  final homeCubit = context.read<HomeCubit>();
  final exit = await context.push<LessonExit>(AppRoutes.lesson(lessonId));
  homeCubit.refresh();
  await journeyCubit.silentRefresh();
  if (exit != null) {
    final node = journeyCubit.state.journeyOrNull?.nodeById(exit.nodeId);
    if (node != null && node.type != NodeType.checkpoint) journeyCubit.selectNode(exit.nodeId);
    if (exit.unlockedNodeId != null) journeyCubit.pulse(exit.unlockedNodeId);
  }
  return exit;
}
