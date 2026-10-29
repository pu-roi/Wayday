import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> _file() async => File(
  '${(await getApplicationSupportDirectory()).path}/search-accounting.json',
);
Future<String?> readQuotaFile() async {
  final file = await _file();
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeQuotaFile(String content) async {
  final file = await _file();
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.pending');
  await temporary.writeAsString(content, flush: true);
  await temporary.rename(file.path);
}
