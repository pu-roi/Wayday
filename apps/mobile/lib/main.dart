import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/wayday_app.dart';
import 'core/data/local_repositories.dart';
import 'features/recurring/presentation/recurring_controller.dart';
import 'features/today/presentation/today_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    runApp(const ProviderScope(child: WaydayApp()));
    return;
  }

  final repositories = await LocalRepositories.open();
  runApp(
    ProviderScope(
      overrides: [
        dayRepositoryProvider.overrideWithValue(repositories.today),
        groupRepositoryProvider.overrideWithValue(repositories.recurring),
      ],
      child: const WaydayApp(),
    ),
  );
}
