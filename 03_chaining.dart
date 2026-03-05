// =============================================================
// LESSON 03 — CHAINING FUTURES
// Run: dart run 03_chaining.dart
//
// Futures can be chained: the result of one feeds into the next.
// .then() returns a NEW Future, enabling pipelines.
// =============================================================

void main() async {
  // ── 1. Basic .then() chain ────────────────────────────────────
  print('--- Basic .then() chain ---');

  // Each .then() receives the previous value and returns a new one.
  // The type can change at each step.
  final result = await Future.value('  hello, world!  ')
      .then((s) => s.trim())          // String → String
      .then((s) => s.toUpperCase())   // String → String
      .then((s) => s.split(', '))     // String → List<String>
      .then((list) => list.length);   // List   → int

  print('chain result: $result'); // 2

  // ── 2. Async .then() (returning a Future inside .then) ────────
  print('\n--- Async steps in a chain ---');

  // If the callback inside .then() returns a Future, Dart automatically
  // "flattens" it — you don't get Future<Future<T>>, just Future<T>.
  String data = await fetchId()
      .then((id) => fetchUser(id))        // id → Future<User>
      .then((user) => fetchProfile(user)) // user → Future<Profile>
      .then((profile) => profile.summary);

  print('pipeline result: $data');

  // ── 3. Equivalent async/await version ────────────────────────
  print('\n--- Same pipeline with async/await ---');

  // Easier to read for longer chains
  final id = await fetchId();
  final user = await fetchUser(id);
  final profile = await fetchProfile(user);
  print('step-by-step result: ${profile.summary}');

  // ── 4. Transforming types along the chain ─────────────────────
  print('\n--- Type transformation chain ---');

  // String → int → double → String
  String formatted = await Future.value('42')
      .then(int.parse)              // pass function directly
      .then((n) => n * 1.5)
      .then((d) => d.toStringAsFixed(2));

  print('transformed: $formatted'); // 63.00

  // ── 5. Mixing .then() with await ──────────────────────────────
  print('\n--- Mixing .then() and await ---');

  // You can mix styles — await the whole chain at the end
  var score = await getBaseScore()
      .then((s) => applyBonus(s))
      .then((s) => clamp(s, 0, 100));

  print('final score: $score');

  // ── 6. Side-effects with .then() ──────────────────────────────
  print('\n--- Side effects in chain ---');

  // Use .then() returning the SAME value to add logging without altering flow
  final value = await Future.value(123)
      .then((n) {
        print('  [side-effect] got $n');
        return n; // pass through unchanged
      })
      .then((n) => n * 2);

  print('after side-effect: $value'); // 246

  // ── 7. Branching: conditional chains ─────────────────────────
  print('\n--- Conditional branching ---');

  for (final userId in ['admin', 'guest', 'unknown']) {
    final access = await resolveUser(userId)
        .then((user) => user.isAdmin ? fetchAdminData() : fetchPublicData())
        .then((data) => '[$userId] $data');
    print(access);
  }

  // ── 8. .then() vs async/await mental model ───────────────────
  print('\n--- Mental model ---');
  //
  // These two are identical:
  //
  //   future.then((v) => transform(v))
  //
  //   (() async {
  //     final v = await future;
  //     return transform(v);
  //   })()
  //
  // Prefer async/await for readability when chains get long.
  // .then() shines for short, readable one-liners.

  // One-liner with .then()
  final upper = await Future.value('dart').then((s) => s.toUpperCase());

  // Verbose with async/await — overkill here
  final upperAlt = await () async {
    final s = await Future.value('dart');
    return s.toUpperCase();
  }();

  print('both equal: ${upper == upperAlt}'); // true

  // ── 9. Chaining in a loop (sequential pipeline) ───────────────
  print('\n--- Sequential pipeline over a list ---');

  // Process items one by one — result of each feeds the next
  List<String> pipeline = ['raw text', '  extra spaces  ', 'mixed CASE'];
  List<String> cleaned = [];

  for (final item in pipeline) {
    final clean = await Future.value(item)
        .then((s) => s.trim())
        .then((s) => s.toLowerCase())
        .then((s) => s.replaceAll(' ', '_'));
    cleaned.add(clean);
  }
  print('cleaned: $cleaned');

  // ── 10. whenComplete is NOT a transformer ─────────────────────
  print('\n--- whenComplete vs then ---');

  // .whenComplete runs a callback but does NOT change the value
  final same = await Future.value('original')
      .whenComplete(() => print('  [cleanup]'))  // runs, value unchanged
      .then((s) => s.toUpperCase());

  print('after whenComplete: $same'); // ORIGINAL
}

// ── Models & Helpers ─────────────────────────────────────────────

class User {
  final int id;
  final String name;
  final bool isAdmin;
  User(this.id, this.name, {this.isAdmin = false});
}

class Profile {
  final String summary;
  Profile(this.summary);
}

Future<int> fetchId() async {
  await Future.delayed(Duration(milliseconds: 10));
  return 7;
}

Future<User> fetchUser(int id) async {
  await Future.delayed(Duration(milliseconds: 10));
  return User(id, 'User#$id');
}

Future<Profile> fetchProfile(User user) async {
  await Future.delayed(Duration(milliseconds: 10));
  return Profile('Profile of ${user.name} (id=${user.id})');
}

Future<int> getBaseScore() async {
  await Future.delayed(Duration(milliseconds: 10));
  return 85;
}

Future<int> applyBonus(int score) async {
  await Future.delayed(Duration(milliseconds: 5));
  return score + 20;
}

int clamp(int value, int min, int max) =>
    value < min ? min : (value > max ? max : value);

Future<User> resolveUser(String id) async {
  await Future.delayed(Duration(milliseconds: 5));
  return switch (id) {
    'admin' => User(1, 'Admin', isAdmin: true),
    'guest' => User(2, 'Guest'),
    _ => User(0, 'Unknown'),
  };
}

Future<String> fetchAdminData() async {
  await Future.delayed(Duration(milliseconds: 5));
  return 'secret admin data';
}

Future<String> fetchPublicData() async {
  await Future.delayed(Duration(milliseconds: 5));
  return 'public data';
}
