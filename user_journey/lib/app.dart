import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/router.dart';
import 'core/theme/theme.dart';
import 'di.dart';
import 'features/app_config/presentation/app_config_cubit.dart';
import 'features/home/presentation/bloc/home_cubit.dart';
import 'features/journey/presentation/bloc/journey_cubit.dart';

class HealthTickApp extends StatefulWidget {
  const HealthTickApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<HealthTickApp> createState() => _HealthTickAppState();
}

class _HealthTickAppState extends State<HealthTickApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<AppConfigCubit>()..load()),
        BlocProvider.value(value: sl<HomeCubit>()),
        BlocProvider.value(value: sl<JourneyCubit>()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      ),
    );
  }
}
