class_name DSort
extends RefCounted
## Dart's List.sort (insertion sort up to 32, dual-pivot quicksort above),
## ported line for line so ties land in the same order as the original sim.
## [cmp] returns a negative, zero or positive int.

static func sort(a: Array, cmp: Callable) -> void:
	_do(a, 0, a.size() - 1, cmp)

## Sort with the natural order (numbers, strings).
static func sort_natural(a: Array) -> void:
	_do(a, 0, a.size() - 1, func(x, y): return -1 if x < y else (1 if x > y else 0))

## Compare helper: sign of a - b for numbers, like Dart's num.compareTo.
static func c(x, y) -> int:
	return -1 if x < y else (1 if x > y else 0)

static func _do(a: Array, left: int, right: int, cmp: Callable) -> void:
	if right - left <= 32:
		_ins(a, left, right, cmp)
	else:
		_dpq(a, left, right, cmp)

static func _ins(a: Array, left: int, right: int, cmp: Callable) -> void:
	for i in range(left + 1, right + 1):
		var el = a[i]
		var j := i
		while j > left and cmp.call(a[j - 1], el) > 0:
			a[j] = a[j - 1]
			j -= 1
		a[j] = el

static func _dpq(a: Array, left: int, right: int, cmp: Callable) -> void:
	var sixth := (right - left + 1) / 6
	var index1 := left + sixth
	var index5 := right - sixth
	var index3 := (left + right) / 2
	var index2 := index3 - sixth
	var index4 := index3 + sixth
	var el1 = a[index1]
	var el2 = a[index2]
	var el3 = a[index3]
	var el4 = a[index4]
	var el5 = a[index5]
	var t
	if cmp.call(el1, el2) > 0: t = el1; el1 = el2; el2 = t
	if cmp.call(el4, el5) > 0: t = el4; el4 = el5; el5 = t
	if cmp.call(el1, el3) > 0: t = el1; el1 = el3; el3 = t
	if cmp.call(el2, el3) > 0: t = el2; el2 = el3; el3 = t
	if cmp.call(el1, el4) > 0: t = el1; el1 = el4; el4 = t
	if cmp.call(el3, el4) > 0: t = el3; el3 = el4; el4 = t
	if cmp.call(el2, el5) > 0: t = el2; el2 = el5; el5 = t
	if cmp.call(el2, el3) > 0: t = el2; el2 = el3; el3 = t
	if cmp.call(el4, el5) > 0: t = el4; el4 = el5; el5 = t
	var pivot1 = el2
	var pivot2 = el4
	a[index1] = el1
	a[index3] = el3
	a[index5] = el5
	a[index2] = a[left]
	a[index4] = a[right]
	var less := left + 1
	var great := right - 1
	var pivots_are_equal: bool = cmp.call(pivot1, pivot2) == 0
	if pivots_are_equal:
		var pivot = pivot1
		var k := less
		while k <= great:
			var ak = a[k]
			var comp: int = cmp.call(ak, pivot)
			if comp == 0:
				k += 1
				continue
			if comp < 0:
				if k != less:
					a[k] = a[less]
					a[less] = ak
				less += 1
			else:
				while true:
					comp = cmp.call(a[great], pivot)
					if comp > 0:
						great -= 1
						continue
					elif comp < 0:
						a[k] = a[less]
						a[less] = a[great]
						less += 1
						a[great] = ak
						great -= 1
						break
					else:
						a[k] = a[great]
						a[great] = ak
						great -= 1
						break
			k += 1
	else:
		var k := less
		while k <= great:
			var ak = a[k]
			var cp1: int = cmp.call(ak, pivot1)
			if cp1 < 0:
				if k != less:
					a[k] = a[less]
					a[less] = ak
				less += 1
			else:
				var cp2: int = cmp.call(ak, pivot2)
				if cp2 > 0:
					while true:
						var comp: int = cmp.call(a[great], pivot2)
						if comp > 0:
							great -= 1
							if great < k:
								break
							continue
						else:
							comp = cmp.call(a[great], pivot1)
							if comp < 0:
								a[k] = a[less]
								a[less] = a[great]
								less += 1
								a[great] = ak
								great -= 1
							else:
								a[k] = a[great]
								a[great] = ak
								great -= 1
							break
			k += 1
	a[left] = a[less - 1]
	a[less - 1] = pivot1
	a[right] = a[great + 1]
	a[great + 1] = pivot2
	_do(a, left, less - 2, cmp)
	_do(a, great + 2, right, cmp)
	if pivots_are_equal:
		return
	if less < index1 and great > index5:
		while cmp.call(a[less], pivot1) == 0:
			less += 1
		while cmp.call(a[great], pivot2) == 0:
			great -= 1
		var k := less
		while k <= great:
			var ak = a[k]
			var cp1: int = cmp.call(ak, pivot1)
			if cp1 == 0:
				if k != less:
					a[k] = a[less]
					a[less] = ak
				less += 1
			else:
				var cp2: int = cmp.call(ak, pivot2)
				if cp2 == 0:
					while true:
						var comp: int = cmp.call(a[great], pivot2)
						if comp == 0:
							great -= 1
							if great < k:
								break
							continue
						else:
							comp = cmp.call(a[great], pivot1)
							if comp < 0:
								a[k] = a[less]
								a[less] = a[great]
								less += 1
								a[great] = ak
								great -= 1
							else:
								a[k] = a[great]
								a[great] = ak
								great -= 1
							break
			k += 1
		_do(a, less, great, cmp)
	else:
		_do(a, less, great, cmp)
