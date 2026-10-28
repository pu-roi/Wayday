import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/widgets/place_picker.dart';
import 'package:wayday/app/settings_view.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/data/regional_map_repository.dart';
import 'package:wayday/features/maps/presentation/regional_map.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';

class TestMapBundle extends CachingAssetBundle {
  TestMapBundle(this.files);
  final Map<String, Uint8List> files;
  int reads = 0;
  @override
  Future<ByteData> load(String key) async {
    reads++;
    final value = files[key];
    if (value == null) throw FlutterError('Missing asset');
    return ByteData.sublistView(value);
  }
}

TestMapBundle packageBundle({bool remote = false}) {
  final archive = Uint8List(127)..setAll(0, [...ascii.encode('PMTiles'), 3]);
  archive[97] = 2;
  archive[98] = 2;
  archive[99] = 1;
  archive[101] = 15;
  final header = ByteData.sublistView(archive);
  final bounds = [121.045, 14.548, 121.116, 14.617];
  for (var i = 0; i < 4; i++) {
    header.setInt32(102 + i * 4, (bounds[i] * 1e7).round(), Endian.little);
  }
  final resources = <String, Uint8List>{
    'pilot.pmtiles': archive,
    'style.json': Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 8,
          'glyphs': '__PACKAGE_ROOT__/fonts/{fontstack}/{range}.pbf',
          'sprite': remote
              ? 'https://example.com/sprite'
              : '__PACKAGE_ROOT__/sprites/light',
          'sources': {
            'protomaps': {
              'type': 'vector',
              'url': 'pmtiles://__PACKAGE_ROOT__/pilot.pmtiles',
            },
          },
          'layers': [
            {'id': 'background', 'type': 'background'},
          ],
        }),
      ),
    ),
    for (var start = 0; start < 65536; start += 256)
      'fonts/NotoSansRegular/$start-${start + 255}.pbf': Uint8List.fromList([
        1,
      ]),
    for (final suffix in ['.json', '.png', '@2x.json', '@2x.png'])
      'sprites/light$suffix': Uint8List.fromList([1]),
    for (final name in RegionalMapRepository.noticeFiles)
      'notices/$name': Uint8List.fromList(utf8.encode('License $name')),
  };
  final manifest = {
    'formatVersion': 1,
    'id': 'test',
    'region': 'Test region',
    'boundsWestSouthEastNorth': [121.045, 14.548, 121.116, 14.617],
    'minZoom': 0,
    'maxZoom': 15,
    'sourceDate': '2026-10-26',
    'sourceSnapshot': '2026-10-26T04:00:00Z',
    'styleFile': 'style.json',
    'archiveFile': 'pilot.pmtiles',
    'tileSchema': 'Protomaps 4.15.2',
    'files': [
      for (final entry in resources.entries)
        {
          'path': entry.key,
          'bytes': entry.value.length,
          'sha256': sha256.convert(entry.value).toString(),
        },
    ],
  };
  return TestMapBundle({
    for (final entry in resources.entries) 'test/${entry.key}': entry.value,
    'test/manifest.json': Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
  });
}

void main() {
  test(
    'valid local package verifies once and resolves only bundled resources',
    () async {
      final bundle = packageBundle();
      final repository = RegionalMapRepository(
        bundle: bundle,
        assetRoot: 'test',
      );
      final package = await repository.load();
      final reads = bundle.reads;
      expect(await repository.load(), same(package));
      expect(bundle.reads, reads);
      expect(
        package.style,
        contains('pmtiles://asset://flutter_assets/test/pilot.pmtiles'),
      );
      expect(package.notices, contains('Noto-OFL.txt'));
    },
  );
  test('missing, corrupt, unsafe and remote packages fail honestly', () async {
    final missing = TestMapBundle({});
    await expectLater(
      RegionalMapRepository(bundle: missing, assetRoot: 'test').load(),
      throwsA(isA<MapPackageException>()),
    );
    final corrupt = packageBundle();
    corrupt.files['test/pilot.pmtiles']![0] = 0;
    await expectLater(
      RegionalMapRepository(bundle: corrupt, assetRoot: 'test').load(),
      throwsA(isA<MapPackageException>()),
    );
    await expectLater(
      RegionalMapRepository(
        bundle: packageBundle(remote: true),
        assetRoot: 'test',
      ).load(),
      throwsA(isA<MapPackageException>()),
    );
    final unsafe = packageBundle();
    final manifest = jsonDecode(
      utf8.decode(unsafe.files['test/manifest.json']!),
    );
    manifest['files'][0]['path'] = '../outside';
    unsafe.files['test/manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    );
    await expectLater(
      RegionalMapRepository(bundle: unsafe, assetRoot: 'test').load(),
      throwsA(isA<MapPackageException>()),
    );
  });
  test(
    'omitted glyph inventory and wrong-region headers are rejected',
    () async {
      for (final change in ['glyph', 'bounds']) {
        final bundle = packageBundle();
        final manifest = jsonDecode(
          utf8.decode(bundle.files['test/manifest.json']!),
        );
        if (change == 'glyph') {
          (manifest['files'] as List).removeWhere(
            (entry) => entry['path'] == 'fonts/NotoSansRegular/256-511.pbf',
          );
        } else {
          manifest['boundsWestSouthEastNorth'][0] = 121.046;
        }
        bundle.files['test/manifest.json'] = Uint8List.fromList(
          utf8.encode(jsonEncode(manifest)),
        );
        await expectLater(
          RegionalMapRepository(bundle: bundle, assetRoot: 'test').load(),
          throwsA(isA<MapPackageException>()),
        );
      }
    },
  );
  testWidgets(
    'unavailable map preserves label saving and Back cancellation at large text',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapPlatformSupportedProvider.overrideWithValue(true),
            placeMapBuilderProvider.overrideWithValue(
              (_) => const Text('Online map unavailable'),
            ),
            regionalMapPackageProvider.overrideWith(
              (ref) => RegionalMapRepository(
                bundle: TestMapBundle({}),
                assetRoot: 'test',
              ).load(),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const SizedBox(height: 300, child: RegionalMap()),
                    TextButton(
                      onPressed: () async {
                        result = (await choosePlace(
                          context,
                          title: 'From',
                          initial: 'Original',
                        ))?.label;
                      },
                      child: const Text('Choose'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Map unavailable'), findsOneWidget);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('place-name')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('place-name')), 'Changed');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('place-name')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Original'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('place-name')),
        'Manual place',
      );
      await tester.ensureVisible(find.text('Use name only'));
      await tester.tap(find.text('Use name only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(result, 'Manual place');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('ready renderer keeps accessible local credits outside the map', (
    tester,
  ) async {
    final package = await RegionalMapRepository(
      bundle: packageBundle(),
      assetRoot: 'test',
    ).load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapPlatformSupportedProvider.overrideWithValue(true),
          regionalMapRepositoryProvider.overrideWithValue(
            RegionalMapRepository(bundle: packageBundle(), assetRoot: 'test'),
          ),
          regionalMapPackageProvider.overrideWithValue(AsyncData(package)),
          regionalMapRendererProvider.overrideWithValue(
            (context, package, ready) => Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) => ready());
                return const ColoredBox(
                  color: Colors.blue,
                  key: Key('test-map-renderer'),
                );
              },
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: RegionalMap())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-map-renderer')), findsOneWidget);
    expect(find.text('Loading map…'), findsNothing);
    expect(
      find.text('© OpenStreetMap contributors · Protomaps'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.text('© OpenStreetMap contributors · Protomaps'),
    );
    await tester.tap(find.text('© OpenStreetMap contributors · Protomaps'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noto-OFL.txt'), findsOneWidget);
    expect(find.textContaining('Tangram-Icons-MIT.txt'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });
  testWidgets(
    'settings credits work without a map and report missing notices',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bundle = packageBundle();
      bundle.files.remove('test/pilot.pmtiles');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            regionalMapRepositoryProvider.overrideWithValue(
              RegionalMapRepository(bundle: bundle, assetRoot: 'test'),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const SettingsView(),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Map credits and licenses'),
        200,
      );
      await tester.ensureVisible(find.text('Map credits and licenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map credits and licenses'));
      await tester.pumpAndSettle();
      expect(find.text('Test region'), findsOneWidget);
      expect(find.text('Source 2026-10-26'), findsOneWidget);
      expect(find.textContaining('Noto-OFL.txt'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final missingBundle = TestMapBundle(Map.of(bundle.files))
        ..files.remove('test/notices/Noto-OFL.txt');
      // A fresh provider scope forces the failed asset load to be retried.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            regionalMapRepositoryProvider.overrideWithValue(
              RegionalMapRepository(bundle: missingBundle, assetRoot: 'test'),
            ),
          ],
          child: MaterialApp(theme: buildTheme(), home: const SettingsView()),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Map credits and licenses'),
        200,
      );
      await tester.ensureVisible(find.text('Map credits and licenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map credits and licenses'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Offline map credits and licenses are unavailable on this device.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'blank native renderer expires without preventing manual label entry',
    (tester) async {
      final package = await RegionalMapRepository(
        bundle: packageBundle(),
        assetRoot: 'test',
      ).load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapPlatformSupportedProvider.overrideWithValue(true),
            regionalMapPackageProvider.overrideWithValue(AsyncData(package)),
            regionalMapRendererProvider.overrideWithValue(
              (context, package, ready) => const SizedBox(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: RegionalMap())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Map unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PlacePicker(title: 'From', initial: 'Original'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('place-name')),
        'Still editable',
      );
      expect(find.text('Still editable'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'unsupported platform does not load a package or native renderer',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapPlatformSupportedProvider.overrideWithValue(false),
            regionalMapPackageProvider.overrideWith(
              (ref) => throw StateError('must not load'),
            ),
            regionalMapRendererProvider.overrideWithValue(
              (context, package, ready) => throw StateError('must not render'),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: RegionalMap())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Map available on Android'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
