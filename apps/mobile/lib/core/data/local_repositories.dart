import '../../features/recurring/data/group_repository.dart';
import '../../features/today/data/day_repository.dart';
import '../../features/places/data/saved_place_repository.dart';
import 'wayday_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localRepositoriesProvider = Provider<LocalRepositories?>((ref) => null);
final savedPlaceRepositoryProvider = Provider<SavedPlaceRepository?>(
  (ref) => ref.watch(localRepositoriesProvider)?.savedPlaces,
);

class LocalRepositories {
  const LocalRepositories({
    required this.database,
    required this.today,
    required this.recurring,
    required this.savedPlaces,
  });

  final WaydayDatabase database;
  final SqliteDayRepository today;
  final SqliteGroupRepository recurring;
  final SavedPlaceRepository savedPlaces;

  static Future<LocalRepositories> open({WaydayDatabase? database}) async {
    final localDatabase = database ?? WaydayDatabase();
    final today = await SqliteDayRepository.open(localDatabase);
    final recurring = await SqliteGroupRepository.open(localDatabase);
    return LocalRepositories(
      database: localDatabase,
      today: today,
      recurring: recurring,
      savedPlaces: SqliteSavedPlaceRepository(localDatabase),
    );
  }
}
