// =============================================================
// LESSON 01 — FUTURE BASICS
// Run: dart run 01_future_basics.dart
//
// A Future<T> represents a value that will be available at some
// point in the future — or an error if something went wrong.
// Think of it as a promise: "I'll give you a T eventually."
// =============================================================

void main() async {
  // ── 1. What is a Future? ──────────────────────────────────────
  // A Future is in one of three states:
  //   • uncompleted  — the async work hasn't finished yet
  //   • completed with a value
  //   • completed with an error

  // ── 2. Future.value — already-completed future ────────────────
  print('--- Future.value ---');

  Future<int> ready = Future.value(42);
  ready.then((v) => print('value: $v')); // prints on next microtask

  // Awaiting it synchronously with await (inside async main)
  int v = await Future.value(99);
  print('awaited: $v');

  // ── 3. Future.delayed — completes after a duration ────────────
  print('\n--- Future.delayed ---');

  print('before delay');
  await Future.delayed(Duration(milliseconds: 100));
  print('after 100ms delay');

  // Deliver a value after a delay
  String msg = await Future.delayed(
    Duration(milliseconds: 50),
    () => 'delivered after 50ms',
  );
  print(msg);

  // ── 4. Future.error — a future that always fails ──────────────
  print('\n--- Future.error ---');

  Future<int> boom = Future.error('something went wrong');
  try {
    await boom;
  } catch (e) {
    print('caught: $e');
  }

  // ── 5. Creating a Future from an async function ───────────────
  print('\n--- async function returns Future ---');

  // Any function marked `async` automatically returns a Future.
  // You don't write `return Future.value(...)` — just `return`.
  String greeting = await fetchGreeting('Alice');
  print(greeting);

  int squared = await squareAsync(7);
  print('7² = $squared');

  // ── 6. .then() — register a callback on success ───────────────
  print('\n--- .then() ---');

  fetchGreeting('Bob')
      .then((g) => print('.then got: $g'));

  await Future.delayed(Duration.zero); // let the microtask run

  // .then can transform the value (returns a new Future)
  Future<int> lengthFuture = fetchGreeting('Carol').then((g) => g.length);
  print('greeting length: ${await lengthFuture}');

  // ── 7. .catchError() — register a callback on failure ─────────
  print('\n--- .catchError() ---');

  await Future<int>.error(FormatException('bad input'))
      .catchError((e) {
        print('catchError: $e');
        return -1; // provide a fallback value
      });

  // test: only catch specific error types
  await Future<int>.error(RangeError('out of range'))
      .catchError(
        (e) { print('RangeError handler: $e'); return 0; },
        test: (e) => e is RangeError,
      )
      .catchError(
        (e) { print('fallback handler: $e'); return 0; },
      );

  // ── 8. .whenComplete() — runs regardless of success or error ──
  print('\n--- .whenComplete() ---');

  // Like finally — runs cleanup whether the future succeeds or fails
  await fetchGreeting('Dave')
      .whenComplete(() => print('  [cleanup after success]'));

  await Future<String>.error('oops')
      .catchError((e) => 'recovered')
      .whenComplete(() => print('  [cleanup after recovery]'));

  // ── 9. Checking future completion synchronously ───────────────
  print('\n--- Synchronous vs Asynchronous ---');

  // Code after creating a Future (but before awaiting) runs synchronously
  print('1 — synchronous');
  Future.delayed(Duration.zero).then((_) => print('3 — microtask (then)'));
  print('2 — synchronous');
  await Future.delayed(Duration.zero);
  print('4 — after await');

  // ── 10. Future<void> ─────────────────────────────────────────
  print('\n--- Future<void> ---');

  await saveData('my data');
  print('save complete');
}

// ── Helper async functions ────────────────────────────────────────

Future<String> fetchGreeting(String name) async {
  // Simulate network latency
  await Future.delayed(Duration(milliseconds: 10));
  return 'Hello, $name!';
}

Future<int> squareAsync(int n) async => n * n;

Future<void> saveData(String data) async {
  await Future.delayed(Duration(milliseconds: 20));
  print('  [saved: $data]');
}
