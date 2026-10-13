import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_journey/core/copy/app_copy.dart';
import 'package:user_journey/core/error/app_exception.dart';
import 'package:user_journey/core/error/failure.dart';
import 'package:user_journey/features/app_config/data/bootstrap_dto.dart';
import 'package:user_journey/features/app_config/domain/bootstrap.dart';
import 'package:user_journey/features/app_config/presentation/app_config_cubit.dart';

class MockAppConfigRepository extends Mock implements AppConfigRepository {}

const bootstrapJson = {
  'contentVersion': 42,
  'user': {'id': 'u', 'displayName': 'Yash', 'healthPointsTotal': 37},
  'copy': {'journey.title': 'Your Journey'},
  'assets': {
    'lockedNode': {
      'url': '/static/assets/node_locked.png',
      'width': 114,
      'height': 114,
      'alt': 'Locked',
      'format': 'png',
    },
    'completionMedal': {'url': '/static/assets/ui_completion_medal.png'},
  },
  'feedbackReasons': [
    {'id': 'r1', 'key': 'others', 'label': 'Others', 'requiresText': true},
  ],
};

void main() {
  test('BootstrapDto parses the contract and maps to the domain', () {
    final b = BootstrapDto.fromJson(bootstrapJson).toDomain();
    expect(b.displayName, 'Yash');
    expect(b.copy('journey.title'), 'Your Journey');
    expect(b.lockedNodeAsset?.width, 114);
    expect(b.feedbackReasons.single.requiresText, isTrue);
  });

  test('BootstrapDto rejects a malformed payload', () {
    expect(() => BootstrapDto.fromJson({'contentVersion': 'x'}), throwsA(anything));
  });

  test('AppCopy falls back only for error keys', () {
    expect(AppCopy.empty('error.retry'), 'Retry');
    expect(AppCopy.empty('journey.title'), '');
  });

  group('AppConfigCubit', () {
    late MockAppConfigRepository repo;
    final bootstrap = BootstrapDto.fromJson(bootstrapJson).toDomain();
    setUp(() => repo = MockAppConfigRepository());

    blocTest<AppConfigCubit, AppConfigState>(
      'loading → ready',
      setUp: () => when(() => repo.bootstrap()).thenAnswer((_) async => bootstrap),
      build: () => AppConfigCubit(repo),
      act: (cubit) => cubit.load(),
      expect: () => [const AppConfigState.loading(), AppConfigState.ready(bootstrap)],
    );

    blocTest<AppConfigCubit, AppConfigState>(
      'loading → failure',
      setUp: () => when(() => repo.bootstrap()).thenThrow(const AppException(NetworkFailure())),
      build: () => AppConfigCubit(repo),
      act: (cubit) => cubit.load(),
      expect: () => [const AppConfigState.loading(), const AppConfigState.failure(NetworkFailure())],
    );

    blocTest<AppConfigCubit, AppConfigState>(
      'a failed reload keeps the loaded config',
      setUp: () => when(() => repo.bootstrap()).thenThrow(const AppException(TimeoutFailure())),
      build: () => AppConfigCubit(repo),
      seed: () => AppConfigState.ready(bootstrap),
      act: (cubit) => cubit.load(),
      expect: () => <AppConfigState>[],
    );
  });
}
