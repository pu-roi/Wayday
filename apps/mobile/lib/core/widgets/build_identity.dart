import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BuildIdentity extends StatefulWidget {
  const BuildIdentity({super.key});
  @override
  State<BuildIdentity> createState() => _BuildIdentityState();
}

class _BuildIdentityState extends State<BuildIdentity> {
  late final Future<Map<String, dynamic>?> identity = _load();
  Future<Map<String, dynamic>?> _load() async {
    try {
      return await const MethodChannel(
        'wayday/gateway',
      ).invokeMapMethod<String, dynamic>('buildInfo');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: identity,
    builder: (context, snapshot) {
      final info = snapshot.data;
      if (info == null) return const SizedBox.shrink();
      const source = String.fromEnvironment('WAYDAY_SOURCE_COMMIT');
      final commit = source.length >= 7 ? ' · ${source.substring(0, 7)}' : '';
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          '${info['channel']} · ${info['version']} (${info['versionCode']})$commit',
        ),
      );
    },
  );
}
