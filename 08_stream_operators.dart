// =============================================================
// LESSON 08 — STREAM OPERATORS
// Run: dart run 08_stream_operators.dart
//
// Streams have a rich operator API — similar to Iterable but async.
// Every operator returns a new Stream (lazy, non-consuming).
// =============================================================

import 'dart:async';

void main() async {
  // ── 1. map — transform each event ────────────────────────────
  print('--- map ---');

  Stream<String> upper = nums(1, 5).map((n) => 'item-$n');
  await show('map', upper);

  Stream<int> lengths = words().map((w) => w.length);
  await show('lengths', lengths);

  // ── 2. where — filter events ──────────────────────────────────
  print('\n--- where ---');

  Stream<int> evens = nums(1, 10).where((n) => n.isEven);
  await show('evens', evens);

  Stream<String> long = words().where((w) => w.length > 3);
  await show('long words', long);

  // ── 3. take & skip ───────────────────────────────────────────
  print('\n--- take / skip ---');

  await show('take(3)', nums(1, 10).take(3));
  await show('skip(7)', nums(1, 10).skip(7));
  await show('takeWhile < 5', nums(1, 10).takeWhile((n) => n < 5));
  await show('skipWhile < 5', nums(1, 10).skipWhile((n) => n < 5));

  // ── 4. expand — flatMap / one-to-many ─────────────────────────
  print('\n--- expand ---');

  // Each input produces multiple outputs
  Stream<int> expanded = nums(1, 3).expand((n) => [n, n * 10]);
  await show('expand', expanded);

  // ── 5. asyncMap — async transform ────────────────────────────
  print('\n--- asyncMap ---');

  // Like map but the transform function is async.
  // Events are processed one-at-a-time (sequential).
  Stream<String> fetched = nums(1, 3).asyncMap((n) => fetchItem(n));
  await show('asyncMap', fetched);

  // ── 6. asyncExpand — async one-to-many ───────────────────────
  print('\n--- asyncExpand ---');

  // Each input can produce a sub-stream; sub-streams are flattened
  Stream<String> expanded2 = nums(1, 3).asyncExpand(
    (n) => Stream.fromFuture(fetchItem(n)).map((s) => '$s (from $n)'),
  );
  await show('asyncExpand', expanded2);

  // ── 7. distinct — deduplicate consecutive duplicates ─────────
  print('\n--- distinct ---');

  Stream<int> withDupes = Stream.fromIterable([1, 1, 2, 2, 2, 3, 1, 1]);
  await show('distinct', withDupes.distinct());

  // ── 8. handleError — inline error recovery ───────────────────
  print('\n--- handleError ---');

  Stream<int> withErrors = Stream.fromIterable([1, 2, 3]).asyncMap((n) async {
    if (n == 2) throw Exception('bad item $n');
    return n * 10;
  });

  await show(
    'handleError',
    withErrors.handleError(
      (e) => print('  [skipped error: $e]'),
      test: (e) => e is Exception,
    ),
  );

  // ── 9. transform — apply a StreamTransformer ─────────────────
  print('\n--- StreamTransformer ---');

  // A reusable transformer that multiplies every value by a factor
  final doubler = StreamTransformer<int, int>.fromHandlers(
    handleData: (data, sink) => sink.add(data * 2),
    handleError: (e, st, sink) => sink.addError(e, st),
    handleDone: (sink) => sink.close(),
  );

  await show('transform(doubler)', nums(1, 5).transform(doubler));

  // ── 10. Combining streams ─────────────────────────────────────
  print('\n--- merge streams (manual) ---');

  // Dart has no built-in merge; use a StreamController
  Stream<String> merged = mergeStreams([
    timedStream('A', [100, 200, 300], ['a1', 'a2', 'a3']),
    timedStream('B', [50, 150, 250], ['b1', 'b2', 'b3']),
  ]);
  await show('merged', merged);

  // ── 11. Fold & reduce ─────────────────────────────────────────
  print('\n--- fold / reduce ---');

  int sum = await nums(1, 5).fold(0, (acc, n) => acc + n);
  print('fold sum: $sum');

  int product = await nums(1, 5).reduce((a, b) => a * b);
  print('reduce product: $product');

  // ── 12. drain — consume and discard ───────────────────────────
  print('\n--- drain ---');

  await nums(1, 3)
      .map((n) { print('  side effect: $n'); return n; })
      .drain();
  print('drain complete');

  // ── 13. pipe — route one stream into a StreamConsumer ─────────
  print('\n--- pipe ---');

  final collector = CollectorSink<int>();
  await nums(1, 5).pipe(collector);
  print('piped: ${collector.items}');
}

// ── Helpers ──────────────────────────────────────────────────────

Stream<int> nums(int from, int to) =>
    Stream.fromIterable(List.generate(to - from + 1, (i) => from + i));

Stream<String> words() =>
    Stream.fromIterable(['dart', 'is', 'fun', 'async', 'stream']);

Future<void> show<T>(String label, Stream<T> stream) async {
  final items = await stream.toList();
  print('$label: $items');
}

Future<String> fetchItem(int id) async {
  await Future.delayed(Duration(milliseconds: 10));
  return 'item-$id';
}

// Emits a string after each delay in the list
Stream<String> timedStream(
  String prefix,
  List<int> delays,
  List<String> values,
) async* {
  for (var i = 0; i < values.length; i++) {
    await Future.delayed(Duration(milliseconds: delays[i]));
    yield values[i];
  }
}

// Merge multiple streams into one (interleaved)
Stream<T> mergeStreams<T>(List<Stream<T>> streams) {
  final controller = StreamController<T>();
  int active = streams.length;

  for (final stream in streams) {
    stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: () {
        active--;
        if (active == 0) controller.close();
      },
    );
  }
  return controller.stream;
}

// A StreamConsumer that collects items into a list
class CollectorSink<T> implements StreamConsumer<T> {
  final List<T> items = [];

  @override
  Future<void> addStream(Stream<T> stream) async {
    await for (final item in stream) {
      items.add(item);
    }
  }

  @override
  Future<void> close() async {}
}
