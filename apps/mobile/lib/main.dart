import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'app/wayday_app.dart';
import 'core/data/local_repositories.dart';
import 'core/data/legacy_recovery.dart';
import 'core/data/recovery_types.dart';
import 'features/recurring/presentation/recurring_controller.dart';
import 'features/today/presentation/today_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    MapLibreMap.useHybridComposition = true;
  }
  if (kIsWeb) {
    runApp(const ProviderScope(child: WaydayApp()));
    return;
  }

  runApp(const _RecoveryBootstrap());
}

class _RecoveryBootstrap extends StatefulWidget {
  const _RecoveryBootstrap();
  @override
  State<_RecoveryBootstrap> createState() => _RecoveryBootstrapState();
}

class _RecoveryBootstrapState extends State<_RecoveryBootstrap> {
  final _recovery = LegacyRecovery();
  LocalRepositories? _repositories;
  Object? _error;
  bool _loading = true;
  bool _choose = false;

  @override
  void initState() {
    super.initState();
    _inspect();
  }

  Future<void> _inspect() async {
    setState(() {
      _loading = true;
      _error = null;
      _choose = false;
    });
    try {
      final state = await _recovery.inspect();
      if (state == RecoveryState.choose) {
        if (mounted) {
          setState(() {
            _loading = false;
            _choose = true;
          });
        }
      } else {
        final repositories = state == RecoveryState.normal
            ? await LocalRepositories.open()
            : await _recovery.open(
                state == RecoveryState.rudyOnly
                    ? RecoveryChoice.rudy
                    : RecoveryChoice.roi,
              );
        if (mounted) {
          setState(() {
            _repositories = repositories;
            _loading = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _select(RecoveryChoice choice) async {
    setState(() {
      _loading = true;
      _error = null;
      _choose = false;
    });
    try {
      final repositories = await _recovery.open(choice);
      if (mounted) {
        setState(() {
          _repositories = repositories;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repositories = _repositories;
    if (repositories != null) {
      return ProviderScope(
        overrides: [
          localRepositoriesProvider.overrideWithValue(repositories),
          dayRepositoryProvider.overrideWithValue(repositories.today),
          groupRepositoryProvider.overrideWithValue(repositories.recurring),
        ],
        child: const WaydayApp(),
      );
    }
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_choose) ...[
                          const Text(
                            'Two Wayday data sets were found. Choose which one to use. Both original databases will be kept.',
                          ),
                          FilledButton(
                            onPressed: () => _select(RecoveryChoice.roi),
                            child: const Text('Use Roi data'),
                          ),
                          OutlinedButton(
                            onPressed: () => _select(RecoveryChoice.rudy),
                            child: const Text('Use Rudy data'),
                          ),
                        ] else if (_error != null) ...[
                          const Text(
                            'Your saved data could not be opened. It has not been reset.',
                          ),
                          FilledButton(
                            onPressed: _inspect,
                            child: const Text('Retry'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
