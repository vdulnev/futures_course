// =============================================================
// LESSON 06 — COMPLETER
// Run: dart run 06_completer.dart
//
// A Completer<T> separates the production of a Future from its
// consumption.  It gives you manual control: complete it with a
// value or an error from anywhere in your code.
//
// Common uses:
//   • Wrap callback-based APIs into Futures
//   • Implement timeout patterns
//   • Signal between isolates / event handlers
// =============================================================

import 'dart:async';

void main() async {
  // ── 1. Basic Completer ────────────────────────────────────────
  print('--- Basic Completer ---');

  // Create a completer — it holds a Future that is not yet resolved
  final completer = Completer<String>();

  // Hand out the Future to whoever needs the value
  final future = completer.future;
  print('isCompleted before: ${completer.isCompleted}'); // false

  // Complete it from anywhere (here: immediately)
  completer.complete('hello from completer');
  print('isCompleted after: ${completer.isCompleted}');  // true

  print('value: ${await future}');

  // ── 2. Complete with an error ─────────────────────────────────
  print('\n--- Complete with error ---');

  final errCompleter = Completer<int>();
  errCompleter.completeError(Exception('something went wrong'));

  try {
    await errCompleter.future;
  } catch (e) {
    print('caught: $e');
  }

  // ── 3. Wrapping a callback API ────────────────────────────────
  print('\n--- Wrapping callbacks ---');

  // Imagine a legacy SDK with a callback-based API.
  // We convert it to a Future using a Completer.
  String result = await convertCallbackToFuture();
  print('result: $result');

  // ── 4. Timeout pattern ────────────────────────────────────────
  print('\n--- Timeout ---');

  try {
    String data = await fetchWithTimeout(
      slowOperation(),
      timeout: Duration(milliseconds: 80),
    );
    print('got: $data');
  } on TimeoutException catch (e) {
    print('timed out: $e');
  }

  // Fast operation — succeeds before timeout
  String fast = await fetchWithTimeout(
    fastOperation(),
    timeout: Duration(milliseconds: 200),
  );
  print('fast got: $fast');

  // ── 5. One-time event signal ──────────────────────────────────
  print('\n--- One-time event signal ---');

  final ready = ReadySignal();

  // Simulate something marking the system as ready after a delay
  Future.delayed(Duration(milliseconds: 50), ready.markReady);

  print('waiting for ready signal...');
  await ready.onReady;
  print('system is ready!');

  // Any subsequent await on onReady resolves immediately
  await ready.onReady;
  print('already ready — resolved instantly');

  // ── 6. Completer in a class (lazy initialization) ─────────────
  print('\n--- Lazy async initialization ---');

  final service = LazyService();
  print('before first call');
  print(await service.getValue());
  print(await service.getValue()); // second call: uses cached future
  print(await service.getValue()); // third call: still cached

  // ── 7. Converting a Stream to a Future via Completer ──────────
  print('\n--- Stream to Future via Completer ---');

  final lastValue = await firstMatchingValue(
    Stream.periodic(Duration(milliseconds: 20), (i) => i).take(10),
    (n) => n > 4,
  );
  print('first value > 4: $lastValue');

  // ── 8. Multiple listeners sharing one Future ──────────────────
  print('\n--- Shared Future from Completer ---');

  final sharedCompleter = Completer<String>();
  final sharedFuture = sharedCompleter.future;

  // Two listeners on the same Future
  sharedFuture.then((v) => print('listener A: $v'));
  sharedFuture.then((v) => print('listener B: $v'));

  await Future.delayed(Duration(milliseconds: 30));
  sharedCompleter.complete('shared value');
  await Future.delayed(Duration.zero); // let microtasks run
}

// ── Helpers ──────────────────────────────────────────────────────

// 3. Wrap callback → Future
Future<String> convertCallbackToFuture() {
  final completer = Completer<String>();

  // Simulated callback-based API
  legacyCallbackApi(
    onSuccess: (value) => completer.complete(value),
    onError: (error) => completer.completeError(error),
  );

  return completer.future;
}

void legacyCallbackApi({
  required void Function(String) onSuccess,
  required void Function(Object) onError,
}) {
  // Simulate async work via a timer (no await here — pure callbacks)
  Future.delayed(Duration(milliseconds: 30), () {
    onSuccess('callback result');
  });
}

// 4. Timeout wrapper
Future<T> fetchWithTimeout<T>(
  Future<T> operation, {
  required Duration timeout,
}) {
  final completer = Completer<T>();

  // Start the operation
  operation.then(
    (v) { if (!completer.isCompleted) completer.complete(v); },
    onError: (e, st) { if (!completer.isCompleted) completer.completeError(e, st); },
  );

  // Start the timer
  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      completer.completeError(
        TimeoutException('operation timed out', timeout),
      );
    }
  });

  return completer.future;
}

Future<String> slowOperation() async {
  await Future.delayed(Duration(milliseconds: 150));
  return 'slow result';
}

Future<String> fastOperation() async {
  await Future.delayed(Duration(milliseconds: 40));
  return 'fast result';
}

// 5. One-time ready signal
class ReadySignal {
  final _completer = Completer<void>();

  Future<void> get onReady => _completer.future;

  void markReady() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

// 6. Lazy async init
class LazyService {
  Future<String>? _future;

  Future<String> getValue() {
    // Only run initialization once — reuse the same Future
    _future ??= _initialize();
    return _future!;
  }

  Future<String> _initialize() async {
    print('  [initializing service...]');
    await Future.delayed(Duration(milliseconds: 30));
    return 'service value';
  }
}

// 7. Completer to get first matching value from a Stream
Future<T> firstMatchingValue<T>(Stream<T> stream, bool Function(T) test) {
  final completer = Completer<T>();
  StreamSubscription<T>? subscription;

  subscription = stream.listen(
    (value) {
      if (!completer.isCompleted && test(value)) {
        completer.complete(value);
        subscription?.cancel();
      }
    },
    onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    },
    onDone: () {
      if (!completer.isCompleted) {
        completer.completeError(StateError('stream ended without a match'));
      }
    },
  );

  return completer.future;
}
