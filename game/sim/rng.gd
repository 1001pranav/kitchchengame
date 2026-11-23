class_name SimRng
extends RefCounted
## Deterministic xorshift32 RNG whose state can be saved (doc 08 §5).
## Bit-for-bit the same stream as the original Dart SimRng.

var _s: int

func _init(seed: int = 1, from_state := false) -> void:
	if from_state:
		_s = 0x9E3779B9 if seed == 0 else seed
	else:
		_s = mix(seed)

static func from_state(state: int) -> SimRng:
	return SimRng.new(state, true)

var state: int:
	get:
		return _s

## murmur3 fmix32, so small seeds do not start near zero.
static func mix(seed: int) -> int:
	var h := seed & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x85EBCA6B) & 0xFFFFFFFF
	h ^= h >> 13
	h = (h * 0xC2B2AE35) & 0xFFFFFFFF
	h ^= h >> 16
	return 0x9E3779B9 if h == 0 else h

func next_u32() -> int:
	var x := _s
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= (x >> 17)
	x ^= (x << 5) & 0xFFFFFFFF
	_s = x & 0xFFFFFFFF
	return _s

## Uniform in [0, 1).
func next_float() -> float:
	return (next_u32() >> 8) / 16777216.0

## Inclusive bounds.
func next_int(a: int, b: int) -> int:
	return a + floori(next_float() * (b - a + 1))

func range_f(a: float, b: float) -> float:
	return a + (b - a) * next_float()

func chance(p: float) -> bool:
	return next_float() < p

func pick(list: Array) -> Variant:
	return list[next_int(0, list.size() - 1)]

## One draw.
func weighted(items: Array, weights: Array) -> Variant:
	var total := 0.0
	for w in weights:
		total += w
	var r := next_float() * total
	for i in items.size():
		r -= weights[i]
		if r < 0:
			return items[i]
	return items[items.size() - 1]

## Fisher–Yates; consumes length−1 draws.
func shuffle(list: Array) -> void:
	var i := list.size() - 1
	while i > 0:
		var j := next_int(0, i)
		var t = list[i]
		list[i] = list[j]
		list[j] = t
		i -= 1

## Triangular distribution on [lo, hi] with mode c.
func triangular(lo: float, hi: float, c: float) -> float:
	var u := next_float()
	var f := (c - lo) / (hi - lo)
	if u < f:
		return lo + _sqrt(u * (hi - lo) * (c - lo))
	return hi - _sqrt((1 - u) * (hi - lo) * (hi - c))

static func _sqrt(x: float) -> float:
	if x <= 0:
		return 0.0
	var g := x
	for i in 30:
		g = 0.5 * (g + x / g)
	return g
