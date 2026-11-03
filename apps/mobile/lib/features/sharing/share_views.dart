import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../places/domain/place_intent.dart';
import '../planning/presentation/plan_map.dart';
import 'share_models.dart';
import 'share_repository.dart';

String sharingMessage(Object error) => error is SharingFailure
    ? error.message
    : 'Sharing is unavailable. Check your connection and try again.';

Future<void> openShareSheet(
  BuildContext context, {
  required Future<SharedSnapshot?> Function() snapshot,
  String? runId,
  ShareRepository? repository,
}) async {
  final repo = repository ?? ShareRepository.shared;
  try {
    final candidate = await snapshot();
    final owner = await repo.ownerFor(
      sourceId: candidate?.sourceId,
      runId: runId,
    );
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => ShareManagementSheet(
        snapshot: candidate,
        access: owner,
        repository: repo,
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sharingMessage(error))));
    }
  }
}

class ShareToolbarAction extends StatefulWidget {
  const ShareToolbarAction({
    required this.snapshot,
    this.runId,
    this.sourceId,
    this.enabled = true,
    this.label = 'Share trip',
    super.key,
  });
  final Future<SharedSnapshot?> Function() snapshot;
  final String? runId, sourceId;
  final bool enabled;
  final String label;
  @override
  State<ShareToolbarAction> createState() => _ShareToolbarActionState();
}

class _ShareToolbarActionState extends State<ShareToolbarAction> {
  bool managing = false;
  @override
  void initState() {
    super.initState();
    ShareRepository.shared.addListener(refresh);
    unawaited(load());
  }

  void refresh() {
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final owner = await ShareRepository.shared.ownerFor(
        runId: widget.runId,
        sourceId: widget.sourceId,
      );
      if (mounted) setState(() => managing = owner != null);
    } catch (_) {
      /* Opening the sheet reports storage failures explicitly. */
    }
  }

  @override
  void didUpdateWidget(covariant ShareToolbarAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId ||
        oldWidget.runId != widget.runId) {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    ShareRepository.shared.removeListener(refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: managing ? 'Manage sharing' : widget.label,
    icon: const Icon(Icons.share_outlined),
    onPressed: widget.enabled
        ? () => openShareSheet(
            context,
            snapshot: widget.snapshot,
            runId: widget.runId,
          )
        : null,
  );
}

class ShareManagementSheet extends StatefulWidget {
  const ShareManagementSheet({
    required this.snapshot,
    required this.access,
    required this.repository,
    super.key,
  });
  final SharedSnapshot? snapshot;
  final ShareAccess? access;
  final ShareRepository repository;
  @override
  State<ShareManagementSheet> createState() => _ShareManagementSheetState();
}

class _ShareManagementSheetState extends State<ShareManagementSheet> {
  ShareAccess? access;
  SharedTrip? trip;
  Map<String, dynamic> status = {};
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    access = widget.access;
    if (access != null) unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final local = await widget.repository.status();
      if (mounted) setState(() => status = local);
      try {
        await widget.repository.flushProgress();
      } catch (_) {}
      final state = await widget.repository.read(access!);
      if (mounted) {
        setState(() {
          trip = state;
          status = local;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = sharingMessage(e));
    }
  }

  Future<void> act(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = sharingMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get active =>
      status['active'] == true &&
      status['shareId'] == access?.id &&
      status['role'] == access?.role;
  @override
  Widget build(BuildContext context) {
    final snapshot = trip?.snapshot ?? widget.snapshot;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    access == null ? 'Share trip' : 'Manage sharing',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (status['linkRevocationPending'] == true) ...[
              const Text(
                'Location sharing has stopped on this phone. Ending link access is pending until the service is reachable or the link expires.',
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        await widget.repository.end(access!);
                        if (context.mounted) Navigator.pop(context);
                      }),
                child: const Text('Retry ending sharing'),
              ),
            ] else if (access == null) ...[
              const Text(
                'Anyone with this link can view the route, errands, start and final destination for two hours. Live location is off until you choose to turn it on.',
              ),
              const SizedBox(height: 16),
              if (snapshot != null) ...[
                Text(
                  'What you’ll share',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ShareItinerary(snapshot: snapshot, preview: true),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          final created = await widget.repository.create(
                            snapshot,
                          );
                          if (!mounted) return;
                          setState(() => access = created);
                          await refresh();
                          await widget.repository.shareViewerLink(created);
                        }),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(busy ? 'Creating link…' : 'Create share link'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'The original planned route is unavailable or expired. Open Your plan and explicitly refresh the route before sharing. Your trip and progress are kept.',
                  ),
                ),
            ] else ...[
              if (trip != null)
                Text(
                  'Shared until ${TimeOfDay.fromDateTime(trip!.expiresAt).format(context)}. Anyone with the link can view.',
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () =>
                          act(() => widget.repository.shareViewerLink(access!)),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share link again'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SharedTripPage(
                            access: access!,
                            repository: widget.repository,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View shared trip'),
              ),
              const SizedBox(height: 16),
              Text(
                'Your live location',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Turning this on shares your current location while the app is minimized or your phone is locked. Use Stop sharing here or in the phone notification at any time.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        if (active || trip?.broadcasting == true) {
                          await widget.repository.stopLocation(access!);
                        } else {
                          await requestShareLocation();
                          await widget.repository.startLocation(access!);
                        }
                        await refresh();
                      }),
                icon: Icon(
                  active ? Icons.location_off_outlined : Icons.my_location,
                ),
                label: Text(
                  active || trip?.broadcasting == true
                      ? 'Stop sharing my location'
                      : 'Share my live location',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share location back',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a separate five-minute invitation to one person. They must accept and choose to turn on their own location sharing. Only you can see their location.',
              ),
              const SizedBox(height: 8),
              if (trip?.paired == true)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await widget.repository.event(access!, {
                            'kind': 'removeRecipient',
                          });
                          await refresh();
                        }),
                  child: const Text('Remove paired recipient'),
                )
              else
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await widget.repository.invite(access!);
                          await refresh();
                        }),
                  child: const Text('Invite one recipient'),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        await widget.repository.end(access!);
                        if (context.mounted) Navigator.pop(context);
                      }),
                icon: const Icon(Icons.link_off),
                label: const Text('End sharing'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> requestShareLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const SharingFailure(
      'Turn on phone location services before sharing your location.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const SharingFailure(
      'Location permission is needed only if you choose to share your location. Enable it in phone settings and try again.',
    );
  }
}

class SharedTripPage extends StatefulWidget {
  const SharedTripPage({required this.access, this.repository, super.key});
  final ShareAccess access;
  final ShareRepository? repository;
  @override
  State<SharedTripPage> createState() => _SharedTripPageState();
}

class _SharedTripPageState extends State<SharedTripPage>
    with WidgetsBindingObserver {
  ShareRepository get repo => widget.repository ?? ShareRepository.shared;
  late ShareAccess access = widget.access;
  SharedTrip? trip;
  String? error;
  bool loading = false, busy = false, unavailable = false;
  Map<String, dynamic> nativeStatus = {};
  Timer? poll, clock;
  bool get visible =>
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => initialize());
    poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && visible) unawaited(refresh());
    });
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !visible) return;
      if (trip != null && !trip!.expiresAt.isAfter(repo.now())) {
        setState(() {
          trip = null;
          unavailable = true;
          error = 'This shared trip has expired.';
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> initialize() async {
    try {
      if (access.role == 'viewer') {
        final paired = await repo.pairedFor(access.id);
        if (paired != null) access = paired;
      }
      if (mounted && access.role != 'invitation') await refresh();
    } catch (failure) {
      if (mounted) setState(() => error = sharingMessage(failure));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        access.role != 'invitation') {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poll?.cancel();
    clock?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (loading || unavailable) return;
    loading = true;
    try {
      final value = await repo.read(access);
      Map<String, dynamic> status = {};
      try {
        status = await repo.status();
      } catch (_) {}
      if (mounted) {
        setState(() {
          trip = value;
          nativeStatus = status;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = sharingMessage(e);
          unavailable = e is SharingFailure && e.unavailable;
          if (unavailable) trip = null;
        });
      }
    } finally {
      loading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> act(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = sharingMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = trip;
    return Scaffold(
      appBar: AppBar(title: const Text('Shared trip')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (access.role == 'invitation') ...[
              Text(
                'Share your location back',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Accept this invitation to pair with the sender. Pairing does not turn on location sharing. You will choose that separately.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        final paired = await repo.pair(access);
                        if (!mounted) return;
                        setState(() => access = paired);
                        await refresh();
                      }),
                child: const Text('Accept invitation'),
              ),
            ] else if (value != null) ...[
              Text(
                'Shared until ${TimeOfDay.fromDateTime(value.expiresAt).format(context)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ShareItinerary(
                snapshot: value.snapshot,
                trip: value,
                now: repo.now(),
              ),
              if (access.role != 'viewer') ...[
                const SizedBox(height: 24),
                Text(
                  'Your live location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  access.role == 'recipient'
                      ? 'Only the sender can see your location. Sharing continues while your phone is locked or Wayday is minimized.'
                      : 'Anyone with the viewer link can see your location when sharing is on.',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          if ((nativeStatus['active'] == true &&
                                  nativeStatus['shareId'] == access.id &&
                                  nativeStatus['role'] == access.role) ||
                              value.broadcasting) {
                            await repo.stopLocation(access);
                          } else {
                            await requestShareLocation();
                            await repo.startLocation(access);
                          }
                          await refresh();
                        }),
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    (nativeStatus['active'] == true &&
                                nativeStatus['shareId'] == access.id &&
                                nativeStatus['role'] == access.role) ||
                            value.broadcasting
                        ? 'Stop sharing my location'
                        : 'Share my live location',
                  ),
                ),
              ],
            ] else if (!unavailable && (loading || error == null))
              const Center(child: CircularProgressIndicator()),
            if (!unavailable && access.role != 'invitation') ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: loading ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh shared trip'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShareItinerary extends StatelessWidget {
  const ShareItinerary({
    required this.snapshot,
    this.trip,
    this.now,
    this.preview = false,
    super.key,
  });
  final SharedSnapshot snapshot;
  final SharedTrip? trip;
  final DateTime? now;
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final current = now ?? DateTime.now();
    final done = trip?.snapshot.completed ?? snapshot.completed;
    final next = snapshot.stops
        .where((s) => !done.contains(s.id))
        .firstOrNull
        ?.id;
    final owner = SharedTrip.fresh(trip?.ownerLocation, current)
        ? trip!.ownerLocation
        : null;
    final recipient = SharedTrip.fresh(trip?.recipientLocation, current)
        ? trip!.recipientLocation
        : null;
    final locations = <(String, Map<String, dynamic>)>[
      if (owner != null) ('Sender', owner),
      if (recipient != null) ('Recipient', recipient),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: preview ? 200 : 300,
            child: PlanMap(
              places: [
                ...snapshot.places,
                for (final (name, fix) in locations)
                  PlaceIntent(
                    kind: PlaceKind.specific,
                    label: '$name live location',
                    source: 'shared_device_location',
                    latitude: (fix['latitude'] as num).toDouble(),
                    longitude: (fix['longitude'] as num).toDouble(),
                  ),
              ],
              geometry: [snapshot.route],
              labels: [
                'Start',
                ...snapshot.stops.map((s) => s.place),
                'Final destination',
                for (final (name, _) in locations) '$name live location',
              ],
              markerLabels: [
                'S',
                for (var i = 0; i < snapshot.stops.length; i++) '${i + 1}',
                'F',
                for (final (name, _) in locations) name == 'Sender' ? '●' : '◆',
              ],
              onSelect: (_) {},
              interactive: !preview,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Planned route',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        if (trip != null) ...[
          const SizedBox(height: 4),
          Text(
            owner == null
                ? (trip!.ownerSharing
                      ? 'Waiting for a fresh sender location.'
                      : 'Live location is off.')
                : '${(owner['accuracy'] as num) > 100 ? 'Approximate sender location' : 'Sender live location'} · updated ${((current.millisecondsSinceEpoch / 1000) - (owner['recordedAt'] as num)).floor()}s ago',
          ),
          if (recipient != null)
            Text('Paired recipient location · only you can see this'),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Errands', style: Theme.of(context).textTheme.titleLarge),
            Text('${done.length} of ${snapshot.stops.length} done'),
          ],
        ),
        const SizedBox(height: 12),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.trip_origin),
          title: Text('From'),
          subtitle: Text('Start location'),
        ),
        for (var i = 0; i < snapshot.stops.length; i++) ...[
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.secondary,
              child: done.contains(snapshot.stops[i].id)
                  ? const Icon(Icons.check, size: 18)
                  : Text('${i + 1}', style: const TextStyle(fontSize: 14)),
            ),
            title: Text(snapshot.stops[i].title),
            subtitle: Text(
              '${snapshot.stops[i].place}\n${done.contains(snapshot.stops[i].id)
                  ? 'Done'
                  : snapshot.stops[i].id == next
                  ? 'Next'
                  : 'Planned'}',
            ),
          ),
        ],
        const Divider(height: 1),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.flag_outlined),
          title: Text('To'),
          subtitle: Text('Final destination'),
        ),
      ],
    );
  }
}

class SharingLinks {
  static bool _bound = false;
  static String? _last;
  static void bind(GoRouter router) {
    if (_bound || !sharingEnabled) return;
    _bound = true;
    void open(String? link) {
      if (link == null || link == _last) return;
      try {
        final access = ShareRepository.shared.parseLink(link);
        if (access == null) return;
        _last = link;
        router.push('/shared', extra: access).whenComplete(() => _last = null);
      } catch (_) {
        /* Invalid platform URLs never reach a repository or editor. */
      }
    }

    sharingChannel.setMethodCallHandler((call) async {
      if (call.method == 'openLink' && call.arguments is String) {
        open(call.arguments as String);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        open(await sharingChannel.invokeMethod<String>('initialLink'));
      } catch (_) {}
    });
  }
}

/// A finished trip can leave an offline revocation to retry from the main shell.
class SharingRecoveryBanner extends StatefulWidget {
  const SharingRecoveryBanner({super.key});
  @override
  State<SharingRecoveryBanner> createState() => _SharingRecoveryBannerState();
}

class _SharingRecoveryBannerState extends State<SharingRecoveryBanner>
    with WidgetsBindingObserver {
  bool pending = false, busy = false;
  final repo = ShareRepository.shared;
  @override
  void initState() {
    super.initState();
    repo.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
  }

  void changed() {
    unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final status = await repo.status();
      if (mounted) {
        setState(
          () => pending =
              status['revocationPending'] == true ||
              status['progressPending'] == true,
        );
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    repo.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => pending
      ? MaterialBanner(
          content: const Text(
            'A trip sharing update is waiting for a connection.',
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await repo.retryPending();
                      } catch (failure) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(sharingMessage(failure))),
                          );
                        }
                      }
                      if (mounted) setState(() => busy = false);
                      await refresh();
                    },
              child: Text(busy ? 'Updating…' : 'Retry sharing update'),
            ),
          ],
        )
      : const SizedBox.shrink();
}
