# Dart Futures Course

A hands-on course covering Dart's async model end-to-end.
Every lesson is a self-contained `.dart` file — run any of them with:

```bash
dart run <file>
```

## Prerequisites

- Dart SDK >= 3.0  (`dart --version`)

---

## Lessons

| # | File | What you will learn |
|---|------|---------------------|
| 01 | [01_future_basics.dart](01_future_basics.dart) | What a Future is, `Future.value`, `Future.error`, `Future.delayed`, `.then`, `.catchError`, `.whenComplete` |
| 02 | [02_async_await.dart](02_async_await.dart) | `async`/`await` syntax, sequential vs. parallel awaits, `async` main |
| 03 | [03_chaining.dart](03_chaining.dart) | Chaining `.then()`, transforming results, pipeline style |
| 04 | [04_combinators.dart](04_combinators.dart) | `Future.wait`, `Future.any`, `Future.wait` error modes |
| 05 | [05_error_handling.dart](05_error_handling.dart) | `try/catch/finally`, `catchError`, error propagation, re-throw |
| 06 | [06_completer.dart](06_completer.dart) | `Completer`, wrapping callbacks, timeout pattern |
| 07 | [07_streams.dart](07_streams.dart) | `Stream`, `async*`/`yield`, `StreamController`, broadcast streams |
| 08 | [08_stream_operators.dart](08_stream_operators.dart) | `map`, `where`, `asyncMap`, `take`, `listen`, `toList` |
| 09 | [09_patterns.dart](09_patterns.dart) | Retry, debounce, cache, `FutureOr<T>`, fire-and-forget |

---

## Learning Path

```
01 → 02 → 03          # core async model
         ↓
04 → 05 → 06          # combinators, errors, control
         ↓
07 → 08 → 09          # streams & real-world patterns
```

## Running All Lessons

```bash
cd futures_course
for f in *.dart; do
  echo "=== $f ==="; dart run "$f"; echo
done
```
