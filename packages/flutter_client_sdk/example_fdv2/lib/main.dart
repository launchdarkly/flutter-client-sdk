import 'package:flutter/material.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';

void main() {
  runApp(const FDv2DemoApp());
}

/// Manual testing app for the FDv2 data system. Demonstrates:
/// - Enabling FDv2 via [DataSystemConfig].
/// - Live flag value updates over the FDv2 streaming synchronizer.
/// - Switching connection modes (streaming, polling, offline) at runtime.
/// - Identifying new contexts.
/// - Observing the data source status.
class FDv2DemoApp extends StatelessWidget {
  const FDv2DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LaunchDarkly FDv2 Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final LDClient _client;
  late final Future<bool> _started;

  final _flagKeyController = TextEditingController(text: 'sample-feature');
  final _userKeyController = TextEditingController(text: 'example-user-key');

  ConnectionMode _selectedMode = ConnectionMode.streaming;
  String _flagKey = 'sample-feature';
  String _contextDescription = 'user: example-user-key';

  @override
  void initState() {
    super.initState();
    _client = LDClient(
        LDConfig(
          // The credentials come from the environment, you can set them
          // using --dart-define.
          // Examples:
          // flutter run --dart-define LAUNCHDARKLY_CLIENT_SIDE_ID=<my-client-side-id> -d Chrome
          // flutter run --dart-define LAUNCHDARKLY_MOBILE_KEY=<my-mobile-key> -d ios
          //
          // Alternatively `CredentialSource.fromEnvironment()` can be
          // replaced with your mobile key.
          CredentialSource.fromEnvironment(),
          AutoEnvAttributes.enabled,
          applicationInfo: ApplicationInfo(
            applicationId: 'ld-flutter-fdv2-test-app',
            applicationVersion: '0.0.1',
          ),
          // The presence of a data system configuration opts the SDK into
          // the FDv2 protocol.
          dataSystem: const DataSystemConfig(),
          // Disable automatic state detection so the connection mode
          // buttons below keep full control of the active mode.
          applicationEvents: ApplicationEvents(
              backgrounding: false, networkAvailability: false),
        ),
        LDContextBuilder().kind('user', 'example-user-key').build());
    _started = _client
        .start()
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
  }

  @override
  void dispose() {
    _client.close();
    _flagKeyController.dispose();
    _userKeyController.dispose();
    super.dispose();
  }

  void _identify() {
    final userKey = _userKeyController.text.trim();
    if (userKey.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    _client
        .identify(LDContextBuilder().kind('user', userKey).build())
        .then((result) {
      if (!mounted) return;
      setState(() {
        _contextDescription = 'user: $userKey';
      });
      messenger.showSnackBar(SnackBar(
          content: Text(switch (result) {
        IdentifyComplete() => 'Identify complete: $userKey',
        IdentifySuperseded() => 'Identify superseded',
        IdentifyError(error: final error) => 'Identify error: $error',
      })));
    });
  }

  void _setMode(ConnectionMode mode) {
    setState(() {
      _selectedMode = mode;
    });
    _client.setConnectionMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('LaunchDarkly FDv2 Demo'),
      ),
      body: FutureBuilder(
        future: _started,
        builder: (context, started) => !started.hasData
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusCard(client: _client),
                    const SizedBox(height: 16),
                    Text('Connection mode',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<ConnectionMode>(
                      segments: const [
                        ButtonSegment(
                            value: ConnectionMode.streaming,
                            label: Text('Streaming')),
                        ButtonSegment(
                            value: ConnectionMode.polling,
                            label: Text('Polling')),
                        ButtonSegment(
                            value: ConnectionMode.offline,
                            label: Text('Offline')),
                      ],
                      selected: {_selectedMode},
                      onSelectionChanged: (selection) =>
                          _setMode(selection.first),
                    ),
                    const SizedBox(height: 16),
                    Text('Context',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_contextDescription),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _userKeyController,
                      decoration: const InputDecoration(
                        labelText: 'User key',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _identify(),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: _identify, child: const Text('Identify')),
                    const SizedBox(height: 16),
                    Text('Flag evaluation',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _flagKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Flag key',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() {
                        _flagKey = value.trim();
                      }),
                    ),
                    const SizedBox(height: 8),
                    _FlagValueCard(client: _client, flagKey: _flagKey),
                    const SizedBox(height: 16),
                    Text('All flags',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _AllFlagsCard(client: _client),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Shows the live data source status: the state name and how long the SDK
/// has been in it. Interruptions and recoveries appear here, which makes
/// synchronizer fallback behavior observable.
class _StatusCard extends StatelessWidget {
  final LDClient client;

  const _StatusCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DataSourceStatus>(
      stream: client.dataSourceStatusChanges,
      initialData: client.dataSourceStatus,
      builder: (context, status) {
        final state = status.data?.state;
        final since = status.data?.stateSince;
        final error = status.data?.lastError;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle,
                        size: 12,
                        color: switch (state) {
                          DataSourceState.valid => Colors.green,
                          DataSourceState.initializing => Colors.amber,
                          DataSourceState.interrupted => Colors.orange,
                          _ => Colors.red,
                        }),
                    const SizedBox(width: 8),
                    Text('Data source: ${state?.name ?? 'unknown'}',
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                if (since != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Since: $since',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Last error: ${error.message}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shows the live value of a single flag. Values update as FDv2 payloads
/// arrive; the evaluation goes through the client so analytics events are
/// generated as they would be in a real application.
class _FlagValueCard extends StatelessWidget {
  final LDClient client;
  final String flagKey;

  const _FlagValueCard({required this.client, required this.flagKey});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FlagsChangedEvent>(
      stream: client.flagChanges,
      builder: (context, _) {
        final value = client.jsonVariation(flagKey, LDValue.ofNull());
        return Card(
          child: ListTile(
            title: Text(flagKey.isEmpty ? '(no flag key)' : flagKey),
            subtitle: Text(value.type == LDValueType.nullType
                ? 'not found (null)'
                : value.toString()),
          ),
        );
      },
    );
  }
}

/// Lists every flag the SDK currently holds, refreshing as payloads
/// arrive. Useful for confirming full and partial transfers apply.
class _AllFlagsCard extends StatelessWidget {
  final LDClient client;

  const _AllFlagsCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FlagsChangedEvent>(
      stream: client.flagChanges,
      builder: (context, _) {
        final allFlags = client.allFlags();
        if (allFlags.isEmpty) {
          return const Card(
            child: ListTile(title: Text('No flags received yet.')),
          );
        }
        return Card(
          child: Column(
            children: allFlags.entries
                .map((entry) => ListTile(
                      dense: true,
                      title: Text(entry.key),
                      subtitle: Text(entry.value.toString()),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}
