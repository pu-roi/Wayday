import '../../features/recurring/data/group_repository.dart';
import '../../features/today/data/day_repository.dart';
import 'wayday_database.dart';

class LocalRepositories {
  const LocalRepositories({
    required this.database,
    required this.today,
    required this.recurring,
  });

  final WaydayDatabase database;
  final SqliteDayRepository today;
  final SqliteGroupRepository recurring;

  static Future<LocalRepositories> open({WaydayDatabase? database}) async {
    final localDatabase = database ?? WaydayDatabase();
    final savedSettings = await localDatabase
        .select(localDatabase.daySettings)
        .getSingleOrNull();
    final isFirstLaunch = savedSettings == null;
    late final SqliteDayRepository today;
    late final SqliteGroupRepository recurring;
    if (isFirstLaunch) {
      recurring = await SqliteGroupRepository.open(
        localDatabase,
        initialData: exampleGroups(),
      );
      today = await SqliteDayRepository.open(
        localDatabase,
        initialData: exampleDay(),
      );
    } else {
      today = await SqliteDayRepository.open(localDatabase, initialData: null);
      recurring = await SqliteGroupRepository.open(
        localDatabase,
        initialData: null,
      );
    }
    return LocalRepositories(
      database: localDatabase,
      today: today,
      recurring: recurring,
    );
  }
}
