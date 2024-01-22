import 'dart:convert';

import 'package:test/test.dart';

import 'package:launchdarkly_common_client/src/flag_manager/context_index.dart';

void main() {
  test('can notice a context', () {
    final index = ContextIndex();
    index.notice('a', DateTime.fromMillisecondsSinceEpoch(600));

    final entries = index.entries;

    expect(entries.length, 1);

    expect(entries[0].msTimestamp, 600);
    expect(entries[0].id, 'a');
  });

  test('can update time for context', () {
    final index = ContextIndex();
    index.notice('a', DateTime.fromMillisecondsSinceEpoch(100));
    index.notice('a', DateTime.fromMillisecondsSinceEpoch(200));

    final entries = index.entries;

    expect(entries.length, 1);

    expect(entries[0].msTimestamp, 200);
    expect(entries[0].id, 'a');
  });

  test('can notice multiple contexts', () {
    final index = ContextIndex();
    index.notice('a', DateTime.fromMillisecondsSinceEpoch(100));
    index.notice('b', DateTime.fromMillisecondsSinceEpoch(200));

    final entries = index.entries;

    expect(entries.length, 2);

    expect(entries[0].msTimestamp, 100);
    expect(entries[0].id, 'a');

    expect(entries[1].msTimestamp, 200);
    expect(entries[1].id, 'b');
  });

  test('does not prune below limit', () {
    final index = ContextIndex();
    index.notice('c', DateTime.fromMillisecondsSinceEpoch(600));
    index.notice('a', DateTime.fromMillisecondsSinceEpoch(100));
    index.notice('b', DateTime.fromMillisecondsSinceEpoch(500));

    index.prune(5);

    final entries = index.entries;

    expect(entries.length, 3);

    expect(entries[0].msTimestamp, 600);
    expect(entries[0].id, 'c');

    expect(entries[1].msTimestamp, 100);
    expect(entries[1].id, 'a');

    expect(entries[2].msTimestamp, 500);
    expect(entries[2].id, 'b');
  });

  test('does prune over limit', () {
    final index = ContextIndex();
    index.notice('c', DateTime.fromMillisecondsSinceEpoch(600));
    index.notice('a', DateTime.fromMillisecondsSinceEpoch(100));
    index.notice('b', DateTime.fromMillisecondsSinceEpoch(500));

    index.prune(2);

    final entries = index.entries;

    expect(entries.length, 2);

    expect(entries[0].msTimestamp, 600);
    expect(entries[0].id, 'c');

    expect(entries[1].msTimestamp, 500);
    expect(entries[1].id, 'b');
  });

  test('can serialize and deserialize', () {
    final index = ContextIndex();
    index.notice('c', DateTime.fromMillisecondsSinceEpoch(600));
    index.notice('a', DateTime.fromMillisecondsSinceEpoch(100));
    index.notice('b', DateTime.fromMillisecondsSinceEpoch(500));

    final string = jsonEncode(index.toJson());
    final deserialized = ContextIndex.fromJson(jsonDecode(string));

    final entries = deserialized.entries;
    expect(entries.length, 3);

    expect(entries[0].msTimestamp, 600);
    expect(entries[0].id, 'c');

    expect(entries[1].msTimestamp, 100);
    expect(entries[1].id, 'a');

    expect(entries[2].msTimestamp, 500);
    expect(entries[2].id, 'b');
  });
}
