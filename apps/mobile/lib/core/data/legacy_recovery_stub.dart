import 'local_repositories.dart';
import 'recovery_types.dart';

class LegacyRecovery {
  Future<RecoveryState> inspect() async => RecoveryState.normal;
  Future<LocalRepositories> open(RecoveryChoice choice) =>
      LocalRepositories.open();
}
