import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/recurring/presentation/recurring_view.dart';
import '../features/today/presentation/today_view.dart';
import 'settings_view.dart';
import '../features/profile/presentation/profile_view.dart';
import '../core/widgets/module_transition.dart';
import 'theme.dart';
import '../core/database/local_workspace.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/today',
            pageBuilder: (context, state) =>
                modulePage(context, state, const TodayView()),
          ),
          GoRoute(
            path: '/recurring',
            pageBuilder: (context, state) =>
                modulePage(context, state, const RecurringView()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                modulePage(context, state, const ProfileView()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                modulePage(context, state, const SettingsView()),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class WaydayApp extends ConsumerWidget {
  const WaydayApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Wayday',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    themeMode: ThemeMode.light,
    routerConfig: ref.watch(routerProvider),
    builder: (context, child) {
      final workspace = ref.watch(localWorkspaceProvider);
      if (workspace == null) return child!;
      return ListenableBuilder(
        listenable: workspace,
        builder: (context, _) => Column(
          children: [
            if (workspace.lastError != null)
              SafeArea(
                bottom: false,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Changes are not saved. Keep Wayday open and retry.',
                          ),
                        ),
                        TextButton(
                          onPressed: workspace.isSaving
                              ? null
                              : workspace.retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: child!),
          ],
        ),
      );
    },
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final index = switch (location) {
      '/recurring' => 1,
      '/profile' => 2,
      '/settings' => 3,
      _ => 0,
    };
    void select(int value) =>
        context.go(['/today', '/recurring', '/profile', '/settings'][value]);
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.format_list_bulleted_rounded),
        label: 'Today',
      ),
      NavigationDestination(
        icon: Icon(Icons.repeat_rounded),
        label: 'Recurring',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        label: 'Profile',
      ),
      NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: select,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Icon(
                      Icons.route_rounded,
                      color: context.wayday.link,
                    ),
                  ),
                  destinations: destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: item.icon,
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }
        return Scaffold(
          body: child,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colors.outlineVariant),
              ),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }
}
