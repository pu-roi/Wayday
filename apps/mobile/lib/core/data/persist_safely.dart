import 'package:flutter/foundation.dart';

Future<void> persistSafely(
  Future<void> operation, {
  required String label,
}) async {
  try {
    await operation;
  } catch (error, stackTrace) {
    debugPrint('Could not save $label locally: $error\n$stackTrace');
  }
}
