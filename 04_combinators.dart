// =============================================================
// LESSON 04 -- COMBINATORS: Future.wait, Future.any, Future.wait eagerError
// Run: dart run 04_combinators.dart
//
// Combinators let you coordinate multiple Futures at once:
//   • Future.wait  -- all must succeed
//   • Future.any   -- first to complete wins
//   • Future.wait with eagerError -- fail fast on first error
// =============================================================

import 'dart:async';

void main() async {
  // ── 1. Future.wait -- run in parallel, collect all results ─────
  print('--- Future.wait ---');

  // Fires all three at the same time; waits for ALL to finish.
  // Total time ≈ max(100, 80, 60) = 100ms  (not 240ms sequential)
  final sw = Stopwatch()..start();

  List<String> results = await Future.wait([
    fetchData('A', 100),
    fetchData('B', 80),
    fetchData('C', 60),
  ]);

  sw.stop();
  print('results: $results  (${sw.elapsedMilliseconds}ms)');
  // Order in results matches the order of the input list

  // ── 2. Future.wait with different types ───────────────────────
  print('\n--- Future.wait -- heterogeneous results ---');

  // Use separate awaits if types differ, or accept List<dynamic>
  final (userName, userAge, userScore) = await (
    fetchName(1),
    fetchAge(1),
    fetchScore(1),
  ).wait; // Record .wait extension (Dart 3.0+)

  print('name=$userName  age=$userAge  score=$userScore');

  // Alternative with Future.wait<dynamic>
  final mixed = await Future.wait<dynamic>([
    fetchName(2),
    fetchAge(2),
    fetchScore(2),
  ]);
  print('mixed: name=${mixed[0]}  age=${mixed[1]}  score=${mixed[2]}');

  // ── 3. Future.any -- first to complete wins ────────────────────
  print('\n--- Future.any ---');

  // Returns the value of whichever Future completes first.
  // Other Futures are still running but their results are ignored.
  sw.reset();
  sw.start();

  String fastest = await Future.any([
    fetchData('slow', 200),
    fetchData('medium', 100),
    fetchData('fast', 30),
  ]);

  sw.stop();
  print('fastest: $fastest  (${sw.elapsedMilliseconds}ms)');

  // Use case: race a primary source against a backup
  String content = await Future.any([
    fetchFromPrimary(), // might be slow
    fetchFromMirror(), // backup, possibly faster
  ]);
  print('content from racing: $content');

  // ── 4. Future.wait with eagerError (fail-fast) ────────────────
  print('\n--- Future.wait eagerError=true ---');

  // By default Future.wait waits for ALL futures even if some fail,
  // then throws the first error.
  //
  // eagerError: true  →  throws as soon as the first error arrives.
  try {
    await Future.wait([
      fetchData('ok-1', 30),
      failingFetch('bad', 50),
      fetchData('ok-2', 100),
    ], eagerError: true);
  } catch (e) {
    print('eagerError caught: $e');
  }

  // ── 5. Future.wait without eagerError (default) ───────────────
  print('\n--- Future.wait eagerError=false (default) ---');

  // All futures run to completion, but the overall future fails.
  // You lose access to partial results from the list.
  try {
    await Future.wait([
      fetchData('ok-1', 30),
      failingFetch('bad', 50),
      fetchData('ok-2', 20),
    ]);
  } catch (e) {
    print('default caught: $e');
  }

  // ── 6. Collect partial results despite errors ─────────────────
  print('\n--- Partial results despite errors ---');

  // Wrap each Future so it never throws -- instead returns a sentinel
  final safeResults = await Future.wait(
    ['ok', 'bad', 'ok2'].map<Future<(String, Object?)>>((id) async {
      try {
        final v = await fetchOrThrow(id);
        return (v, null);
      } catch (e) {
        return ('', e);
      }
    }),
  );

  for (final (value, error) in safeResults) {
    if (error != null) {
      print('  error: $error');
    } else {
      print('  value: $value');
    }
  }

  // ── 7. Future.wait on an empty list ───────────────────────────
  print('\n--- Empty Future.wait ---');

  final empty = await Future.wait(<Future<int>>[]);
  print('empty result: $empty'); // []

  // ── 8. Parallel with independent error handling ───────────────
  print('\n--- Independent error handling ---');

  // Each Future handles its own error; Future.wait sees them all succeed
  final handled = await Future.wait([
    fetchOrThrow('ok').catchError((_) => 'fallback-1'),
    fetchOrThrow('bad').catchError((_) => 'fallback-2'),
    fetchOrThrow('ok2').catchError((_) => 'fallback-3'),
  ]);
  print('handled results: $handled');

  // ── 9. Building a parallel map utility ───────────────────────
  print('\n--- Parallel map ---');

  // Apply an async transform to every element concurrently
  List<String> ids = ['u1', 'u2', 'u3', 'u4'];
  List<String> users = await Future.wait(ids.map(loadUser));
  print('users: $users');

  // ── 10. Parallel execution on Records ────────────────────────
  print('\n--- Parallel execution on Records ---');

  // Records preserve static types -- no casting needed.
  // The three futures run concurrently; total time ≈ max(delays).

  // Sequential baseline for comparison
  sw.reset();
  sw.start();
  final seqName = await fetchName(42);
  final seqAge = await fetchAge(42);
  final seqScore = await fetchScore(42);
  sw.stop();
  print(
    'sequential: name=$seqName  age=$seqAge  score=$seqScore  '
    '(${sw.elapsedMilliseconds}ms)',
  );

  // Parallel using Record .wait -- fires all three at the same time
  sw.reset();
  sw.start();
  final (parName, parAge, parScore) = await (
    fetchName(42), // 20 ms
    fetchAge(42), // 15 ms
    fetchScore(42), // 10 ms
  ).wait; // total ≈ 20 ms, not 45 ms
  sw.stop();
  print(
    'parallel:   name=$parName  age=$parAge  score=$parScore  '
    '(${sw.elapsedMilliseconds}ms)',
  );

  // Records also work with completely unrelated return types
  final (profilePic, friendCount, isPremium) = await (
    fetchProfilePic(42), // Future<String>
    fetchFriendCount(42), // Future<int>
    fetchIsPremium(42), // Future<bool>
  ).wait;
  print('profile: pic=$profilePic  friends=$friendCount  premium=$isPremium');

  // ── 11. Record .wait with errors ─────────────────────────────
  print('\n--- Record .wait with errors ---');

  // If ANY future in the record throws, .wait rethrows immediately
  // (same behaviour as Future.wait with eagerError: true).
  try {
    final (x, y, z) = await (
      fetchName(99), // ok
      failingFetch('bad', 20), // throws after 20 ms
      fetchScore(99), // ok, but result is discarded
    ).wait;
    print('x: $x y: $y z: $z');
  } on ParallelWaitError<
    (String?, String?, double?),   // partial values -- null where future failed
    (AsyncError?, AsyncError?, AsyncError?)  // per-slot errors
  > catch (e) {
    // Access successful partial results (non-null where future succeeded)
    final name = e.values.$1;          // 'Alice' -- this one succeeded
    print('partial name: $name');

    // Access per-slot error (null where future succeeded)
    if (e.errors.$2 != null) {
      print('slot 2 error: ${e.errors.$2!.error}');
    }
  } catch (e, s) {
    print('Exception details:\n $e');
    print('Stack trace:\n $s');
  }

  // To tolerate partial failures, wrap each future with catchError
  // before placing it in the record.
  final (safeName, safeCount, safePremium) = await (
    fetchName(99).catchError((_) => 'unknown'),
    fetchFriendCount(99).catchError((_) => 0),
    fetchIsPremium(99).catchError((_) => false),
  ).wait;
  print(
    'safe record: name=$safeName  friends=$safeCount  premium=$safePremium',
  );
}

// ── Helpers ──────────────────────────────────────────────────────

Future<String> fetchData(String label, int ms) async {
  await Future.delayed(Duration(milliseconds: ms));
  return 'data-$label';
}

Future<String> failingFetch(String label, int ms) async {
  await Future.delayed(Duration(milliseconds: ms));
  throw Exception('fetch failed for $label');
}

Future<String> fetchOrThrow(String id) async {
  await Future.delayed(Duration(milliseconds: 20));
  if (id == 'bad') throw Exception('bad id');
  return 'result-$id';
}

Future<String> fetchFromPrimary() async {
  await Future.delayed(Duration(milliseconds: 120));
  return 'primary data';
}

Future<String> fetchFromMirror() async {
  await Future.delayed(Duration(milliseconds: 40));
  return 'mirror data';
}

Future<String> fetchName(int id) async {
  await Future.delayed(Duration(milliseconds: 20));
  return 'Alice';
}

Future<int> fetchAge(int id) async {
  await Future.delayed(Duration(milliseconds: 15));
  return 30;
}

Future<double> fetchScore(int id) async {
  await Future.delayed(Duration(milliseconds: 10));
  return 98.5;
}

Future<String> loadUser(String id) async {
  await Future.delayed(Duration(milliseconds: 30));
  return 'User($id)';
}

Future<String> fetchProfilePic(int id) async {
  await Future.delayed(Duration(milliseconds: 25));
  return 'https://cdn.example.com/avatar/$id.png';
}

Future<int> fetchFriendCount(int id) async {
  await Future.delayed(Duration(milliseconds: 20));
  return 42;
}

Future<bool> fetchIsPremium(int id) async {
  await Future.delayed(Duration(milliseconds: 15));
  return true;
}

// ── Record .wait extension (Dart 3.0) ────────────────────────────
// The built-in extension lets you await a Record of Futures:
//   (futureA, futureB).wait  →  Future<(A, B)>
// It's already available in the Dart SDK -- nothing to import.
// On error it throws ParallelWaitError, giving access to partial
// results and per-slot AsyncError details.
