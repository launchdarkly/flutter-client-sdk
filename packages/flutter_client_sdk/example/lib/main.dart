import 'package:flutter/material.dart';
import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // The LDClient doesn't need to change throughout the lifetime of the
    // application, so we wrap the application in a provider with the client.
    return Provider<LDClient>(
        create: (_) => LDClient(
            LDConfig(
                // The credentials come from the environment, you can set them
                // using --dart-define.
                // Examples:
                // flutter run --dart-define LAUNCHDARKLY_CLIENT_SIDE_ID=<my-client-side-id> -d Chrome
                // flutter run --dart-define LAUNCHDARKLY_MOBILE_KEY=<my-mobile-key> -d ios
                //
                // Alternatively `CredentialSource.fromEnvironment()` can be replaced with your mobile key.
                CredentialSource.fromEnvironment(),
                dataSourceConfig: DataSourceConfig(useReport: true),
                AutoEnvAttributes.enabled,
                logger: LDLogger(level: LDLogLevel.debug)),
            // Here we are using a default user with 'user-key'.
            LDContextBuilder().kind('user', 'user-key').build()),
        dispose: (_, client) => client.close(),
        // We use a future provider to wait for the client to either start,
        // or for a timeout to elapse.
        child: MaterialApp(
          title: 'LaunchDarkly Example',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          home: const MyHomePage(title: 'LaunchDarkly Example'),
        ));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

/// Example provider which listens for flag changes and maps them to string
/// values. It would also be possible to map to some application specific model
/// types. When mapping be sure all values are accessed through the client
/// `variation` methods. This ensures that the SDK generates the expected
/// events.
class FlagProviderString extends StreamProvider<String> {
  FlagProviderString(
      {super.key,
      required LDClient client,
      required String flagKey,
      required String defaultValue,
      required Widget child})
      : super(
            create: (context) => client.flagChanges
                .where((element) => element.keys.contains(flagKey))
                .map((event) => client.stringVariation(flagKey, defaultValue)),
            // Here we get the initial value of the flag. If the SDK is not
            // initialized, then the default value will be returned.
            initialData: client.stringVariation(flagKey, defaultValue),
            child: child);
}

class _MyHomePageState extends State<MyHomePage> {
  final _userKeyController = TextEditingController(text: 'user-key');

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: // The FutureBuilder here is used in order to gate the presentation content
          // based on the LaunchDarkly SDK having started. While it has not started
          // a loading indicator will be shown. Once it has started, or encountered
          // a timeout, then it will render the content.
          FutureBuilder(
              future: Provider.of<LDClient>(context, listen: false)
                  .start()
                  .timeout(const Duration(seconds: 5))
                  .then((value) => true),
              builder: (context, loaded) => loaded.data ?? false
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  // The validator receives the text that the user has entered.
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a user key';
                                    }
                                    return null;
                                  },
                                  controller: _userKeyController,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Validate returns true if the form is valid, or false otherwise.
                                      if (_formKey.currentState!.validate()) {
                                        final client = Provider.of<LDClient>(
                                            context,
                                            listen: false);

                                        client
                                            .identify(LDContextBuilder()
                                                .kind('user',
                                                    _userKeyController.text)
                                                .build())
                                            .then((value) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Identify complete')),
                                          );
                                        });
                                      }
                                    },
                                    child: const Text('Identify'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FlagProviderString(
                              // The client will not be changing, so we don't need to
                              // listen for client changes.
                              client:
                                  Provider.of<LDClient>(context, listen: false),
                              flagKey: 'string-flag',
                              defaultValue: 'default-value',
                              child: Consumer<String>(
                                  builder: (context, flagValue, _) =>
                                      Text('flag value: $flagValue'))),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator()),
    );
  }
}
