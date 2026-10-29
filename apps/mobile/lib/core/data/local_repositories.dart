import '../../features/places/data/google_pin_cache.dart';
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
    this.googlePins,
  });

  final GooglePinCache? googlePins;
  final WaydayDatabase database;
  final SqliteDayRepository today;
  final SqliteGroupRepository recurring;
  final SavedPlaceRepository savedPlaces;

  static Future<LocalRepositories> open({
    WaydayDatabase? database,
    GooglePinCache? googlePins,
  }) async {
    final localDatabase = database ?? WaydayDatabase();
    final pins = googlePins ?? GooglePinCache();
    await pins.load();
    final today = await SqliteDayRepository.open(
      localDatabase,
      resolveGooglePin: pins.lease,
    );
    final recurring = await SqliteGroupRepository.open(
      localDatabase,
      resolveGooglePin: pins.lease,
    );
    return LocalRepositories(
      database: localDatabase,
      today: today,
      recurring: recurring,
      savedPlaces: SqliteSavedPlaceRepository(
        localDatabase,
        resolveGooglePin: pins.lease,
      ),
      googlePins: pins,
    );
  }
}
