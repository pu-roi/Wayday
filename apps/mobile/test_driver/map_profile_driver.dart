import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final output = File(
      '../../.tools/map-profile-${data?['variant'] ?? 'unknown'}.json',
    );
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    final adb =
        '${Platform.environment['LOCALAPPDATA']}/Android/Sdk/platform-tools/adb.exe';
    final frames = await Process.run(adb, [
      '-s',
      Platform.environment['WAYDAY_PROFILE_DEVICE'] ?? 'emulator-5554',
      'shell',
      'dumpsys',
      'gfxinfo',
      'dev.wayday.wayday.maptest',
      'framestats',
    ]);
    await File(
      '../../.tools/map-profile-${data?['variant'] ?? 'unknown'}-gfxinfo.txt',
    ).writeAsString(frames.stdout as String);
  },
);
