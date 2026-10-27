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
    final today = await SqliteDayRepository.open(localDatabase);
    final recurring = await SqliteGroupRepository.open(localDatabase);
    return LocalRepositories(
      database: localDatabase,
      today: today,
      recurring: recurring,
    );
  }
}
