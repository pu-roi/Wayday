import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/network/gateway_client.dart';
import '../planning/data/itinerary_repository.dart';
import 'share_models.dart';

const sharingChannel = MethodChannel('wayday/sharing');

class ShareRepository extends ChangeNotifier {
  ShareRepository({
    GatewayClient? gateway,
    Future<String?> Function()? readStorage,
    Future<void> Function(String)? writeStorage,
    DateTime Function()? now,
    Future<Map<String, dynamic>?> Function()? nativeStatus,
    Future<void> Function()? stopNative,
  }) : gateway = gateway ?? GatewayClient.shared,
       _readStorage =
           readStorage ??
           (() => sharingChannel.invokeMethod<String>('readStorage')),
       _writeStorage =
           writeStorage ??
           ((v) => sharingChannel.invokeMethod<void>('writeStorage', v)),
       now = now ?? DateTime.now,
       _nativeStatus =
           nativeStatus ??
           (() async => Map<String, dynamic>.from(
             await sharingChannel.invokeMapMethod<String, dynamic>(
                   'broadcastStatus',
                 ) ??
                 {},
           )),
       _stopNative =
           stopNative ??
           (() => sharingChannel.invokeMethod<void>('stopBroadcast'));
  static final shared = ShareRepository();
  final GatewayClient gateway;
  final DateTime Function() now;
  final Future<String?> Function() _readStorage;
  final Future<void> Function(String) _writeStorage;
  final Future<Map<String, dynamic>?> Function() _nativeStatus;
  final Future<void> Function() _stopNative;
  Map<String, dynamic>? _values;
  Future<void> _writes = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _writes.then((_) => work());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, dynamic>> _load() async {
    if (_values != null) return _values!;
    final encoded = await _readStorage();
    _values = encoded == null || encoded.isEmpty
        ? {}
        : Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    return _values!;
  }

  Future<void> _save() async {
    await _writeStorage(jsonEncode(_values));
    notifyListeners();
  }

  static String credential() => base64UrlEncode(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  static String operationId() {
    final b = List.generate(16, (_) => Random.secure().nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Uri get origin {
    final uri = Uri.tryParse(gateway.baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !{'', '/'}.contains(uri.path)) {
      throw const SharingFailure('Trip sharing is not configured in this app.');
    }
    return uri;
  }

  String link(ShareAccess access, {bool invitation = false}) => origin
      .replace(
        path: invitation ? '/pair/' : '/share/',
        fragment: '${access.id}.${access.token}',
      )
      .toString();
  ShareAccess? parseLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.origin != origin.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        !{'/share/', '/pair/'}.contains(uri.path)) {
      return null;
    }
    final parsed = RegExp(
      r'^([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})\.([A-Za-z0-9_-]{43})$',
    ).firstMatch(uri.fragment);
    return parsed == null
        ? null
        : ShareAccess(
            id: parsed[1]!,
            token: parsed[2]!,
            role: uri.path == '/pair/' ? 'invitation' : 'viewer',
          );
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
      final proof = await gateway.token().timeout(const Duration(seconds: 12));
      if (proof.isEmpty) {
        throw const SharingFailure(
          'App verification is unavailable. Try again.',
        );
      }
      headers['X-Firebase-AppCheck'] = proof;
    }
    final request =
        http.Request(body == null ? 'GET' : 'POST', origin.resolve(path))
          ..followRedirects = false
          ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await gateway.client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > 100000) {
        throw const SharingFailure('The shared trip response is too large.');
      }
      bytes.addAll(chunk);
    }
    if (response.statusCode == 404 || response.statusCode == 403) {
      throw const SharingFailure(
        'This shared trip is unavailable or has expired.',
        unavailable: true,
      );
    }
    if (response.statusCode == 409) {
      throw const SharingFailure('Sharing changed. Refresh and try again.');
    }
    if (response.statusCode == 413 || response.statusCode == 422) {
      throw const SharingFailure('This trip could not be shared with its current route. Refresh your plan before sharing.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const SharingFailure(
        'Couldn’t reach trip sharing. Your trip is kept. Try again.',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  }

  Future<SharedTrip> read(ShareAccess access) async {
    try {
      final result = SharedTrip.fromJson(
        await _request('/v1/shares/${access.id}', token: access.token),
      );
      if (!result.expiresAt.isAfter(now())) {
        throw const SharingFailure(
          'This shared trip has expired.',
          unavailable: true,
        );
      }
      return result;
    } on SharingFailure {
      rethrow;
    } catch (_) {
      throw const SharingFailure(
        'Couldn’t open the shared trip. Check your connection and try again.',
      );
    }
  }

  Future<void> cacheCandidate(SharedSnapshot snapshot) => _serial(() async {
    final values = await _load();
    final old = values['candidate'] as Map?;
    // A background UI rebuild never extends a stored coordinate lease.
    if (old?['snapshot'] is Map &&
        (old!['snapshot'] as Map)['sourceId'] == snapshot.sourceId &&
        (old['expiresAt'] as num) > now().millisecondsSinceEpoch) {
      return;
    }
    values['candidate'] = {
      'snapshot': snapshot.toJson(),
      'expiresAt': now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
    };
    await _save();
  });
  Future<void> prepareReplacement(SharedSnapshot next) => _serial(() async {
    final values = await _load(), owner = valuesOrNullOwner;
    values.remove('candidate');
    await _save();
    if (owner != null && owner['sourceId'] != next.sourceId) await _end(owner);
    // Candidate is saved separately from source-owned accepted itinerary data.
    values['candidate'] = {
      'snapshot': next.toJson(),
      'expiresAt': now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
    };
    await _save();
  });
  Future<void> invalidateCandidate() => _serial(() async {
    (await _load()).remove('candidate');
    await _save();
  });
  Map<String, dynamic>? get valuesOrNullOwner => _values?['owner'] is Map
      ? Map<String, dynamic>.from(_values!['owner'] as Map)
      : null;
  Future<void> bind(AcceptedItinerary plan) => _serial(() async {
    final values = await _load(), candidate = values['candidate'] as Map?;
    if (candidate == null ||
        (candidate['expiresAt'] as num) <= now().millisecondsSinceEpoch) {
      return;
    }
    final snapshot = SharedSnapshot.fromJson(
      Map<String, dynamic>.from(candidate['snapshot'] as Map),
    );
    if (!snapshot.matches(plan)) return;
    candidate['runId'] = plan.runId;
    final owner = valuesOrNullOwner;
    if (owner != null && owner['sourceId'] == snapshot.sourceId) {
      owner['runId'] = plan.runId;
      values['owner'] = owner;
    }
    await _save();
  });
  Future<SharedSnapshot?> snapshotForTrip(AcceptedItinerary plan) async {
    final candidate = (await _load())['candidate'] as Map?;
    if (candidate == null ||
        candidate['runId'] != plan.runId ||
        (candidate['expiresAt'] as num) <= now().millisecondsSinceEpoch) {
      return null;
    }
    final value = SharedSnapshot.fromJson(
      Map<String, dynamic>.from(candidate['snapshot'] as Map),
    );
    return value.matches(plan) ? value.withCompleted(plan.completed) : null;
  }

  bool managingSource(String sourceId) =>
      valuesOrNullOwner?['sourceId'] == sourceId &&
      (valuesOrNullOwner?['expiresAt'] as num? ?? 0) >
          now().millisecondsSinceEpoch / 1000;
  Future<ShareAccess?> ownerFor({String? sourceId, String? runId}) async {
    await _load();
    final owner = valuesOrNullOwner;
    if (owner == null ||
        (owner['expiresAt'] as num? ?? 0) <=
            now().millisecondsSinceEpoch / 1000 ||
        (sourceId != null && owner['sourceId'] != sourceId) ||
        (runId != null && owner['runId'] != runId)) {
      return null;
    }
    return ShareAccess(
      id: owner['id'] as String,
      token: owner['token'] as String,
      role: 'owner',
    );
  }

  Future<ShareAccess> create(SharedSnapshot snapshot) => _serial(() async {
    final values = await _load();
    var owner = valuesOrNullOwner;
    if (owner != null && (owner['expiresAt'] as num? ?? 0) <= now().millisecondsSinceEpoch / 1000) {
      await _end(owner);
      owner = null;
    }
    if (owner != null &&
        (owner['sourceId'] != snapshot.sourceId ||
            owner['revocationPending'] == true)) {
      await _end(owner);
      owner = null;
    }
    if (owner != null &&
        (owner['expiresAt'] as num? ?? 0) >
            now().millisecondsSinceEpoch / 1000 &&
        owner['pendingCreate'] != true) {
      return ShareAccess(
        id: owner['id'] as String,
        token: owner['token'] as String,
        role: 'owner',
      );
    }
    if (owner == null || owner['pendingCreate'] != true) {
      owner = {
        'id': operationId(),
        'token': credential(),
        'viewerToken': credential(),
        'sourceId': snapshot.sourceId,
        'pendingCreate': true,
        'expiresAt':
            now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        'snapshot': snapshot.toJson(),
        if ((values['candidate'] as Map?)?['snapshot'] is Map &&
            (((values['candidate'] as Map)['snapshot']) as Map)['sourceId'] ==
                snapshot.sourceId)
          'runId': (values['candidate'] as Map)['runId'],
      };
      values['owner'] = owner;
      await _save();
    }
    final result = await _request(
      '/v1/shares',
      body: {
        'operationId': owner['id'],
        'ownerToken': owner['token'],
        'viewerToken': owner['viewerToken'],
        'snapshot': owner['snapshot'],
      },
    );
    owner['expiresAt'] = result['expiresAt'];
    owner['pendingCreate'] = false;
    values['owner'] = owner;
    await _save();
    return ShareAccess(
      id: owner['id'] as String,
      token: owner['token'] as String,
      role: 'owner',
    );
  });
  Future<void> shareViewerLink(ShareAccess access) async {
    await _load();
    final owner = valuesOrNullOwner;
    if (owner == null || owner['id'] != access.id) {
      throw const SharingFailure('Open the current sharing controls again.');
    }
    await sharingChannel.invokeMethod<void>(
      'share',
      link(
        ShareAccess(
          id: access.id,
          token: owner['viewerToken'] as String,
          role: 'viewer',
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> event(
    ShareAccess access,
    Map<String, dynamic> body,
  ) => _serial(() async {
    final current = await read(access);
    return _request(
      '/v1/shares/${access.id}/events',
      token: access.token,
      body: {'revision': current.revision, ...body},
    );
  });
  Future<void> publish(AcceptedItinerary plan) async {
    try {
      await _serial(() async {
        final access = await ownerFor(runId: plan.runId);
        if (access == null) return;
        (await _load())['progressPending'] = {
          'id': access.id,
          'completed': plan.completed.toList(),
        };
        await _save();
      });
      await flushProgress();
    } catch (_) {
      // Local completion is authoritative. Never fail or undo a committed Done.
    }
  }

  Future<void> flushProgress() => _serial(() async {
    final values = await _load();
    final pending = values['progressPending'];
    final owner = valuesOrNullOwner;
    if (pending is! Map ||
        owner == null ||
        pending['id'] != owner['id'] ||
        owner['revocationPending'] == true) {
      return;
    }
    final access = ShareAccess(
      id: owner['id'] as String,
      token: owner['token'] as String,
      role: 'owner',
    );
    final current = await read(access);
    await _request(
      '/v1/shares/${access.id}/events',
      token: access.token,
      body: {
        'kind': 'progress',
        'revision': current.revision,
        'completed': pending['completed'],
      },
    );
    values.remove('progressPending');
    await _save();
  });
  Future<void> retryPending() async {
    final values = await _load();
    if ((await _nativeStatus())?['revocationPending'] == true) {
      try {
        await _stopNative();
      } catch (_) {}
    }
    if ((values['owner'] as Map?)?['revocationPending'] == true) {
      final owner = values['owner'] as Map;
      await end(
        ShareAccess(
          id: owner['id'] as String,
          token: owner['token'] as String,
          role: 'owner',
        ),
      );
    }
    await flushProgress();
  }

  Future<void> _stop(ShareAccess access) async {
    final status = await _nativeStatus();
    if (status?['shareId'] == access.id && status?['role'] == access.role) await _stopNative();
  }

  Future<void> _end(Map<String, dynamic> owner) async {
    final access = ShareAccess(
      id: owner['id'] as String,
      token: owner['token'] as String,
      role: 'owner',
    );
    owner['revocationPending'] = true;
    _values!['owner'] = owner;
    try {
      await _save();
    } finally {
      // Stopping the device is immediate even if persisting intent failed.
      // A failed remote broadcast stop must not prevent ending link access.
      try {
        await _stop(access);
      } catch (_) {}
    }
    try {
      final state = await read(access);
      await _request(
        '/v1/shares/${access.id}/events',
        token: access.token,
        body: {'kind': 'end', 'revision': state.revision},
      );
    } on SharingFailure catch (e) {
      if (!e.unavailable) rethrow;
    }
    _values!.remove('owner');
    _values!.remove('progressPending');
    await _save();
  }

  Future<void> end(ShareAccess access) => _serial(() async {
    await _load();
    final owner = valuesOrNullOwner;
    if (owner != null && owner['id'] == access.id) await _end(owner);
  });
  Future<void> finish(String runId) async {
    final access = await ownerFor(runId: runId);
    if (access != null) {
      try {
        await end(access);
      } catch (_) {
        /* Pending state is durable and surfaced in management. */
      }
    }
    await _serial(() async {
      final values = await _load();
      if ((values['candidate'] as Map?)?['runId'] == runId) {
        values.remove('candidate');
      }
      await _save();
    });
  }

  Future<ShareAccess> invite(ShareAccess access) async {
    final invitation = ShareAccess(
      id: access.id,
      token: credential(),
      role: 'invitation',
    );
    await event(access, {
      'kind': 'invite',
      'invitationToken': invitation.token,
    });
    await sharingChannel.invokeMethod<void>(
      'share',
      link(invitation, invitation: true),
    );
    return invitation;
  }

  Future<ShareAccess> pair(ShareAccess invitation) => _serial(() async {
    final values = await _load();
    final previous = values['recipient'] as Map?;
    ShareAccess? access;
    if (previous?['id'] == invitation.id) {
      final retained = ShareAccess.fromJson(
        Map<String, dynamic>.from(previous!),
      );
      try {
        await read(retained);
        return retained;
      } on SharingFailure catch (failure) {
        if (!failure.unavailable) rethrow;
        if (previous['invitation'] == invitation.token) access = retained;
      }
    }
    access ??= ShareAccess(
      id: invitation.id,
      token: credential(),
      role: 'recipient',
    );
    // Persist before dispatch; uncertain pairing can be checked without replaying the invitation.
    values['recipient'] = {...access.toJson(), 'invitation': invitation.token};
    await _save();
    await _request(
      '/v1/shares/${access.id}/pair',
      token: invitation.token,
      body: {'recipientToken': access.token},
    );
    return access;
  });
  Future<ShareAccess?> pairedFor(String id) async {
    final value = (await _load())['recipient'];
    if (value is! Map || value['id'] != id) return null;
    return ShareAccess.fromJson(Map<String, dynamic>.from(value));
  }

  Future<void> startLocation(ShareAccess access) async {
    final state = await read(access), status = await _nativeStatus();
    if (status?['active'] == true &&
        (status?['shareId'] != access.id || status?['role'] != access.role)) {
      throw const SharingFailure(
        'Stop your other location share before starting this one.',
      );
    }
    final result = await event(access, {'kind': 'broadcast', 'enabled': true});
    try {
      await sharingChannel.invokeMethod<void>('startBroadcast', {
        'shareId': access.id,
        'token': access.token,
        'role': access.role,
        'broadcastRevision': result['broadcastRevision'],
        'expiresAt': state.expiresAt.millisecondsSinceEpoch ~/ 1000,
      });
    } catch (_) {
      try {
        await event(access, {'kind': 'broadcast', 'enabled': false});
      } catch (_) {}
      throw const SharingFailure(
        'Location sharing couldn’t start. Check location and notification permissions.',
      );
    }
  }

  Future<void> stopLocation(ShareAccess access) async {
    await _stop(access);
    await event(access, {'kind': 'broadcast', 'enabled': false});
  }

  Future<Map<String, dynamic>> status() async => {
    ...?await _nativeStatus(),
    'revocationPending':
        ((await _load())['owner'] is Map &&
            ((await _load())['owner'] as Map)['revocationPending'] == true) ||
        (await _nativeStatus())?['revocationPending'] == true,
    'progressPending': (await _load())['progressPending'] is Map,
  };
}
