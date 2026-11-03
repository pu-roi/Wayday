import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/network/gateway_client.dart';
import 'package:wayday/features/planning/data/alternative_route_client.dart';
import 'package:wayday/features/planning/data/navigation_target_resolver.dart';
import 'package:wayday/features/places/data/search_quota.dart';

void main() {
  test('ordinary public builds enable shared navigation without test identity', () {
    expect(const bool.fromEnvironment('WAYDAY_PUBLIC_TEST'), isFalse);
    expect(GatewayClient.enabled, isTrue);
    expect(AlternativeRouteClient().enabled, isTrue);
    expect(uiKitNavigationTargetsEnabled, isTrue);
    expect(QuotaLedger().enforceDaily, isFalse);
  });
}
