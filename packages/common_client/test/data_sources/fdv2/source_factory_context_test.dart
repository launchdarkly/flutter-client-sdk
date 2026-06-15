import 'dart:convert';

import 'package:launchdarkly_common_client/src/config/service_endpoints.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/cache_initializer.dart';
import 'package:launchdarkly_common_client/src/data_sources/fdv2/source_factory_context.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart'
    hide ServiceEndpoints;
import 'package:test/test.dart';

void main() {
  group('SourceFactoryContext.fromClientConfig', () {
    test(
        'contextJson matches jsonEncode(LDContextSerialization.toJson '
        '(context, isEvent: false))', () {
      final context = LDContextBuilder()
          .kind('user', 'alice')
          .name('Alice')
          .setString('segment', 'beta')
          .build();
      final logger = LDLogger(level: LDLogLevel.error);
      final httpProperties = HttpProperties();
      final endpoints = ServiceEndpoints.custom(polling: 'https://poll.test');
      Future<CachedFlags?> reader(LDContext _) async => null;

      final ctx = SourceFactoryContext.fromClientConfig(
        credential: 'test-credential',
        context: context,
        logger: logger,
        httpProperties: httpProperties,
        serviceEndpoints: endpoints,
        withReasons: true,
        defaultPollingInterval: const Duration(seconds: 42),
        cachedFlagsReader: reader,
      );

      final expected = jsonEncode(
        LDContextSerialization.toJson(context, isEvent: false),
      );
      expect(ctx.contextJson, expected);
    });

    test(
        'contextJson differs from isEvent: true serialization for anonymous '
        'context when redaction would apply', () {
      final context = LDContextBuilder()
          .kind('user', 'key1')
          .anonymous(true)
          .setString('email', 'a@b.c')
          .build();
      final logger = LDLogger(level: LDLogLevel.error);
      final endpoints = ServiceEndpoints.custom(polling: 'https://poll.test');
      Future<CachedFlags?> reader(LDContext _) async => null;

      final ctx = SourceFactoryContext.fromClientConfig(
        credential: 'test-credential',
        context: context,
        logger: logger,
        httpProperties: HttpProperties(),
        serviceEndpoints: endpoints,
        withReasons: false,
        defaultPollingInterval: const Duration(seconds: 300),
        cachedFlagsReader: reader,
      );

      final nonEvent = jsonEncode(
        LDContextSerialization.toJson(context, isEvent: false),
      );
      final asEvent = jsonEncode(
        LDContextSerialization.toJson(
          context,
          isEvent: true,
          redactAnonymous: true,
        ),
      );

      expect(ctx.contextJson, nonEvent);
      expect(ctx.contextJson, isNot(asEvent));
    });

    test(
        'decoded contextJson is a multi-kind payload when context has '
        'multiple kinds', () {
      final context =
          LDContextBuilder().kind('user', 'u1').kind('org', 'o1').build();
      final logger = LDLogger(level: LDLogLevel.error);
      final endpoints = ServiceEndpoints.custom(polling: 'https://poll.test');
      Future<CachedFlags?> reader(LDContext _) async => null;

      final ctx = SourceFactoryContext.fromClientConfig(
        credential: 'test-credential',
        context: context,
        logger: logger,
        httpProperties: HttpProperties(),
        serviceEndpoints: endpoints,
        withReasons: false,
        defaultPollingInterval: const Duration(seconds: 300),
        cachedFlagsReader: reader,
      );

      final decoded = jsonDecode(ctx.contextJson) as Map<String, dynamic>;
      expect(decoded['kind'], 'multi');
      expect(decoded['user'], isA<Map<String, dynamic>>());
      expect(decoded['org'], isA<Map<String, dynamic>>());
    });

    test(
        'passes through context, logger, endpoints, flags, and optional '
        'httpClientFactory', () {
      final context = LDContextBuilder().kind('user', 'k').build();
      final logger = LDLogger(level: LDLogLevel.warn);
      final httpProperties = HttpProperties();
      final endpoints = ServiceEndpoints.custom(
        polling: 'https://p.example',
        streaming: 'https://s.example',
      );
      Future<CachedFlags?> reader(LDContext _) async => null;

      HttpClient httpClientFactory(HttpProperties p) =>
          HttpClient(httpProperties: p);

      final ctx = SourceFactoryContext.fromClientConfig(
        credential: 'test-credential',
        context: context,
        logger: logger,
        httpProperties: httpProperties,
        serviceEndpoints: endpoints,
        withReasons: false,
        defaultPollingInterval: const Duration(minutes: 5),
        cachedFlagsReader: reader,
        httpClientFactory: httpClientFactory,
      );

      expect(ctx.context, same(context));
      expect(ctx.logger, same(logger));
      expect(ctx.httpProperties, same(httpProperties));
      expect(ctx.serviceEndpoints, same(endpoints));
      expect(ctx.withReasons, isFalse);
      expect(ctx.defaultPollingInterval, const Duration(minutes: 5));
      expect(ctx.cachedFlagsReader, same(reader));
      expect(ctx.httpClientFactory, same(httpClientFactory));
    });
  });
}
