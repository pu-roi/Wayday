import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final saveFailuresProvider =
    NotifierProvider<SaveFailures, Map<String, VoidCallback>>(SaveFailures.new);

class SaveFailures extends Notifier<Map<String, VoidCallback>> {
  @override
  Map<String, VoidCallback> build() => {};
  void failed(String label, VoidCallback retry) =>
      state = {...state, label: retry};
  void saved(String label) {
    if (!state.containsKey(label)) return;
    state = {...state}..remove(label);
  }
}

Future<void> persistSafely(
  Future<void> operation, {
  required String label,
  VoidCallback? onFailure,
  VoidCallback? onSuccess,
}) async {
  try {
    await operation;
    onSuccess?.call();
  } catch (error, stackTrace) {
    debugPrint('Could not save $label locally: $error\n$stackTrace');
    onFailure?.call();
  }
}
