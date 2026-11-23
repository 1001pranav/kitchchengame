class_name Content
extends RefCounted
## All static content (port of content.dart). JSON numbers arrive as floats,
## so ints are converted where the Dart code reads them as ints.

class Balance:
	var raw: Dictionary
	func _init(r: Dictionary) -> void:
		raw = r
	func _get_k(k: String) -> Variant:
		assert(raw.has(k), "balance.json: missing key " + k)
		return raw[k]
	func d(k: String) -> float:
		return float(_get_k(k))
	func i(k: String) -> int:
		return int(_get_k(k))
	func list(k: String) -> Array:
		var out: Array = []
		for e in _get_k(k):
			out.append(float(e))
		return out
	func dmap(k: String) -> Dictionary:
		var out := {}
		var m: Dictionary = _get_k(k)
		for key in m:
			out[key] = float(m[key])
		return out
	func map(k: String) -> Dictionary:
		return _get_k(k)
	func by_difficulty(k: String, difficulty: String) -> float:
		return float(_get_k(k)[difficulty])

class Ingredient:
	var id: String; var name: String; var category: String; var storage: String
	var shelfLifeDays: int; var baseCost: float
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; category = j.category; storage = j.storage
		shelfLifeDays = int(j.shelfLifeDays); baseCost = float(j.baseCost)

class RecipeLine:
	var ingredientId: String; var qty: int
	func _init(a: String, q: int) -> void:
		ingredientId = a; qty = q

class Dish:
	var id: String; var name: String; var theme: String; var course: String; var station: String
	var prepTicks: int; var skillReq: int; var popularity: float
	var recipe: Array = []
	var basePrice := 0
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; theme = j.theme; course = j.course; station = j.station
		prepTicks = int(j.prepTicks); skillReq = int(j.skillReq)
		popularity = 1.0 if j.get("popularity") == null else float(j.popularity)
		for r in j.recipe:
			recipe.append(RecipeLine.new(r.ingredientId, int(r.qty)))
	var courseGroup: String:
		get:
			return "sweet" if (course == "dessert" or course == "drink") else course

class EquipmentType:
	var type: String; var name: String; var kind: String
	var station = null; var storage = null
	var slots: int; var capacity: int; var price: int; var wearPerDay: float
	func _init(j: Dictionary) -> void:
		type = j.type; name = j.name; kind = j.kind
		station = j.get("station"); storage = j.get("storage")
		slots = 0 if j.get("slots") == null else int(j.slots)
		capacity = 0 if j.get("capacity") == null else int(j.capacity)
		price = int(j.price); wearPerDay = float(j.wearPerDay)

class Supplier:
	var id: String; var name: String; var categories: Array
	var priceMult: float; var reliability: float
	var quality: int; var minOrder: int; var leadDays: int; var creditDays: int
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; categories = j.categories
		priceMult = float(j.priceMult); reliability = float(j.reliability)
		quality = int(j.quality); minOrder = int(j.minOrder); leadDays = int(j.leadDays); creditDays = int(j.creditDays)

class Trait:
	var id: String; var name: String; var description: String
	var roles = null
	var modifiers := {}
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; description = j.description; roles = j.get("roles")
		for k in j.modifiers:
			modifiers[k] = float(j.modifiers[k])

class Festival:
	var id: String; var name: String
	var month: int; var day: int; var durationDays: int; var demandMult: float
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; month = int(j.month); day = int(j.day)
		durationDays = int(j.durationDays); demandMult = float(j.demandMult)

class CuisineTheme:
	var id: String; var name: String; var accent: String; var mainStation: String
	var stations: Array
	## stationSet → Array of [type, count]
	var startingEquipment := {}
	var restaurantNames: Array; var firstNames: Array; var lastNames: Array
	var festivals: Array = []
	var startingMenu = null
	var isMixed: bool:
		get:
			return id == "mixed"
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; accent = j.accent; mainStation = j.mainStation
		stations = j.stations
		for k in j.startingEquipment:
			var l: Array = []
			for e in j.startingEquipment[k]:
				l.append([e.type, int(e.count)])
			startingEquipment[k] = l
		restaurantNames = j.namePools.restaurant
		firstNames = j.namePools.staffFirst
		lastNames = j.namePools.staffLast
		for f in j.festivals:
			festivals.append(Festival.new(f))
		startingMenu = j.get("startingMenu")

class LocationClass:
	var id: String; var name: String; var baseFootfall: int; var weeklyRent: int
	var segmentMix := {}
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; baseFootfall = int(j.baseFootfall); weeklyRent = int(j.weeklyRent)
		for k in j.segmentMix:
			segmentMix[k] = float(j.segmentMix[k])

static func _ints(a: Array) -> Array:
	var out: Array = []
	for e in a:
		out.append(int(e))
	return out

class Tier:
	var id: String; var name: String; var locationClass: String; var stationSet: String
	var price: int; var loan: int; var morale: int; var tables: int
	var staffRoles: Array; var skillRange: Array; var equipmentCondition: Array
	var equipmentAgeYears: Array; var hiddenProblems: Array
	var reputation: float; var wageMult: float; var stockDays: float
	var rentOverride = null
	var hasAc: bool; var hasGenerator: bool; var extraFridge: bool; var oneBroken: bool; var badApple: bool
	func _init(j: Dictionary) -> void:
		id = j.id; name = j.name; locationClass = j.locationClass; stationSet = j.stationSet
		price = int(j.price); loan = int(j.loan); morale = int(j.morale); tables = int(j.tables)
		staffRoles = j.staffRoles
		skillRange = Content._ints(j.skillRange)
		equipmentCondition = Content._ints(j.equipmentCondition)
		equipmentAgeYears = Content._ints(j.equipmentAgeYears)
		hiddenProblems = Content._ints(j.hiddenProblems)
		reputation = float(j.reputation); wageMult = float(j.wageMult); stockDays = float(j.stockDays)
		rentOverride = null if j.get("rentOverride") == null else int(j.rentOverride)
		hasAc = j.hasAc; hasGenerator = j.hasGenerator; extraFridge = j.extraFridge
		oneBroken = j.get("oneBroken", false); badApple = j.get("badApple", false)

class IncidentOption:
	var id: String; var label: String
	var requires = null
	var effects: Array = []
	var hint = null
	func _init(j: Dictionary) -> void:
		id = j.id; label = j.label; hint = j.get("hint"); requires = j.get("requires")
		var e = j.get("effects")
		effects = [] if e == null else e

class IncidentDef:
	var id: String; var title: String; var text: String; var timing: String; var category: String
	var trigger: Dictionary; var weight: float; var cooldownDays: int; var forced: bool
	var tags: Array; var subject: String
	var subjectFilter = null
	var options: Array = []
	var defaultOption: String
	func _init(j: Dictionary) -> void:
		id = j.id; title = j.title; text = j.text; timing = j.timing
		category = j.get("category", "staff") if j.get("category") != null else "staff"
		var t = j.get("trigger")
		trigger = {} if t == null else t
		weight = 0.0 if j.get("weight") == null else float(j.weight)
		cooldownDays = 0 if j.get("cooldownDays") == null else int(j.cooldownDays)
		forced = j.get("forced", false) == true
		var tg = j.get("tags")
		tags = [] if tg == null else tg
		subject = "none" if j.get("subject") == null else j.subject
		subjectFilter = j.get("subjectFilter")
		for o in j.options:
			options.append(IncidentOption.new(o))
		defaultOption = j.defaultOption
	func option(oid: String) -> IncidentOption:
		for o in options:
			if o.id == oid:
				return o
		assert(false, "no option " + oid)
		return null

class Objective:
	var id: String; var text: String; var rewardText: String; var stage: int
	var reward: Array = []
	func _init(j: Dictionary) -> void:
		id = j.id; text = j.text; rewardText = j.rewardText; stage = int(j.stage)
		var r = j.get("reward")
		reward = [] if r == null else r

class Term:
	var id: String; var name: String; var meaning: String; var why: String
	func _init(a: String, b: String, c: String, d: String) -> void:
		id = a; name = b; meaning = c; why = d

var balance: Balance
var ingredients := {}
var dishes := {}
var equipment := {}
var suppliers := {}
var traits := {}
var themes := {}
var locationClasses := {}
var tiers: Array = []
var incidents := {}
var objectives: Array = []
var terms := {}

func tier(id: String) -> Tier:
	for t in tiers:
		if t.id == id:
			return t
	assert(false, "no tier " + id)
	return null

## Mixed draws from every pack (doc 01 §4.2).
func dishes_for(theme_id: String) -> Array:
	var out: Array = []
	for d in dishes.values():
		if theme_id == "mixed" or d.theme == theme_id:
			out.append(d)
	return out

const FILES := ["balance.json", "ingredients.json", "dishes.json", "equipment.json", "suppliers.json",
	"traits.json", "themes.json", "locations.json", "tiers.json", "incidents.json", "objectives.json", "terms_en.json"]

static func load_dir(dir := "res://data/") -> Content:
	var files := {}
	for f in FILES:
		files[f] = FileAccess.get_file_as_string(dir + f)
	return load_files(files)

static func load_files(files: Dictionary) -> Content:
	var c := Content.new()
	var read := func(f: String) -> Variant:
		assert(files.has(f) and files[f] != "", f + " missing")
		return JSON.parse_string(files[f])
	c.balance = Balance.new(read.call("balance.json"))
	for j in read.call("ingredients.json"):
		c.ingredients[j.id] = Ingredient.new(j)
	for j in read.call("dishes.json"):
		c.dishes[j.id] = Dish.new(j)
	var targets := c.balance.dmap("FOOD_COST_TARGET")
	for d in c.dishes.values():
		var cost := 0.0
		for r in d.recipe:
			assert(c.ingredients.has(r.ingredientId), "unknown ingredient " + r.ingredientId)
			cost += r.qty * c.ingredients[r.ingredientId].baseCost
		assert(targets.has(d.course), "unknown course " + d.course)
		d.basePrice = roundi(cost / targets[d.course])
	var terms_raw: Dictionary = read.call("terms_en.json")
	for k in terms_raw:
		var m: Dictionary = terms_raw[k]
		c.terms[k] = Term.new(k, m.name, m.meaning, m.why)
	for j in read.call("equipment.json"):
		c.equipment[j.type] = EquipmentType.new(j)
	for j in read.call("suppliers.json"):
		c.suppliers[j.id] = Supplier.new(j)
	for j in read.call("traits.json"):
		c.traits[j.id] = Trait.new(j)
	for j in read.call("themes.json"):
		c.themes[j.id] = CuisineTheme.new(j)
	for j in read.call("locations.json"):
		c.locationClasses[j.id] = LocationClass.new(j)
	for j in read.call("tiers.json"):
		c.tiers.append(Tier.new(j))
	for j in read.call("incidents.json"):
		c.incidents[j.id] = IncidentDef.new(j)
	for j in read.call("objectives.json"):
		c.objectives.append(Objective.new(j))
	return c
