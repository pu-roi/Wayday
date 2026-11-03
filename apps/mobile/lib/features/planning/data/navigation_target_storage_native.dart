import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> _file() async => File(
  '${(await getApplicationCacheDirectory()).path}/trip-navigation-targets.json',
);
Future<String?> readTargets() async {
  final file = await _file();
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeTargets(String value) async {
  final file = await _file();
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.pending');
  await temporary.writeAsString(value, flush: true);
  await temporary.rename(file.path);
}
