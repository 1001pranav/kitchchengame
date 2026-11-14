/// xorshift32 exactly as doc 08 §5, so this prototype's seeds stay meaningful later.
class SimRng {
  int _s;
  SimRng(int seed) : _s = _mix(seed);

  /// Seeds are scrambled first (murmur3 fmix32, doc 08 §5). Raw small seeds made the
  /// first xorshift32 output nearly 0 (seeds 1–200: mean 0.006), so the first thing
  /// rolled in every run — the head chef's skill — was always the minimum.
  static int _mix(int seed) {
    var h = seed & 0xFFFFFFFF;
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h == 0 ? 0x9E3779B9 : h;
  }

  int get state => _s;

  int nextU32() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    return _s = x & 0xFFFFFFFF;
  }

  double nextFloat() => (nextU32() >> 8) / 16777216.0;
  int nextInt(int a, int b) => a + (nextFloat() * (b - a + 1)).floor();
  bool chance(double p) => nextFloat() < p;
  double uniform(double a, double b) => a + (b - a) * nextFloat();

  T weighted<T>(List<T> items, List<num> weights) {
    final total = weights.fold<num>(0, (a, b) => a + b);
    var r = nextFloat() * total;
    for (var i = 0; i < items.length; i++) {
      r -= weights[i];
      if (r < 0) return items[i];
    }
    return items.last;
  }
}
