import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/network/sse_client.dart';
import 'core/routing/router.dart';
import 'core/sync/content_sync_service.dart';
import 'core/theme/theme.dart';
import 'core/theme/tokens.dart';
import 'di.dart';
import 'features/app_config/presentation/app_config_cubit.dart';
import 'features/home/presentation/bloc/home_cubit.dart';
import 'features/journey/presentation/bloc/journey_cubit.dart';

/// Messenger for app-level toasts that are not tied to a screen (e.g. "Your journey was updated").
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class HealthTickApp extends StatefulWidget {
  const HealthTickApp({super.key, this.router, this.enableContentSync = true});

  final GoRouter? router;
  final bool enableContentSync;

  @override
  State<HealthTickApp> createState() => _HealthTickAppState();
}

class _HealthTickAppState extends State<HealthTickApp> {
  late final GoRouter _router = widget.router ?? buildRouter();
  ContentSyncService? _sync;

  @override
  void initState() {
    super.initState();
    sl<AppConfigCubit>().load();
    if (widget.enableContentSync) {
      _sync = ContentSyncService(
        connect: () => sl<SseClient>().connect(),
        targets: ContentSyncTargets(
          refreshJourney: () => sl<JourneyCubit>().silentRefresh(),
          refreshHome: () => sl<HomeCubit>().refresh(),
          reloadAppConfig: () => sl<AppConfigCubit>().load(),
          isJourneyVisible: () => JourneyVisibility.instance.visible,
          showUpdatedToast: _showUpdatedToast,
        ),
      )..start();
    }
  }

  void _showUpdatedToast() {
    final text = sl<AppConfigCubit>().state.copy('journey.updated.toast');
    appMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: const TextStyle(color: AppColors.textPrimary)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        ),
      );
  }

  @override
  void dispose() {
    _sync?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<AppConfigCubit>()),
        BlocProvider.value(value: sl<HomeCubit>()),
        BlocProvider.value(value: sl<JourneyCubit>()),
      ],
      child: MaterialApp.router(
        title: 'HealthTick',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: appMessengerKey,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}
