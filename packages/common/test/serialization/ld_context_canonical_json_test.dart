import 'dart:convert';
import 'package:launchdarkly_dart_common/src/ld_context.dart';
import 'package:launchdarkly_dart_common/src/ld_value.dart';
import 'package:launchdarkly_dart_common/src/serialization/canonicalize_json.dart';
import 'package:launchdarkly_dart_common/src/serialization/ld_context_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('LDContext canonical JSON serialization', () {
    group('single kind contexts', () {
      test('serializes basic context with sorted keys', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('name', 'Alice')
            .setString('email', 'alice@example.com')
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Keys should be sorted alphabetically
        expect(canonical, contains('"email":"alice@example.com"'));
        expect(canonical, contains('"key":"user-123"'));
        expect(canonical, contains('"kind":"user"'));
        expect(canonical, contains('"name":"Alice"'));

        // Verify email comes before key (alphabetical)
        expect(canonical.indexOf('"email"'), lessThan(canonical.indexOf('"key"')));
      });

      test('serializes context with nested objects in canonical form', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setValue(
                'address',
                LDValueObjectBuilder()
                    .addString('street', '123 Main St')
                    .addString('city', 'Springfield')
                    .addString('zip', '12345')
                    .build())
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Nested object keys should also be sorted
        expect(canonical, contains('{"city":"Springfield","street":"123 Main St","zip":"12345"}'));
      });

      test('serializes context with array values', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setValue(
                'tags',
                LDValueArrayBuilder()
                    .addString('premium')
                    .addString('beta')
                    .addString('early-access')
                    .build())
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Arrays should maintain order (not sorted)
        expect(canonical, contains('["premium","beta","early-access"]'));
      });

      test('serializes anonymous context', () {
        final context = LDContextBuilder()
            .kind('user', 'anon-123')
            .anonymous(true)
            .setString('sessionId', 'session-456')
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Verify canonical form with sorted keys
        final decoded = jsonDecode(canonical);
        expect(decoded['anonymous'], isTrue);
        expect(decoded['key'], equals('anon-123'));
        expect(decoded['sessionId'], equals('session-456'));
      });

      test('serializes context with private attributes metadata', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('email', 'alice@example.com')
            .setString('name', 'Alice')
            .addPrivateAttributes(['email'])
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Verify _meta is included and properly formatted
        expect(canonical, contains('"_meta":'));
        expect(canonical, contains('"privateAttributes":'));

        final decoded = jsonDecode(canonical);
        expect(decoded['_meta']['privateAttributes'], contains('email'));
      });

      test('event serialization with redacted attributes uses canonical form', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('email', 'alice@example.com')
            .setString('name', 'Alice')
            .setString('age', '30')
            .addPrivateAttributes(['email', 'age'])
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: true);
        final canonical = canonicalizeJson(json);

        // Verify redacted attributes are in canonical form
        final decoded = jsonDecode(canonical);
        expect(decoded['email'], isNull);
        expect(decoded['age'], isNull);
        expect(decoded['name'], equals('Alice'));
        expect(decoded['_meta']['redactedAttributes'], containsAll(['age', 'email']));
      });

      test('serializes context with numeric and boolean values', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setNum('loginCount', 42)
            .setBool('verified', true)
            .setNum('score', 99.5)
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        final decoded = jsonDecode(canonical);
        expect(decoded['loginCount'], equals(42));
        expect(decoded['verified'], isTrue);
        expect(decoded['score'], equals(99.5));
      });
    });

    group('multi-kind contexts', () {
      test('serializes multi-kind context with sorted keys', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .name('Alice')
            .kind('organization', 'org-456')
            .name('Acme Corp')
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Verify multi-kind structure
        expect(canonical, contains('"kind":"multi"'));

        // Verify both contexts are present and keys within each are sorted
        final decoded = jsonDecode(canonical);
        expect(decoded['kind'], equals('multi'));
        expect(decoded['user']['key'], equals('user-123'));
        expect(decoded['user']['name'], equals('Alice'));
        expect(decoded['organization']['key'], equals('org-456'));
        expect(decoded['organization']['name'], equals('Acme Corp'));
      });

      test('serializes multi-kind context with complex nested data', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setValue(
                'preferences',
                LDValueObjectBuilder()
                    .addBool('notifications', true)
                    .addString('theme', 'dark')
                    .addNum('fontSize', 14)
                    .build())
            .kind('organization', 'org-456')
            .setValue(
                'features',
                LDValueArrayBuilder()
                    .addString('sso')
                    .addString('audit-logs')
                    .build())
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        final decoded = jsonDecode(canonical);

        // Verify nested objects have sorted keys
        expect(decoded['user']['preferences']['fontSize'], equals(14));
        expect(decoded['user']['preferences']['notifications'], isTrue);
        expect(decoded['user']['preferences']['theme'], equals('dark'));

        // Verify arrays maintain order
        expect(decoded['organization']['features'], equals(['sso', 'audit-logs']));
      });

      test('event serialization with allAttributesPrivate in multi-kind context', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('email', 'user@example.com')
            .kind('organization', 'org-456')
            .setString('domain', 'example.com')
            .build();

        final json = LDContextSerialization.toJson(context,
            isEvent: true, allAttributesPrivate: true);
        final canonical = canonicalizeJson(json);

        final decoded = jsonDecode(canonical);

        // All custom attributes should be redacted
        expect(decoded['user']['email'], isNull);
        expect(decoded['organization']['domain'], isNull);

        // Verify both contexts have redactedAttributes in _meta
        expect(decoded['user']['_meta']['redactedAttributes'], isNotEmpty);
        expect(decoded['organization']['_meta']['redactedAttributes'], isNotEmpty);
      });

      test('serializes multi-kind context with anonymous context', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .name('Alice')
            .kind('session', 'session-789')
            .anonymous(true)
            .setString('deviceId', 'device-abc')
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        final decoded = jsonDecode(canonical);
        expect(decoded['kind'], equals('multi'));
        expect(decoded['session']['anonymous'], isTrue);
        expect(decoded['session']['deviceId'], equals('device-abc'));
      });

      test('redactAnonymous only affects anonymous contexts in multi-kind', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('email', 'user@example.com')
            .kind('session', 'session-789')
            .anonymous(true)
            .setString('deviceId', 'device-abc')
            .build();

        final json = LDContextSerialization.toJson(context,
            isEvent: true, redactAnonymous: true);
        final canonical = canonicalizeJson(json);

        final decoded = jsonDecode(canonical);

        // User context should not be redacted
        expect(decoded['user']['email'], equals('user@example.com'));
        expect(decoded['user']['_meta'], isNull);

        // Session context should be fully redacted
        expect(decoded['session']['deviceId'], isNull);
        expect(decoded['session']['_meta']['redactedAttributes'], contains('/deviceId'));
      });
    });

    group('canonical JSON properties', () {
      test('canonicalized JSON is deterministic', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('z', 'last')
            .setString('a', 'first')
            .setString('m', 'middle')
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);

        final canonical1 = canonicalizeJson(json);
        final canonical2 = canonicalizeJson(json);

        expect(canonical1, equals(canonical2));
      });

      test('canonicalized JSON is compact (no whitespace)', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('name', 'Alice')
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Should not contain any extra whitespace
        expect(canonical, isNot(contains('  ')));
        expect(canonical, isNot(contains('\n')));
        expect(canonical, isNot(contains('\t')));
      });

      test('canonicalized JSON has sorted keys at all levels', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setValue(
                'nested',
                LDValueObjectBuilder()
                    .addValue(
                        'deeper',
                        LDValueObjectBuilder()
                            .addString('z', 'last')
                            .addString('a', 'first')
                            .build())
                    .build())
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Verify nested keys are sorted
        expect(canonical, contains('{"a":"first","z":"last"}'));
      });

      test('canonicalized JSON handles special characters correctly', () {
        final context = LDContextBuilder()
            .kind('user', 'user-123')
            .setString('quote', 'He said "hello"')
            .setString('backslash', 'path\\to\\file')
            .setString('newline', 'line1\nline2')
            .build();

        final json = LDContextSerialization.toJson(context, isEvent: false);
        final canonical = canonicalizeJson(json);

        // Should properly escape special characters
        expect(canonical, contains('\\"'));
        expect(canonical, contains('\\\\'));
        expect(canonical, contains('\\n'));

        // Verify it can be parsed back
        final decoded = jsonDecode(canonical);
        expect(decoded['quote'], equals('He said "hello"'));
        expect(decoded['backslash'], equals('path\\to\\file'));
        expect(decoded['newline'], equals('line1\nline2'));
      });
    });
  });
}
