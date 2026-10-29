import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> _file() async => File(
  '${(await getApplicationSupportDirectory()).path}/planning-accounting.json',
);
Future<String?> readPlanningBudget() async {
  final f = await _file();
  return await f.exists() ? f.readAsString() : null;
}

Future<void> writePlanningBudget(String value) async {
  final f = await _file();
  await f.parent.create(recursive: true);
  final pending = File('${f.path}.pending');
  await pending.writeAsString(value, flush: true);
  await pending.rename(f.path);
}
