// =============================================================
// LESSON 02 — ASYNC / AWAIT
// Run: dart run 02_async_await.dart
//
// `async` and `await` are syntactic sugar over Futures.
// They make async code look and read like synchronous code.
// =============================================================

void main() async {
  // ── 1. The async keyword ──────────────────────────────────────
  // Adding `async` to a function:
  //   • lets you use `await` inside it
  //   • automatically wraps the return value in a Future
  //   • if you return String, the actual return type is Future<String>

  print('--- async function basics ---');

  // Both lines are equivalent — async wraps the return for you
  Future<int> a = Future.value(1);
  Future<int> b = returnOne(); // async function
  print('${await a} == ${await b}');

  // ── 2. await suspends and resumes ─────────────────────────────
  print('\n--- await suspends execution ---');

  print('start');
  String result = await slowUpperCase('hello');
  print('result: $result'); // execution resumes here
  print('end');

  // ── 3. Sequential awaits ──────────────────────────────────────
  print('\n--- Sequential awaits ---');

  // Each await waits for the previous one — total ≈ 300ms
  final sw = Stopwatch()..start();

  String step1 = await fetchStep('A', 100);
  String step2 = await fetchStep('B', 100);
  String step3 = await fetchStep('C', 100);

  sw.stop();
  print('$step1 → $step2 → $step3  (${sw.elapsedMilliseconds}ms)');

  // ── 4. Parallel awaits with Future.wait ───────────────────────
  print('\n--- Parallel awaits ---');

  // Run all three at once — total ≈ 100ms (the longest one)
  sw.reset(); sw.start();

  final results = await Future.wait([
    fetchStep('X', 100),
    fetchStep('Y', 80),
    fetchStep('Z', 60),
  ]);

  sw.stop();
  print('${results.join(' | ')}  (${sw.elapsedMilliseconds}ms)');

  // ── 5. async main ─────────────────────────────────────────────
  // Dart allows `main` to be async — the runtime waits for it.
  // You already see this: `void main() async { ... }`

  // ── 6. Returning values from async functions ──────────────────
  print('\n--- return types ---');

  // async functions always return a Future even if you write void
  Future<String> greeting = buildGreeting('World');
  print(await greeting);

  // Future<void> — async work with no return value
  await logMessage('lesson 02 is running');

  // ── 7. await in different contexts ───────────────────────────
  print('\n--- await in expressions ---');

  // await inside an expression
  int len = (await fetchStep('Hello', 10)).length;
  print('length: $len');

  // await in a list literal
  var trio = [
    await fetchStep('one', 10),
    await fetchStep('two', 10),
    await fetchStep('three', 10),
  ];
  print('trio: $trio'); // sequential — each awaited in order

  // ── 8. Conditional await ──────────────────────────────────────
  print('\n--- conditional await ---');

  // Demonstrate both branches by calling the helper twice
  print('cache path:   ${await loadData(useCache: true)}');
  print('network path: ${await loadData(useCache: false)}');

  // ── 9. async in loops ─────────────────────────────────────────
  print('\n--- await in loops ---');

  // Sequential — processes one at a time
  List<String> ids = ['001', '002', '003'];
  for (String id in ids) {
    String user = await fetchUser(id);
    print('  $user');
  }

  // Parallel — fire all at once, then collect
  List<String> users = await Future.wait(
    ids.map((id) => fetchUser(id)),
  );
  print('parallel: $users');

  // ── 10. async closures ────────────────────────────────────────
  print('\n--- async closures ---');

  var process = (String s) async {
    await Future.delayed(Duration(milliseconds: 10));
    return s.toUpperCase();
  };

  print(await process('async closure'));

  // Used with higher-order functions
  var processed = await Future.wait(['a', 'b', 'c'].map(process));
  print('processed: $processed');

  // ── 11. Don't forget await! ───────────────────────────────────
  print('\n--- common mistake: missing await ---');

  // BAD: returns a Future<String>, not a String — easy to miss
  // var bad = fetchUser('999');  // type is Future<String>

  // GOOD: always await async calls when you need the value
  var good = await fetchUser('999');
  print('good: $good');
}

// ── Helper async functions ────────────────────────────────────────

Future<String> loadData({required bool useCache}) async {
  if (useCache) return fromCache('users');
  return fromNetwork('users');
}

Future<int> returnOne() async => 1;

Future<String> slowUpperCase(String s) async {
  await Future.delayed(Duration(milliseconds: 50));
  return s.toUpperCase();
}

Future<String> fetchStep(String name, int ms) async {
  await Future.delayed(Duration(milliseconds: ms));
  return 'step-$name';
}

Future<String> buildGreeting(String who) async {
  await Future.delayed(Duration(milliseconds: 5));
  return 'Hello, $who!';
}

Future<void> logMessage(String msg) async {
  await Future.delayed(Duration(milliseconds: 5));
  print('  [log] $msg');
}

Future<String> fromCache(String key) async {
  await Future.delayed(Duration(milliseconds: 5));
  return 'cache:$key';
}

Future<String> fromNetwork(String key) async {
  await Future.delayed(Duration(milliseconds: 50));
  return 'network:$key';
}

Future<String> fetchUser(String id) async {
  await Future.delayed(Duration(milliseconds: 20));
  return 'User#$id';
}
