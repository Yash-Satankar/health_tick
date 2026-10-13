import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/app_config/domain/bootstrap.dart';
import '../../features/app_config/presentation/app_config_cubit.dart';
import 'app_copy.dart';

extension CopyContext on BuildContext {
  /// UI copy from the API (rebuilds when the app config changes).
  AppCopy get copy => select<AppConfigCubit, AppCopy>((cubit) => cubit.state.copy);

  /// UI copy without subscribing (for callbacks).
  AppCopy get readCopy => read<AppConfigCubit>().state.copy;

  Bootstrap? get bootstrap => select<AppConfigCubit, Bootstrap?>((cubit) => cubit.state.bootstrapOrNull);
}
