// =============================================================
// LESSON 09 — REAL-WORLD PATTERNS
// Run: dart run 09_patterns.dart
//
// Practical async patterns you'll reach for in real projects:
//   • Retry with backoff
//   • In-memory async cache
//   • Debounce / throttle
//   • FutureOr<T>
//   • Fire-and-forget with error guard
//   • Cancellable operation
//   • Sequential queue
// =============================================================

import 'dart:async';

void main() async {
  // ── 1. Retry with exponential back-off ───────────────────────
  print('--- Retry ---');

  // Flaky operations often succeed on the second or third attempt.
  int attempt = 0;
  try {
    final result = await retry(
      () async {
        attempt++;
        print('  attempt $attempt');
        if (attempt < 3) throw Exception('transient error');
        return 'success on attempt $attempt';
      },
      maxAttempts: 5,
      delay: Duration(milliseconds: 20),
    );
    print('retry result: $result');
  } catch (e) {
    print('all attempts failed: $e');
  }

  // ── 2. In-memory async cache ──────────────────────────────────
  print('\n--- Async cache ---');

  final cache = AsyncCache<String, String>();

  // First call — expensive computation
  String v1 = await cache.get('key1', () => expensiveFetch('key1'));
  String v2 = await cache.get('key1', () => expensiveFetch('key1')); // cached
  String v3 = await cache.get('key2', () => expensiveFetch('key2')); // new

  print('v1: $v1, v2 (cached): $v2, v3: $v3');
  print('cache size: ${cache.size}');

  cache.invalidate('key1');
  String v4 = await cache.get('key1', () => expensiveFetch('key1')); // refetched
  print('after invalidate: $v4');

  // ── 3. Debounce ───────────────────────────────────────────────
  print('\n--- Debounce ---');

  // Only execute after a quiet period — useful for search-as-you-type
  final debounced = Debounce<String>(Duration(milliseconds: 50));

  debounced.call('a');
  debounced.call('ab');
  debounced.call('abc');     // only this one fires (after 50ms quiet)

  await Future.delayed(Duration(milliseconds: 80));

  debounced.call('dart');
  debounced.call('dart f');  // only this one fires
  debounced.onCall = (v) => print('debounced: $v');

  await Future.delayed(Duration(milliseconds: 80));
  debounced.dispose();

  // ── 4. FutureOr<T> ────────────────────────────────────────────
  print('\n--- FutureOr<T> ---');

  // FutureOr<T> accepts EITHER a T or a Future<T>.
  // Useful when a function may or may not need to do async work.
  print(await resolve(42));          // sync value
  print(await resolve(Future.value(99))); // async value

  // Real use: a cache that returns synchronously when warm
  final smartCache = SmartCache<String>();
  print(await smartCache.get('x', () async => 'computed')); // misses → async
  print(await smartCache.get('x', () async => 'computed')); // hits  → sync

  // ── 5. Fire-and-forget with error guard ───────────────────────
  print('\n--- Fire-and-forget ---');

  // Sometimes you start async work but don't need to await it.
  // Always attach an error handler to avoid unhandled rejections.
  unawaited(backgroundJob('job-1'));
  unawaited(backgroundJob('job-2'));

  print('jobs kicked off, continuing...');
  await Future.delayed(Duration(milliseconds: 60)); // let them finish

  // ── 6. Cancellable operation ──────────────────────────────────
  print('\n--- Cancellable operation ---');

  final token = CancellationToken();

  // Cancel after 50ms
  Future.delayed(Duration(milliseconds: 50), token.cancel);

  try {
    await cancellableWork(token, steps: 5, stepMs: 30);
    print('work completed');
  } on CancelledException catch (e) {
    print('cancelled: $e');
  }

  // ── 7. Sequential async queue ─────────────────────────────────
  print('\n--- Sequential queue ---');

  // Enqueue tasks; they run one at a time in order.
  final queue = AsyncQueue();

  // Enqueue without awaiting each individually
  final f1 = queue.add(() => task('T1', 40));
  final f2 = queue.add(() => task('T2', 20));
  final f3 = queue.add(() => task('T3', 10));

  print('results: ${await Future.wait([f1, f2, f3])}');
  // T1 finishes first despite being slowest — they run in ORDER
}

// ── Pattern implementations ───────────────────────────────────────

// 1. Retry
Future<T> retry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration delay = Duration.zero,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    try {
      return await operation();
    } catch (e) {
      if (i == maxAttempts - 1) rethrow;
      // Exponential back-off
      await Future.delayed(delay * (1 << i));
    }
  }
  throw StateError('unreachable');
}

// 2. Async cache
class AsyncCache<K, V> {
  final _store = <K, V>{};
  final _inflight = <K, Future<V>>{};

  int get size => _store.length;

  Future<V> get(K key, Future<V> Function() loader) async {
    if (_store.containsKey(key)) {
      print('  [cache hit: $key]');
      return _store[key]!;
    }
    // Coalesce concurrent requests for the same key
    _inflight[key] ??= loader().then((v) {
      _store[key] = v;
      _inflight.remove(key);
      return v;
    });
    return _inflight[key]!;
  }

  void invalidate(K key) => _store.remove(key);
  void clear() => _store.clear();
}

Future<String> expensiveFetch(String key) async {
  print('  [fetching $key...]');
  await Future.delayed(Duration(milliseconds: 20));
  return 'value-$key';
}

// 3. Debounce
class Debounce<T> {
  final Duration wait;
  Timer? _timer;
  void Function(T)? onCall;

  Debounce(this.wait);

  void call(T value) {
    _timer?.cancel();
    _timer = Timer(wait, () => onCall?.call(value));
  }

  void dispose() => _timer?.cancel();
}

// 4. FutureOr<T>
Future<T> resolve<T>(FutureOr<T> value) async => value;

class SmartCache<V> {
  final _store = <String, V>{};

  FutureOr<V> get(String key, Future<V> Function() loader) {
    if (_store.containsKey(key)) {
      print('  [sync hit: $key]');
      return _store[key]!; // synchronous — returns V directly
    }
    return loader().then((v) {
      _store[key] = v;
      print('  [async miss: $key → $v]');
      return v;
    });
  }
}

// 5. Fire-and-forget helper
void unawaited(Future<void> future) {
  future.catchError((e) => print('  [unawaited error: $e]'));
}

Future<void> backgroundJob(String name) async {
  await Future.delayed(Duration(milliseconds: 40));
  print('  $name done');
}

// 6. Cancellable operation
class CancelledException implements Exception {
  @override
  String toString() => 'CancelledException';
}

class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

Future<void> cancellableWork(
  CancellationToken token, {
  required int steps,
  required int stepMs,
}) async {
  for (int i = 0; i < steps; i++) {
    if (token.isCancelled) throw CancelledException();
    await Future.delayed(Duration(milliseconds: stepMs));
    print('  step ${i + 1}/$steps done');
  }
}

// 7. Sequential async queue
class AsyncQueue {
  Future<void> _last = Future.value();

  Future<T> add<T>(Future<T> Function() task) {
    // Chain onto the end of the queue
    final result = _last.then((_) => task());
    // Advance the tail, swallow errors so the queue doesn't stall
    _last = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}

Future<String> task(String name, int ms) async {
  print('  [$name] start');
  await Future.delayed(Duration(milliseconds: ms));
  print('  [$name] done');
  return name;
}
