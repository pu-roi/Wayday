import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/domain/search_ranking.dart';

PlaceSearchResult place(
  String id,
  String name,
  double lat, {
  String? address,
  int rank = 0,
  String provider = 'geoapify',
  String? brand,
}) => PlaceSearchResult(
  name: name,
  latitude: lat,
  longitude: 121.05,
  sourceId: id,
  address: address,
  rank: rank,
  provider: provider,
  brand: brand,
);

void main() {
  const origin = SearchOrigin.device(14.58, 121.05);
  test(
    'reported jolibee query ranks nearby Jollibee before distant typo matches without brand metadata',
    () {
      final results = [
        place('makati', 'Jolibee', 14.6394),
        place('tagaytay', 'Jolibee', 15.078),
        place('tarlac-one', 'Jolibee', 15.707),
        place('tarlac-two', 'Jolibee', 15.788),
        place('near', 'Jollibee', 14.5935),
        place('next', 'Jollibee', 14.6124),
      ];
      expect(rankPlaces(results, 'jolibee', origin).map((p) => p.sourceId), [
        'near',
        'next',
        'makati',
        'tagaytay',
        'tarlac-one',
        'tarlac-two',
      ]);
    },
  );
  test(
    'Megamall alias beats tenants/sections and never creates a missing mall',
    () {
      final tenant = place('tenant', 'Megamall Building A', 14.58);
      final mall = place('mall', 'SM Megamall', 14.6);
      expect(rankPlaces([tenant, mall], 'Megamall', origin).first, mall);
      expect(rankPlaces([tenant], 'Megamall', origin), [tenant]);
    },
  );
  test('punctuation variants and branches share relevance; nearest wins', () {
    final far = place('far', "McDonald's", 14.7);
    final near = place('near', 'McDonald’s Ortigas', 14.581);
    for (final query in ["McDonald's", 'McDonalds', 'McDonald’s']) {
      expect(rankPlaces([far, near], query, origin).first, near);
    }
    expect(near.name, 'McDonald’s Ortigas');
  });
  test('explicit locality beats proximity and unrelated near names', () {
    final nearby = place('near', "McDonald's Ortigas", 14.58, address: 'Pasig');
    final bgc = place('bgc', "McDonald's", 14.5, address: 'BGC, Taguig');
    expect(rankPlaces([nearby, bgc], "McDonald's BGC", origin).first, bgc);
    final exact = place('exact', 'Rizal Street', 14.7);
    final partial = place('partial', 'Rizal Street Cafe', 14.58);
    expect(rankPlaces([partial, exact], 'Rizal Street', origin).first, exact);
  });
  test(
    'Jollibee branches without metadata share relevance and explicit qualifiers still win',
    () {
      final nearby = place('near', 'Jollibee Ortigas', 14.581);
      final far = place('far', 'Jollibee', 14.7, address: 'BGC, Taguig');
      for (final query in ['jolibee', 'Jollibee']) {
        expect(rankPlaces([far, nearby], query, origin).first, nearby);
      }
      expect(rankPlaces([nearby, far], 'jolibee BGC', origin).first, far);
    },
  );
  test(
    'provider-supplied brands support nearby branches beyond the seed aliases',
    () {
      final far = place('far', 'Jollibee', 14.7, brand: 'Jollibee');
      final near = place('near', 'Jollibee Ortigas', 14.581, brand: 'Jollibee');
      expect(rankPlaces([far, near], 'Jollibee', origin).first, near);
    },
  );
  test(
    'approximate distances use uncertainty buckets and deterministic ties',
    () {
      final one = place('one', 'Branch', 14.581, provider: 'locationiq');
      final two = place('two', 'Branch', 14.582);
      const approximate = SearchOrigin.device(
        14.58,
        121.05,
        approximate: true,
        accuracy: 3000,
      );
      expect(rankPlaces([one, two], 'Branch', approximate).first, two);
      expect(rankPlaces([two, one], 'Branch', approximate).first, two);
      expect(
        searchDistanceLabel(one, approximate),
        'Near your approximate location',
      );
      expect(searchDistanceLabel(one, origin), contains('straight-line'));
      expect(
        searchDistanceLabel(
          one,
          SearchOrigin.map(const SearchArea(14.58, 121.05, 14)),
        ),
        contains('map center'),
      );
    },
  );
}
