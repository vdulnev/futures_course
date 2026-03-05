// =============================================================
// LESSON 05 — ERROR HANDLING IN ASYNC CODE
// Run: dart run 05_error_handling.dart
//
// Async errors behave exactly like sync errors — they propagate
// through the Future chain until something catches them.
// =============================================================

void main() async {
  // ── 1. try / catch with await ─────────────────────────────────
  print('--- try/catch with await ---');

  // Just like synchronous code — the only change is `await`
  try {
    String data = await riskyFetch();
    print('got: $data');
  } catch (e) {
    print('caught: $e');
  }

  // Specific error types
  try {
    await parseNumber('not-a-number');
  } on FormatException catch (e) {
    print('FormatException: ${e.message}');
  } on RangeError catch (e) {
    print('RangeError: $e');
  } catch (e) {
    print('other: $e');
  }

  // ── 2. finally with async ─────────────────────────────────────
  print('\n--- finally ---');

  // finally always runs — success or failure
  try {
    await withCleanup(succeed: true);
  } finally {
    // runs even without a catch
  }

  try {
    await withCleanup(succeed: false);
  } catch (e) {
    print('caught after cleanup: $e');
  }

  // ── 3. .catchError() ─────────────────────────────────────────
  print('\n--- .catchError() ---');

  // Callback-style — equivalent to try/catch in a .then() chain
  await riskyFetch()
      .then((d) => print('success: $d'))
      .catchError((e) => print('catchError: $e'));

  // Provide a fallback value
  String safe = await riskyFetch().catchError((_) => 'fallback value');
  print('safe: $safe');

  // Selective catching with `test:`
  await Future<void>.error(FormatException('bad'))
      .catchError(
        (e) => print('  handled FormatException'),
        test: (e) => e is FormatException,
      )
      .catchError(
        (e) => print('  handled other: $e'),
      );

  // ── 4. Error propagation through chains ───────────────────────
  print('\n--- Error propagation ---');

  // An unhandled error skips all .then() callbacks and falls to .catchError()
  await Future<String>.error(Exception('step 0 failed'))
      .then((s) { print('step 1 — NEVER runs'); return s; })
      .then((s) { print('step 2 — NEVER runs'); return s; })
      .catchError((e) { print('caught at end: $e'); return 'recovered'; })
      .then((s) => print('step 3 — runs after recovery: $s'));

  // ── 5. Re-throwing ────────────────────────────────────────────
  print('\n--- Re-throw ---');

  try {
    await handleWithRethrow();
  } catch (e) {
    print('outer caught re-thrown: $e');
  }

  // ── 6. Custom exceptions ──────────────────────────────────────
  print('\n--- Custom exceptions ---');

  try {
    await fetchWithAuth(token: null);
  } on AuthException catch (e) {
    print('AuthException: ${e.message} (code ${e.code})');
  }

  try {
    await fetchWithAuth(token: 'expired');
  } on AuthException catch (e) {
    print('AuthException: ${e.message} (code ${e.code})');
  }

  try {
    await fetchWithAuth(token: 'valid');
    print('auth succeeded');
  } on AuthException catch (e) {
    print('should not happen: $e');
  }

  // ── 7. Stack traces ───────────────────────────────────────────
  print('\n--- Stack traces ---');

  try {
    await deepCallChain();
  } catch (e, stackTrace) {
    print('error: $e');
    // stackTrace contains the full async call chain
    final firstLine = stackTrace.toString().split('\n').first;
    print('first stack frame: $firstLine');
  }

  // ── 8. Uncaught async errors ──────────────────────────────────
  print('\n--- Uncaught errors ---');

  // A Future with no error handler will throw if awaited,
  // or be silently ignored if fire-and-forget.
  //
  // GOOD: always attach an error handler or await in try/catch
  Future<void> backgroundTask = runInBackground();
  backgroundTask.catchError((e) => print('background error caught: $e'));

  await Future.delayed(Duration(milliseconds: 50)); // let it complete

  // ── 9. Error in Future.wait ───────────────────────────────────
  print('\n--- Error in Future.wait ---');

  try {
    await Future.wait([
      fetchOk('A'),
      failAfter(30, 'middle failed'),
      fetchOk('B'),
    ]);
  } catch (e) {
    print('Future.wait error: $e');
  }

  // ── 10. Converting errors to results (Result pattern) ─────────
  print('\n--- Result<T, E> pattern ---');

  // Instead of throwing, return a discriminated union
  Result<String, String> r1 = await safeFetch('good');
  Result<String, String> r2 = await safeFetch('bad');

  for (final r in [r1, r2]) {
    switch (r) {
      case Ok(:final value):
        print('Ok: $value');
      case Err(:final error):
        print('Err: $error');
    }
  }
}

// ── Error-prone helpers ───────────────────────────────────────────

Future<String> riskyFetch() async {
  await Future.delayed(Duration(milliseconds: 10));
  throw Exception('network timeout');
}

Future<int> parseNumber(String s) async {
  await Future.delayed(Duration(milliseconds: 5));
  return int.parse(s); // throws FormatException
}

Future<void> withCleanup({required bool succeed}) async {
  print('  [open resource]');
  try {
    await Future.delayed(Duration(milliseconds: 10));
    if (!succeed) throw Exception('operation failed');
    print('  [operation succeeded]');
  } finally {
    print('  [close resource]'); // always runs
  }
}

Future<void> handleWithRethrow() async {
  try {
    await riskyFetch();
  } catch (e) {
    print('  inner: logging error $e');
    rethrow; // propagate to caller
  }
}

Future<void> deepCallChain() async {
  await level1();
}

Future<void> level1() async => await level2();
Future<void> level2() async => await level3();
Future<void> level3() async => throw StateError('deep error');

Future<void> runInBackground() async {
  await Future.delayed(Duration(milliseconds: 20));
  throw Exception('background failure');
}

Future<String> fetchOk(String label) async {
  await Future.delayed(Duration(milliseconds: 20));
  return 'ok-$label';
}

Future<String> failAfter(int ms, String msg) async {
  await Future.delayed(Duration(milliseconds: ms));
  throw Exception(msg);
}

// ── Custom Exception ──────────────────────────────────────────────

class AuthException implements Exception {
  final String message;
  final int code;
  AuthException(this.message, this.code);

  @override
  String toString() => 'AuthException($code): $message';
}

Future<String> fetchWithAuth({required String? token}) async {
  await Future.delayed(Duration(milliseconds: 10));
  if (token == null) throw AuthException('Missing token', 401);
  if (token == 'expired') throw AuthException('Token expired', 403);
  return 'protected data';
}

// ── Result<T, E> (simple) ────────────────────────────────────────

sealed class Result<T, E> {}

final class Ok<T, E> extends Result<T, E> {
  final T value;
  Ok(this.value);
}

final class Err<T, E> extends Result<T, E> {
  final E error;
  Err(this.error);
}

Future<Result<String, String>> safeFetch(String id) async {
  try {
    await Future.delayed(Duration(milliseconds: 10));
    if (id == 'bad') throw Exception('failed to fetch $id');
    return Ok('data-$id');
  } catch (e) {
    return Err(e.toString());
  }
}
