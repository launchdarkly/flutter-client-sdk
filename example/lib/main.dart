import 'package:flutter/material.dart';
import 'dart:async';

import 'package:launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String? typeDropdown = 'Boolean';
  final String contextKind = 'user';
  String contextKey = '';
  String evalKey = '';
  String evalResult = '';
  bool offline = false;
  // TODO: Uncomment as part of sc-215077
  // final client = SSEClient(
  //     // TODO: update this to no longer have a hardcoded key in it.  This is just here during the rewrite
  //     Uri.parse(
  //         'https://clientstream.launchdarkly.com/meval/eyJrZXkiOiAiZXhhbXBsZS11c2VyLWtleSIsICJraW5kIjogInVzZXIifQ=='),
  //     'MOBILE_KEY',
  //     agentName: "FlutterRewriteClient/4.0");

  // StreamSubscription<MessageEvent>? _clientSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    final LDConfig ldConfig =
        LDConfigBuilder('MOBILE_KEY', AutoEnvAttributes.Enabled).build();

    LDContextBuilder builder = LDContextBuilder();
    builder.kind(contextKind, "user-key-123abc");
    await LDClient.start(ldConfig, builder.build());

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void evaluate() async {
    switch (typeDropdown) {
      case 'Boolean':
        var result = await LDClient.boolVariation(evalKey, false);
        setState(() {
          evalResult = result.toString();
        });
        break;
      // case 'Integer':
      //   var result = await LDClient.intVariation(evalKey, 0);
      //   setState(() { evalResult = result.toString(); });
      //   break;
      // case 'Float':
      //   var result = await LDClient.doubleVariation(evalKey, 0);
      //   setState(() { evalResult = result.toString(); });
      //   break;
      // case 'String':
      //   var result = await LDClient.stringVariation(evalKey, "");
      //   setState(() { evalResult = result; });
      //   break;
      // case 'Json':
      //   var result = await LDClient.jsonVariation(evalKey, LDValue.buildObject().build());
      //   setState(() { evalResult = json.encode(result.codecValue()); });
      //   break;
      default:
        break;
    }
  }

  void track() async {
    await LDClient.track(evalKey);
  }

  void identify() async {
    LDContextBuilder builder = LDContextBuilder();
    builder.kind(contextKind, contextKey);
    await LDClient.identify(builder.build());
  }

  void flush() async {
    await LDClient.flush();
  }

  void toggleOffline(bool offline) async {
    setState(() {
      this.offline = offline;
    });
    // TODO: Uncomment as part of sc-215077
    // if (offline) {
    //   _clientSubscription?.cancel();
    // } else {
    //   _clientSubscription = client.stream.listen((event) {
    //     developer.log(event.data);
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('LaunchDarkly Example')),
        body: Container(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: TextField(
                        onChanged: (text) {
                          setState(() {
                            evalKey = text;
                          });
                        },
                        decoration: const InputDecoration.collapsed(
                            hintText: 'Key', border: UnderlineInputBorder()))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0)),
                DropdownButton<String>(
                    value: typeDropdown,
                    isDense: true,
                    onChanged: (String? newValue) {
                      setState(() {
                        typeDropdown = newValue;
                      });
                    },
                    items: ['Boolean', 'Integer', 'Float', 'String', 'Json']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                          value: value, child: Text(value));
                    }).toList())
              ]),
              const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
              Row(children: [
                Expanded(
                    child: ElevatedButton(
                        onPressed: evaluate,
                        child: const Text('Evaluate'))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0)),
                Expanded(
                    child:
                        ElevatedButton(onPressed: track, child: const Text('Track')))
              ]),
              const Divider(),
              Row(children: [Text(evalResult, textAlign: TextAlign.start)]),
              const Spacer(),
              const Divider(),
              Row(children: [
                Expanded(
                    child: TextField(
                        onChanged: (text) {
                          setState(() {
                            contextKey = text;
                          });
                        },
                        decoration: const InputDecoration.collapsed(
                            hintText: 'User Key',
                            border: UnderlineInputBorder()))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0)),
                ElevatedButton(onPressed: identify, child: const Text('Identify'))
              ]),
              Row(children: [
                ElevatedButton(onPressed: flush, child: const Text('Flush')),
                const Spacer(),
                const Text('Offline'),
                Switch(value: offline, onChanged: toggleOffline)
              ])
            ])),
      ),
    );
  }
}
