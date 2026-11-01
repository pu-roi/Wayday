import 'package:flutter/material.dart';
import 'app/theme.dart';
import 'core/network/gateway_client.dart';
import 'core/network/public_gateway_probe.dart';

/// Separate connection-check entry point, never the public download app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('WAYDAY_PUBLIC_TEST') ||
      !GatewayClient.enabled) {
    throw StateError(
      'This entry point requires the isolated public test build.',
    );
  }
  runApp(
    MaterialApp(
      title: 'Wayday Test',
      theme: buildTheme(),
      home: PublicGatewayTestScreen(
        check: PublicGatewayProbe(GatewayClient.shared).check,
      ),
    ),
  );
}

class PublicGatewayTestScreen extends StatefulWidget {
  const PublicGatewayTestScreen({super.key, required this.check});
  final Future<GatewayProbeResult> Function() check;
  @override
  State<PublicGatewayTestScreen> createState() =>
      _PublicGatewayTestScreenState();
}

class _PublicGatewayTestScreenState extends State<PublicGatewayTestScreen> {
  bool _busy = false;
  GatewayProbeResult? _result;
  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    GatewayProbeResult result;
    try {
      result = await widget.check();
    } catch (_) {
      result = GatewayProbeResult.unavailable;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wayday Test')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Check the app connection',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'This separate test app does not read or change your saved Wayday errands or trips.',
          ),
          const SizedBox(height: 16),
          const Text(
            'The check verifies this app with Firebase and sends a read-only preflight to the Wayday gateway. It does not request Gemini, routes, places or your location.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _check,
            child: Text(_busy ? 'Checking…' : 'Check connection'),
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(switch (_result) {
              GatewayProbeResult.verified =>
                  'App verification and gateway access passed. No provider request was made.',
              GatewayProbeResult.verifiedWithoutBudget =>
                  'App verification and gateway access passed. Shared Google testing is unavailable. No provider request was made.',
              GatewayProbeResult.denied =>
                'The gateway did not accept this app verification. Keep this result for setup review.',
              GatewayProbeResult.unavailable =>
                'The connection check could not finish. No automatic retry will run.',
              null =>
                _busy
                    ? 'Waiting for app verification…'
                    : 'Nothing is sent until you tap Check connection.',
            }),
          ),
          const SizedBox(height: 24),
          const Text(
            'This checks the test app connection only. It does not qualify the public Wayday download or a full planning flow.',
          ),
        ],
      ),
    ),
  );
}
