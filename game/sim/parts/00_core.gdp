class_name Sim
extends RefCounted
## The simulation (port of sim_core's Sim). GENERATED from sim/parts/*.gd by
## tools/build_sim.py — edit the parts, not this file.
## Names follow the original Dart so the two can be compared line by line.

const M = preload("res://sim/model.gd")

const SimError := {
	"notEnoughCash": "notEnoughCash", "wrongPhase": "wrongPhase", "unknownId": "unknownId",
	"belowMinimumOrder": "belowMinimumOrder", "limitReached": "limitReached", "locked": "locked",
	"invalidValue": "invalidValue", "refused": "refused",
}

class CommandResult:
	var ok: bool
	var error = null
	var message = null
	var events: Array = []
	var value = null
	func _init(o: bool, e = null, m = null, ev: Array = [], v = null) -> void:
		ok = o; error = e; message = m; events = ev; value = v
	static func fail(e: String, m = null) -> CommandResult:
		return CommandResult.new(false, e, m)
	static func good(v = null, m = null) -> CommandResult:
		return CommandResult.new(true, null, m, [], v)

## One line of a "Why?" breakdown.
class Factor:
	var label: String; var value: float; var display: String
	func _init(l: String, v: float, d: String) -> void:
		label = l; value = v; display = d

class Explanation:
	var title: String; var valueText: String; var kind: String
	var factors: Array; var howToImprove = null
	func _init(t: String, vt: String, k: String, f: Array, how = null) -> void:
		title = t; valueText = vt; kind = k; factors = f; howToImprove = how

class Forecast:
	var groups: int; var label: String; var factors: Dictionary
	func _init(g: int, l: String, f: Dictionary) -> void:
		groups = g; label = l; factors = f

var content: Content
var state: M.GameState
var _rng: SimRng
var _events: Array = []

var b: Content.Balance:
	get: return content.balance
var rng: SimRng:
	get: return _rng

func _init(c: Content, s: M.GameState, r: SimRng) -> void:
	content = c; state = s; _rng = r

static func new_game(c: Content, seed: int, difficulty: String, theme_id := "italian") -> Sim:
	var r := SimRng.new(seed)
	var st := M.GameState.new()
	st.seed = seed; st.rngState = r.state; st.difficulty = difficulty; st.themeId = theme_id
	st.cash = c.balance.i("START_CAPITAL")
	var sim := Sim.new(c, st, r)
	sim._generateOffers()
	sim._syncRng()
	return sim

static func from_save(c: Content, save: Dictionary) -> Sim:
	var migrated := migrateSave(save)
	var st: M.GameState = M.GameState.new().from_json(migrated.state)
	return Sim.new(c, st, SimRng.from_state(st.rngState))

const currentSaveVersion := 1

static func migrateSave(save: Dictionary) -> Dictionary:
	var v := int(save.get("saveVersion", 1))
	assert(v <= currentSaveVersion, "This save was made by a newer version of the game.")
	return save

func toSave() -> Dictionary:
	_syncRng()
	return {"saveVersion": currentSaveVersion, "state": state.to_json()}

func _syncRng() -> void:
	state.rngState = _rng.state

# ------------------------------------------------------------ helpers

var _ctx: M.Location = null
var loc: M.Location:
	get: return _ctx if _ctx != null else state.viewLoc

## Runs [f] with [l] as the current location.
func at(l: M.Location, f: Callable) -> Variant:
	var prev := _ctx
	_ctx = l
	var r = f.call()
	_ctx = prev
	return r

## Location-scoped flags (pests, leak, bookings …).
func lf(k: String) -> bool:
	return state.flag("%d:%s" % [loc.id, k])

var themeOfLoc: Content.CuisineTheme:
	get: return content.themes.get(loc.themeId, theme)
var theme: Content.CuisineTheme:
	get: return content.themes[state.themeId]
func diff(key: String) -> float:
	return b.by_difficulty(key, state.difficulty)
func emit(type: String, args := {}) -> void:
	_events.append({"type": type, "args": args})
func _drain() -> Array:
	_syncRng()
	var out := _events.duplicate()
	_events.clear()
	return out

func _note(kind: String, text: String, value := 0) -> void:
	loc.today.add(kind, text, value)
func _timeline(text: String) -> void:
	state.timeline.append(M.TimelineEntry.mk(state.dayIndex, text))
	if state.timeline.size() > 60:
		state.timeline.remove_at(0)

## Every coin movement goes through here so the day's P&L stays complete.
func spend(amount: int, bucket: String) -> void:
	state.cash -= amount
	var t := loc.today
	match bucket:
		"ingredients": t.ingredientSpend += amount
		"wages": t.wages += amount
		"rent": t.rent += amount
		"utilities": t.utilities += amount
		"upkeep": t.upkeep += amount
		"marketing": t.marketing += amount
		"interest": t.interest += amount
		"financing": pass
		_: t.other += amount
	emit("cashChanged", {"delta": -amount})

func earn(amount: int, bucket: String) -> void:
	state.cash += amount
	if bucket == "revenue":
		loc.today.revenue += amount
	elif bucket == "other":
		loc.today.other -= amount
	emit("cashChanged", {"delta": amount})

func money(v) -> String:
	var n := roundi(v)
	var s := str(absi(n))
	var buf := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			buf += ","
		buf += s[i]
	return ("−" if n < 0 else "") + buf

func dateLabel(day = null) -> String:
	var d: int = state.dayIndex if day == null else day
	return "Day %d · %s" % [d + 1, M.weekdays[posmod(d, 7)]]

# ------------------------------------------------------------ public API

func apply(c: Dictionary) -> CommandResult:
	var r: CommandResult = _handle(c)
	var ev := _drain()
	return CommandResult.new(r.ok, r.error, r.message, ev, r.value)

## Advance one service tick. Only valid during service.
func tick() -> Array:
	if state.phase != "service":
		return []
	_serviceTickAll()
	return _drain()

func beginDay() -> Array:
	_beginDay()
	return _drain()

func forecast() -> Forecast:
	return _forecast()
func formatInfo(l: M.Location) -> Dictionary:
	return _format(l)
func explain(target: String, id = null) -> Explanation:
	return _explain(target, id)

# ------------------------------------------------------------ Dart helpers

## Dart's num.clamp keeps the type of the receiver for in-range values.
static func clampd(v: float, lo: float, hi: float) -> float:
	return clampf(v, lo, hi)

## Sort like Dart's List.sort with a compare function.
static func dsort(a: Array, cmp: Callable) -> void:
	DSort.sort(a, cmp)

static func cmpn(x, y) -> int:
	return -1 if x < y else (1 if x > y else 0)

## Dart String.compareTo (code-unit order).
static func cmps(x: String, y: String) -> int:
	return -1 if x < y else (1 if x > y else 0)

static func first_or_null(a: Array, f: Callable) -> Variant:
	for e in a:
		if f.call(e):
			return e
	return null

static func any(a: Array, f: Callable) -> bool:
	for e in a:
		if f.call(e):
			return true
	return false

static func count(a: Array, f: Callable) -> int:
	var n := 0
	for e in a:
		if f.call(e):
			n += 1
	return n

static func remove_where(a: Array, f: Callable) -> void:
	var i := 0
	while i < a.size():
		if f.call(a[i]):
			a.remove_at(i)
		else:
			i += 1

static func every(a: Array, f: Callable) -> bool:
	for e in a:
		if not f.call(e):
			return false
	return true
