extends Node
## Autoload "Game": owns the simulation, the clock and saving.

signal changed                     ## state changed (command applied or tick)
signal sim_events(events: Array)   ## events from the last command or tick
signal screen_requested(name: String)

const SAVE_PATH := "user://save.json"
const TICKS_PER_SEC := [0.0, 2.0, 5.0, 12.0] ## paused, play, fast, very fast

var content: Content
var sim: Sim
var speed := 1
var _acc := 0.0
var paused_by_card := false

func _ready() -> void:
	content = Content.load_dir()

func new_game(seed: int, difficulty := "normal", theme_id := "italian") -> void:
	sim = Sim.new_game(content, seed, difficulty, theme_id)
	changed.emit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save() -> void:
	if sim == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(sim.toSave(), "", false, true))

func load_save() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data == null:
		return false
	sim = Sim.from_save(content, data)
	changed.emit()
	return true

func apply(cmd: Dictionary) -> Sim.CommandResult:
	var r := sim.apply(cmd)
	if not r.events.is_empty():
		sim_events.emit(r.events)
	changed.emit()
	if r.ok and (cmd.type == "EndDay" or cmd.type == "BuyRestaurant"):
		save()
	return r

func set_speed(s: int) -> void:
	speed = clampi(s, 0, 3)
	_acc = 0.0

## Fraction of the way to the next tick, for smooth movement between ticks.
var tick_frac: float:
	get: return clampf(_acc, 0.0, 1.0)

func _process(delta: float) -> void:
	if sim == null or sim.state.phase != "service":
		return
	if paused_by_card or speed == 0:
		return
	_acc += delta * TICKS_PER_SEC[speed]
	var guard := 0
	while _acc >= 1.0 and sim.state.phase == "service" and guard < 8:
		_acc -= 1.0
		guard += 1
		var ev := sim.tick()
		if not ev.is_empty():
			sim_events.emit(ev)
		changed.emit()
		if _service_card_open():
			paused_by_card = true
			break

func _service_card_open() -> bool:
	for i in sim.state.openIncidents:
		if i.countdown > 0 and i.locationId == sim.loc.id:
			return true
	return false
