import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'app/wayday_app.dart';
import 'app/theme.dart';
import 'core/database/app_database.dart';
import 'core/database/local_workspace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  // TextureView keeps Flutter controls above the Android map in the same
  // composition path; the default Virtual Display has input/z-order limits.
  MapLibreMap.useHybridComposition = true;
  runApp(const WorkspaceBootstrap());
}

class WorkspaceBootstrap extends StatefulWidget {
  const WorkspaceBootstrap({super.key});
  @override
  State<WorkspaceBootstrap> createState() => _WorkspaceBootstrapState();
}

class _WorkspaceBootstrapState extends State<WorkspaceBootstrap> {
  late Future<LocalWorkspace> _load = _open();

  Future<LocalWorkspace> _open() async {
    final database = AppDatabase.device();
    try {
      return await LocalWorkspace.open(database);
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LocalWorkspace>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ProviderScope(
          overrides: [localWorkspaceProvider.overrideWithValue(snapshot.data!)],
          child: const WaydayApp(),
        );
      }
      return MaterialApp(
        title: 'Wayday',
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Your saved lists could not be opened.'),
                          const SizedBox(height: 12),
                          const Text(
                            'Your data has not been reset. Retry opening it; avoid clearing app storage.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() => _load = _open()),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    },
  );
}
