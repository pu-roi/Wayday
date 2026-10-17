import 'package:wayday/features/places/data/place_search_repository.dart';

class TestPlaceSearch implements PlaceSearchRepository {
  const TestPlaceSearch();
  @override
  Future<List<PlaceResult>> search(String query) async => [];
  @override
  Future<List<PlaceResult>> nearby(double latitude, double longitude) async => [];
}
