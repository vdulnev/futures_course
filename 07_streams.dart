// =============================================================
// LESSON 07 — STREAMS
// Run: dart run 07_streams.dart
//
// A Stream<T> is like a Future<T> that delivers MULTIPLE values
// over time.  Think of it as an async sequence or an event bus.
//
//   Future<T>  →  one value, one time
//   Stream<T>  →  zero or more values, then done (or error)
// =============================================================

import 'dart:async';

void main() async {
  // ── 1. Creating Streams ───────────────────────────────────────
  print('--- Creating Streams ---');

  // From an iterable
  Stream<int> fromList = Stream.fromIterable([1, 2, 3, 4, 5]);
  await printAll('fromIterable', fromList);

  // Single value
  Stream<String> single = Stream.value('hello');
  await printAll('single', single);

  // From a Future
  Stream<int> fromFuture = Stream.fromFuture(computeAnswer());
  await printAll('fromFuture', fromFuture);

  // Periodic — emits every interval (limited with .take)
  Stream<int> ticker = Stream.periodic(
    Duration(milliseconds: 30),
    (tick) => tick,
  ).take(4);
  await printAll('periodic', ticker);

  // Empty stream
  Stream<int> empty = Stream.empty();
  await printAll('empty', empty);

  // ── 2. async* / yield — generator streams ────────────────────
  print('\n--- async* generator ---');

  await for (final n in countUp(1, 5)) {
    print('  countUp: $n');
  }

  await for (final word in words()) {
    print('  word: $word');
  }

  // ── 3. await for ─────────────────────────────────────────────
  print('\n--- await for ---');

  // Iterate a stream sequentially, one value at a time
  var sum = 0;
  await for (final n in Stream.fromIterable([10, 20, 30, 40])) {
    sum += n;
  }
  print('sum: $sum'); // 100

  // break out of await for
  await for (final n in countUp(1, 100)) {
    if (n > 3) break;
    print('  break example: $n');
  }

  // ── 4. .listen() ─────────────────────────────────────────────
  print('\n--- .listen() ---');

  // Non-blocking: callback fired per event
  final subscription = countUp(1, 4).listen(
    (n) => print('  listen onData: $n'),
    onError: (e) => print('  listen onError: $e'),
    onDone: () => print('  listen onDone'),
  );

  await Future.delayed(Duration(milliseconds: 50));
  await subscription.asFuture(); // wait until stream is done

  // ── 5. StreamController — push events manually ───────────────
  print('\n--- StreamController ---');

  // A single-subscription controller
  final ctrl = StreamController<String>();

  ctrl.stream.listen(
    (s) => print('  controller got: $s'),
    onDone: () => print('  controller done'),
  );

  ctrl.add('one');
  ctrl.add('two');
  ctrl.add('three');
  await ctrl.close(); // closes the stream → triggers onDone

  // ── 6. Broadcast Stream — multiple listeners ──────────────────
  print('\n--- Broadcast Stream ---');

  // A broadcast controller allows many listeners at once.
  // Regular (single-subscription) streams throw if you add a second listener.
  final broadcast = StreamController<int>.broadcast();

  broadcast.stream.listen((n) => print('  listener A: $n'));
  broadcast.stream.listen((n) => print('  listener B: ${n * 10}'));

  broadcast.add(1);
  broadcast.add(2);
  broadcast.add(3);
  await broadcast.close();
  await Future.delayed(Duration.zero); // let microtasks flush

  // ── 7. Stream.multi — multiple independent listeners ─────────
  print('\n--- Stream.multi ---');

  // Stream.multi gives each listener its own independent sequence
  final multi = Stream<int>.multi((controller) {
    controller.add(10);
    controller.add(20);
    controller.addError(Exception('mid-stream error'));
    controller.add(30);
    controller.close();
  });

  await multi.listen(
    (n) => print('  multi: $n'),
    onError: (e) => print('  multi error: $e'),
    onDone: () => print('  multi done'),
  ).asFuture();

  // ── 8. Converting a Stream to a Future ────────────────────────
  print('\n--- Stream → Future ---');

  Stream<int> s = Stream.fromIterable([3, 1, 4, 1, 5, 9, 2, 6]);

  int total = await s.fold(0, (acc, n) => acc + n);
  print('fold sum: $total');

  List<int> all = await Stream.fromIterable([1, 2, 3]).toList();
  print('toList: $all');

  int first = await Stream.fromIterable([10, 20, 30]).first;
  print('first: $first');

  // ── 9. Pausing & Cancelling ───────────────────────────────────
  print('\n--- Pause & Cancel ---');

  final sub = Stream.periodic(Duration(milliseconds: 20), (i) => i)
      .listen((n) => print('  tick: $n'));

  await Future.delayed(Duration(milliseconds: 50));
  sub.pause();
  print('  [paused]');
  await Future.delayed(Duration(milliseconds: 60));
  sub.resume();
  print('  [resumed]');
  await Future.delayed(Duration(milliseconds: 50));
  await sub.cancel();
  print('  [cancelled]');
}

// ── Helper definitions ────────────────────────────────────────────

Future<int> computeAnswer() async {
  await Future.delayed(Duration(milliseconds: 10));
  return 42;
}

// async* generator — yields values one by one
Stream<int> countUp(int from, int to) async* {
  for (int i = from; i <= to; i++) {
    await Future.delayed(Duration(milliseconds: 5));
    yield i;
  }
}

Stream<String> words() async* {
  final list = ['dart', 'is', 'awesome'];
  for (final word in list) {
    await Future.delayed(Duration(milliseconds: 10));
    yield word;
  }
}

Future<void> printAll<T>(String label, Stream<T> stream) async {
  final items = await stream.toList();
  print('$label: $items');
}
