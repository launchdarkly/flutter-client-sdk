import 'package:launchdarkly_common_client/launchdarkly_common_client.dart';
import 'package:launchdarkly_common_client/src/context_modifiers/anonymous_context_modifier.dart';
import 'package:launchdarkly_common_client/src/persistence/persistence.dart';
import 'package:launchdarkly_dart_common/launchdarkly_dart_common.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_persistence.dart';

class MockAdapter extends Mock implements LDLogAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(LDLogRecord(
        level: LDLogLevel.debug,
        message: '',
        time: DateTime.now(),
        logTag: ''));
  });
  group('without persistence', () {
    test('it populates keys for anonymous contexts that lack them', () async {
      final context = LDContextBuilder()
          .kind('user')
          .anonymous(true)
          .kind('org', 'org-key')
          .kind('company')
          .anonymous(true)
          .build();

      final decorator =
          AnonymousContextModifier(InMemoryPersistence(), LDLogger());
      final decoratedContext = await decorator.decorate(context);

      expect(decoratedContext.attributesByKind['user']!.key, isNotEmpty);
      expect(decoratedContext.attributesByKind['company']!.key, isNotEmpty);
      expect(decoratedContext.attributesByKind['org']!.key, 'org-key');
    });

    test('it does not use the same key for all kinds', () async {
      final context = LDContextBuilder()
          .kind('user')
          .anonymous(true)
          .kind('org', 'org-key')
          .kind('company')
          .anonymous(true)
          .build();

      final decorator =
          AnonymousContextModifier(InMemoryPersistence(), LDLogger());
      final decoratedContext = await decorator.decorate(context);

      expect(decoratedContext.attributesByKind['user']!.key,
          isNot(equals(decoratedContext.attributesByKind['company']!.key)));
    });

    test('it caches the keys for each kind', () async {
      final context = LDContextBuilder()
          .kind('user')
          .anonymous(true)
          .kind('org', 'org-key')
          .kind('company')
          .anonymous(true)
          .build();

      final decorator =
          AnonymousContextModifier(InMemoryPersistence(), LDLogger());
      final decoratedContext = await decorator.decorate(context);
      final decoratedContext2 = await decorator.decorate(context);

      expect(decoratedContext.attributesByKind['user']!.key,
          decoratedContext2.attributesByKind['user']!.key);
      expect(decoratedContext.attributesByKind['company']!.key,
          decoratedContext2.attributesByKind['company']!.key);
    });
  });

  group('with persistence', () {
    test('it uses the key from persistence when one is available', () async {
      final context = LDContextBuilder()
          .kind('user')
          .anonymous(true)
          .kind('company')
          .anonymous(true)
          .build();

      final mockPersistence = MockPersistence();
      mockPersistence.storage['LaunchDarkly_AnonContextKey'] = {
        encodePersistenceKey('user'): 'the-user-key',
        encodePersistenceKey('company'): 'the-company-key',
      };
      final decorator = AnonymousContextModifier(mockPersistence, LDLogger());

      final decoratedContext = await decorator.decorate(context);

      expect(decoratedContext.attributesByKind['user']!.key, 'the-user-key');
      expect(
          decoratedContext.attributesByKind['company']!.key, 'the-company-key');
    });

    test('it persists the key to persistence when it generates one', () async {
      final context = LDContextBuilder()
          .kind('user')
          .anonymous(true)
          .kind('company')
          .anonymous(true)
          .build();

      final mockPersistence = MockPersistence();
      final decorator = AnonymousContextModifier(mockPersistence, LDLogger());

      final decoratedContext = await decorator.decorate(context);

      expect(
          decoratedContext.attributesByKind['user']!.key,
          mockPersistence.storage['LaunchDarkly_AnonContextKey']![
              encodePersistenceKey('user')]);
      expect(
          decoratedContext.attributesByKind['company']!.key,
          mockPersistence.storage['LaunchDarkly_AnonContextKey']![
              encodePersistenceKey('company')]);
    });
  });

  group('invalid context handling', () {
    test('it logs a info log when asked to modify an invalid context',
        () async {
      final invalidContext =
          LDContextBuilder().build(); // This creates an invalid context
      final mockAdapter = MockAdapter();
      final logger = LDLogger(adapter: mockAdapter, level: LDLogLevel.info);
      final decorator = AnonymousContextModifier(InMemoryPersistence(), logger);

      final result = await decorator.decorate(invalidContext);

      expect(result.valid, false);

      final logRecord = verify(() => mockAdapter.log(captureAny())).captured[0]
          as LDLogRecord;
      expect(logRecord.level, LDLogLevel.warn);
      expect(logRecord.message,
          'AnonymousContextModifier was asked to modify an invalid context and will attempt to do so. This is expected if starting with an empty context.');
    });
  });
}
