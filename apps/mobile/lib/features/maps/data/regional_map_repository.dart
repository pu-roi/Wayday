import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final regionalMapRepositoryProvider = Provider(
  (ref) => RegionalMapRepository(),
);
final regionalMapPackageProvider = FutureProvider<RegionalMapPackage>(
  (ref) => ref.watch(regionalMapRepositoryProvider).load(),
  retry: (count, error) => null,
);
final regionalMapCreditsProvider = FutureProvider<RegionalMapCredits>(
  (ref) => ref.watch(regionalMapRepositoryProvider).loadCredits(),
  retry: (count, error) => null,
);

class RegionalMapCredits {
  const RegionalMapCredits({
    this.region,
    this.sourceDate,
    required this.notices,
  });
  final String? region;
  final String? sourceDate;
  final String notices;
}

class MapPackageException implements Exception {
  const MapPackageException();
  @override
  String toString() => 'The regional map package is missing or invalid.';
}

class RegionalMapPackage {
  const RegionalMapPackage({
    required this.region,
    required this.style,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.sourceDate,
    required this.notices,
  });
  final String region;
  final String style;
  final List<double> bounds;
  final double minZoom;
  final double maxZoom;
  final String sourceDate;
  final String notices;
}

/// Validates the complete bundled package before passing local URLs to native code.
/// This cache is separate from personal task storage and never writes task data.
class RegionalMapRepository {
  RegionalMapRepository({
    AssetBundle? bundle,
    this.assetRoot = 'assets/maps/pilot',
  }) : bundle = bundle ?? rootBundle;
  final AssetBundle bundle;
  final String assetRoot;
  Future<RegionalMapPackage>? _loaded;
  static const noticeFiles = [
    'NOTICES.txt',
    'Noto-OFL.txt',
    'Protomaps-Scripts-BSD.txt',
    'Tangram-Icons-MIT.txt',
    'Upstream-Assets-README.md',
  ];
  Future<RegionalMapCredits> loadCredits() async {
    String? region;
    String? sourceDate;
    try {
      final manifest = jsonDecode(
        await bundle.loadString('$assetRoot/manifest.json'),
      );
      if (manifest is Map<String, dynamic>) {
        if (manifest['region'] is String) region = manifest['region'] as String;
        if (manifest['sourceDate'] is String &&
            DateTime.tryParse(manifest['sourceDate'] as String) != null) {
          sourceDate = manifest['sourceDate'] as String;
        }
      }
    } catch (_) {
      // Notices can still be read when the map manifest is unavailable.
    }
    final notices = <String>[];
    for (final name in noticeFiles) {
      notices.add(
        '$name\n${await bundle.loadString('$assetRoot/notices/$name')}',
      );
    }
    return RegionalMapCredits(
      region: region,
      sourceDate: sourceDate,
      notices: notices.join('\n\n'),
    );
  }

  Future<RegionalMapPackage> load() => _loaded ??= _load();

  bool _safePath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains(RegExp(r'[\\:{}?#]')) &&
      !path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..');

  Future<RegionalMapPackage> _load() async {
    try {
      final manifest =
          jsonDecode(await bundle.loadString('$assetRoot/manifest.json'))
              as Map<String, dynamic>;
      final bounds = (manifest['boundsWestSouthEastNorth'] as List)
          .map((v) => (v as num).toDouble())
          .toList();
      final minZoom = (manifest['minZoom'] as num).toDouble();
      final maxZoom = (manifest['maxZoom'] as num).toDouble();
      if (manifest['formatVersion'] != 1 ||
          manifest['id'] is! String ||
          manifest['region'] is! String ||
          manifest['sourceSnapshot'] is! String ||
          manifest['tileSchema'] != 'Protomaps 4.15.2' ||
          DateTime.tryParse(manifest['sourceDate'] as String) == null ||
          bounds.length != 4 ||
          bounds.any((v) => !v.isFinite) ||
          bounds[0] < -180 ||
          bounds[2] > 180 ||
          bounds[1] < -85.051129 ||
          bounds[3] > 85.051129 ||
          bounds[0] >= bounds[2] ||
          bounds[1] >= bounds[3] ||
          !minZoom.isFinite ||
          !maxZoom.isFinite ||
          minZoom < 0 ||
          maxZoom > 22 ||
          minZoom > maxZoom) {
        throw const MapPackageException();
      }
      final files = <String, Uint8List>{};
      for (final item in manifest['files'] as List) {
        final path = item['path'] as String;
        if (!_safePath(path) || files.containsKey(path)) {
          throw const MapPackageException();
        }
        final data = await bundle.load('$assetRoot/$path');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (bytes.length != item['bytes'] ||
            sha256.convert(bytes).toString() != item['sha256']) {
          throw const MapPackageException();
        }
        files[path] = bytes;
      }
      final archiveFile = manifest['archiveFile'] as String;
      final styleFile = manifest['styleFile'] as String;
      if (!_safePath(archiveFile) || !_safePath(styleFile)) {
        throw const MapPackageException();
      }
      final archive = files[archiveFile]!;
      if (archive.length < 127 ||
          ascii.decode(archive.take(7).toList()) != 'PMTiles' ||
          archive[7] != 3 ||
          archive[97] != 2 ||
          archive[98] != 2 ||
          archive[99] != 1 ||
          archive[100] != minZoom ||
          archive[101] != maxZoom) {
        throw const MapPackageException();
      }
      final header = ByteData.sublistView(archive);
      for (var i = 0; i < 4; i++) {
        if ((header.getInt32(102 + i * 4, Endian.little) / 1e7 - bounds[i])
                .abs() >
            0.0000001) {
          throw const MapPackageException();
        }
      }
      final style =
          jsonDecode(utf8.decode(files[styleFile]!)) as Map<String, dynamic>;
      final sources = style['sources'] as Map<String, dynamic>;
      if (style['version'] != 8 ||
          sources.length != 1 ||
          sources['protomaps']['type'] != 'vector' ||
          sources['protomaps']['url'] !=
              'pmtiles://__PACKAGE_ROOT__/$archiveFile' ||
          sources['protomaps']['tiles'] != null ||
          style['imports'] != null ||
          style['glyphs'] != '__PACKAGE_ROOT__/fonts/{fontstack}/{range}.pbf' ||
          style['sprite'] != '__PACKAGE_ROOT__/sprites/light' ||
          (style['layers'] as List).isEmpty) {
        throw const MapPackageException();
      }
      for (final suffix in ['.json', '.png', '@2x.json', '@2x.png']) {
        if (!files.containsKey('sprites/light$suffix')) {
          throw const MapPackageException();
        }
      }
      for (var start = 0; start < 65536; start += 256) {
        if (!files.containsKey(
          'fonts/NotoSansRegular/$start-${start + 255}.pbf',
        )) {
          throw const MapPackageException();
        }
      }
      // Resource fields are allowlisted above; attribution hyperlinks are legal references.
      for (final layer in style['layers'] as List) {
        if (layer['source'] != null && layer['source'] != 'protomaps') {
          throw const MapPackageException();
        }
        final fonts = layer['layout']?['text-font'];
        if (fonts != null && jsonEncode(fonts) != '["NotoSansRegular"]') {
          throw const MapPackageException();
        }
      }
      final notices = noticeFiles
          .map((name) => '$name\n${utf8.decode(files['notices/$name']!)}')
          .join('\n\n');
      return RegionalMapPackage(
        region: manifest['region'] as String,
        style: jsonEncode(
          style,
        ).replaceAll('__PACKAGE_ROOT__', 'asset://flutter_assets/$assetRoot'),
        bounds: List.unmodifiable(bounds),
        minZoom: minZoom,
        maxZoom: maxZoom,
        sourceDate: manifest['sourceDate'] as String,
        notices: notices,
      );
    } catch (_) {
      throw const MapPackageException();
    }
  }
}
