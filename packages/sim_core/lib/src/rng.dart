/// Deterministic xorshift32 RNG whose state can be saved (doc 08 §5).
class SimRng {
  int _s;

  SimRng(int seed) : _s = mix(seed);
  SimRng.fromState(int state) : _s = state == 0 ? 0x9E3779B9 : state;

  int get state => _s;

  /// murmur3 fmix32, so small seeds do not start near zero.
  static int mix(int seed) {
    var h = seed & 0xFFFFFFFF;
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h == 0 ? 0x9E3779B9 : h;
  }

  int nextU32() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    return _s = x & 0xFFFFFFFF;
  }

  /// Uniform in [0, 1).
  double nextFloat() => (nextU32() >> 8) / 16777216.0;

  /// Inclusive bounds.
  int nextInt(int a, int b) => a + (nextFloat() * (b - a + 1)).floor();

  double range(double a, double b) => a + (b - a) * nextFloat();

  bool chance(double p) => nextFloat() < p;

  T pick<T>(List<T> list) => list[nextInt(0, list.length - 1)];

  /// One draw.
  T weighted<T>(List<T> items, List<double> weights) {
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var r = nextFloat() * total;
    for (var i = 0; i < items.length; i++) {
      r -= weights[i];
      if (r < 0) return items[i];
    }
    return items.last;
  }

  /// Fisher–Yates; consumes length−1 draws.
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(0, i);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  /// Triangular distribution on [lo, hi] with mode c.
  double triangular(double lo, double hi, double c) {
    final u = nextFloat();
    final f = (c - lo) / (hi - lo);
    if (u < f) return lo + _sqrt(u * (hi - lo) * (c - lo));
    return hi - _sqrt((1 - u) * (hi - lo) * (hi - c));
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    var g = x;
    for (var i = 0; i < 30; i++) {
      g = 0.5 * (g + x / g);
    }
    return g;
  }
}
