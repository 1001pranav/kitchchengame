extends Node
## The whole game on one stage: the 3D restaurant is always there, and each
## screen is a panel over it.

const M = preload("res://sim/model.gd")

var room: Restaurant3D
var ui: Control
var screen: Control
var overlay: Control
var toasts: VBoxContainer
var current := ""
var tab := ""
var _card_open := false
var _intro_seen := false
var _hud := {}
var _popup: Control
var _drag_from := Vector2.ZERO
var _dragging := false

@onready var game = get_node("/root/Game")

func _ready() -> void:
	room = Restaurant3D.new()
	add_child(room)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UI.theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	toasts = UI.vbox(6)
	toasts.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toasts.offset_top = 132
	toasts.offset_left = 16
	toasts.offset_right = -16
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toasts)
	game.changed.connect(_on_changed)
	game.sim_events.connect(_on_events)
	if OS.get_cmdline_user_args().has("--autoplay"):
		_autoplay()
		return
	_backdrop()
	show_title()

## A restaurant to look at behind the title: a throwaway game nobody plays.
func _backdrop() -> void:
	var demo := Sim.new_game(game.content, 77, "normal")
	demo.apply({"type": "BuyRestaurant", "offerIndex": 1})
	room.build(demo)

func _clear() -> void:
	for c in screen.get_children():
		c.queue_free()
	_hud.clear()
	_close_popup()

func _sheet(content: Control, height_frac := 0.56, pad := 20) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UI.flat(Color(UI.BG, 0.97), 22, UI.LINE)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = 18
	sb.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.anchor_top = 1.0 - height_frac
	p.offset_top = 0
	p.add_child(content)
	screen.add_child(p)
	# Slide up.
	p.position.y += 60
	p.modulate.a = 0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "position:y", p.position.y - 60, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	return p

func _shade(alpha := 0.55) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(r)
	return r

# ================================================================ routing

func _on_changed() -> void:
	if game.sim == null or current == "title" or current == "intro":
		return
	_route()
	if current == "service":
		_update_hud()

func _route() -> void:
	var st: M.GameState = game.sim.state
	var snd = get_node_or_null("/root/Sound")
	if snd != null:
		snd.music("service" if st.phase == "service" else "title")
		snd.ambience(st.phase == "service")
	var want := st.phase
	if want == "market" and not _intro_seen:
		return
	if tab != "" and (want == "prep" or want == "close"):
		want = "tab"
	if want != current:
		match want:
			"market": show_market()
			"prep": show_prep()
			"service": show_service()
			"close": show_close()
			"gameOver": show_game_over()
			"tab": show_tab(tab)
	_maybe_card()

# ================================================================ title and intro

func show_title() -> void:
	_clear()
	current = "title"
	var snd = get_node_or_null("/root/Sound")
	if snd != null:
		snd.music("title")
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.1))
	gr.set_color(1, Color(0, 0, 0, 0.92))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0.25)
	gt.fill_to = Vector2(0, 0.8)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(grad)
	var v := UI.vbox(12)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_END
	var m := UI.margin(v, 28, 0, 28, 56)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(m)
	v.add_child(UI.kicker("A restaurant management game", UI.BRASS))
	var t := UI.label("Kitchen\nChain", 58, UI.INK, UI.serif(800))
	t.add_theme_constant_override("line_spacing", -14)
	v.add_child(t)
	v.add_child(UI.label("One small place. Then a city of them.", 16, UI.MUTED))
	v.add_child(UI.spacer(18))
	if game.has_save():
		v.add_child(UI.cta("CONTINUE", func():
			if game.load_save():
				_intro_seen = true
				current = ""
				room.build(game.sim)
				_route()))
		v.add_child(UI.button("New game", _new_game))
	else:
		v.add_child(UI.cta("NEW GAME", _new_game))

func _new_game() -> void:
	game.new_game(int(Time.get_unix_time_from_system()) % 100000, "normal")
	show_intro()

func show_intro() -> void:
	_clear()
	current = "intro"
	_shade(0.78)
	var v := UI.vbox(14)
	var m := UI.margin(v, 28, 90, 28, 40)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(m)
	v.add_child(UI.kicker("A letter, left on the counter", UI.BRASS))
	v.add_child(UI.title("You have %s and one chance." % UI.money(game.content.balance.i("START_CAPITAL")), 28))
	var body := "Your aunt ran a kitchen for thirty years. She left you her savings and a note: \"Buy a place. Feed people well. Do not trust anyone who never eats their own food.\"\n\nFive restaurants are for sale. Cheap ones hide problems. Good ones cost more than you have, but the bank will lend.\n\nEvery night the doors open. What happens next is up to you."
	v.add_child(UI.label(body, 16, Color("d9cfbf"), UI.sans(400), true))
	var sp := UI.spacer()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	v.add_child(UI.cta("SEE WHAT'S FOR SALE", func():
		_intro_seen = true
		current = ""
		_route()))

# ================================================================ market

func show_market() -> void:
	_clear()
	current = "market"
	_shade(0.7)
	var st: M.GameState = game.sim.state
	var v := UI.vbox(12)
	var head := UI.vbox(4)
	head.add_child(UI.kicker("Restaurants for sale", UI.BRASS))
	head.add_child(UI.title("Choose your first place", 26))
	head.add_child(UI.label("Cash %s. The bank lends part of the price." % UI.money(st.cash), 14, UI.MUTED))
	v.add_child(head)
	var list := UI.vbox(12)
	for i in st.offers.size():
		list.add_child(_offer_card(i, st.offers[i]))
	v.add_child(UI.scroll(list))
	var m := UI.margin(v, 16, 64, 16, 20)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(m)

const TIER_WORDS := {"excellent": "Excellent", "best": "Very good", "good": "Good", "bad": "Tired", "worst": "Run-down"}

func _offer_card(i: int, o: M.Offer) -> Control:
	var st: M.GameState = game.sim.state
	var l := o.location
	var v := UI.vbox(8)
	var top := UI.hbox()
	var nm := UI.vbox(2)
	nm.add_child(UI.kicker(TIER_WORDS.get(o.tierId, o.tierId) + " · " + game.content.locationClasses[l.classId].name))
	nm.add_child(UI.label(l.name, 20, UI.INK, UI.serif(700)))
	top.add_child(UI.grow(nm))
	var pr := UI.vbox(0)
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	var pl := UI.label(UI.money(o.price), 20, UI.BRASS, UI.sans(800))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pr.add_child(pl)
	var ll := UI.label("bank lends %s" % UI.money(o.loan) if o.loan > 0 else "no loan", 11, UI.MUTED)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pr.add_child(ll)
	top.add_child(pr)
	v.add_child(top)
	var facts := UI.hbox(6)
	facts.add_child(UI.chip("%s rating" % UI.stars(l.reputation), UI.WARN))
	facts.add_child(UI.chip("%d tables" % l.tableSeats.size(), UI.MUTED))
	facts.add_child(UI.chip("%d staff" % l.staff.size(), UI.MUTED))
	v.add_child(facts)
	var known := l.hidden.filter(func(h): return h.revealed)
	if o.inspected:
		if known.is_empty():
			v.add_child(UI.label("Inspection found nothing wrong.", 13, UI.OK))
		for h in known:
			v.add_child(UI.label("• " + Sim.hiddenProblemText.get(h.kind, h.kind), 13, UI.BAD, null, true))
		if l.hidden.size() > known.size():
			v.add_child(UI.label("The inspector may have missed something.", 12, UI.MUTED))
	else:
		v.add_child(UI.label("Problems the seller did not mention: unknown.", 13, UI.MUTED))
	var row := UI.hbox(8)
	var need := o.price - o.loan
	if not o.inspected:
		row.add_child(UI.grow(UI.button("Inspect (%s)" % UI.money(game.content.balance.i("DUE_DILIGENCE_COST")), func():
			_result(game.apply({"type": "BuyDueDiligence", "offerIndex": i}))
			show_market())))
	var buy := UI.button("Buy · pay %s" % UI.money(need), func():
		var r = game.apply({"type": "BuyRestaurant", "offerIndex": i})
		if r.ok:
			room.build(game.sim)
		_result(r), true)
	buy.disabled = st.cash < need
	row.add_child(UI.grow(buy))
	v.add_child(row)
	return UI.panel(v, UI.SURFACE)

# ================================================================ prep

func show_prep() -> void:
	_clear()
	current = "prep"
	room.build(game.sim) if room.loc_id != game.sim.loc.id else null
	var sim: Sim = game.sim
	var st := sim.state
	var l := sim.loc
	_top_bar()
	var v := UI.vbox(12)
	var hd := UI.hbox()
	var nm := UI.vbox(2)
	nm.add_child(UI.kicker("%s · before opening" % sim.dateLabel(), UI.BRASS))
	nm.add_child(UI.label(l.name, 24, UI.INK, UI.serif(700)))
	hd.add_child(UI.grow(nm))
	v.add_child(hd)
	var fc := sim.forecast()
	var stats := UI.hbox(0)
	stats.add_child(_stat("EXPECTED", str(fc.groups), fc.label))
	stats.add_child(_stat("TARGET", "≤%d" % sim.targetPreview(), "walk-outs allowed"))
	stats.add_child(_stat("RATING", "%.1f" % l.reputation, "stars"))
	v.add_child(UI.panel(stats, UI.SURFACE, 12))
	if st.dayIndex == 0 and fc.groups > 0:
		var goal := _opening_goal(fc.groups)
		var g := UI.hbox()
		var gv := UI.vbox(2)
		gv.add_child(UI.kicker("Opening night · your goal", UI.BRASS))
		gv.add_child(UI.label("Serve %d parties" % goal, 20, UI.INK, UI.serif(700)))
		gv.add_child(UI.label("Tap jobs in the room to help your team.", 12, UI.MUTED))
		g.add_child(UI.grow(gv))
		v.add_child(UI.panel(g, Color("221b12"), 12, UI.BRASS.darkened(0.35)))
	var att := _attention()
	if not att.is_empty():
		var av := UI.vbox(6)
		for a in att.slice(0, 4):
			var row := UI.hbox(8)
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(6, 6)
			dot.color = a[1]
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			row.add_child(UI.grow(UI.label(a[0], 13, UI.INK, null, true)))
			av.add_child(row)
		v.add_child(av)
	# Where you start tonight.
	var zl := UI.hbox(6)
	for z in Restaurant3D.ZONES:
		var b := UI.button(Sim.areaNames[z].split(" ")[0], func():
			game.apply({"type": "OwnerStand", "area": z})
			show_prep())
		if st.owner.startArea == z:
			b.add_theme_stylebox_override("normal", UI.flat(Color("2a2416"), 10, UI.BRASS))
		zl.add_child(UI.grow(b))
	v.add_child(UI.kicker("You start at"))
	v.add_child(zl)
	var tabs := UI.hbox(6)
	for t in ["Staff", "Stock", "Menu", "Money"]:
		tabs.add_child(UI.grow(UI.button(t, func():
			tab = t
			current = ""
			_route())))
	v.add_child(tabs)
	var sp := UI.spacer()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var closed := l.closedUntil > st.dayIndex
	v.add_child(UI.cta("STAY CLOSED TODAY" if closed else "OPEN THE DOORS", func():
		game.apply({"type": "StartService"})))
	_sheet(UI.scroll(v), 0.62)
	_notices()

func _opening_goal(fc: int) -> int:
	var share := [0.65, 0.7, 0.95, 0.95, 0.95]
	var q := ["worst", "bad", "good", "best", "excellent"].find(game.sim.loc.tierId)
	return maxi(3, roundi(fc * share[maxi(0, q)]))

func _stat(k: String, v: String, sub: String) -> Control:
	var b := UI.vbox(0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a := UI.kicker(k)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(a)
	var n := UI.label(v, 24, UI.INK, UI.sans(800))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(n)
	var s := UI.label(sub, 11, UI.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(s)
	return b

func _attention() -> Array:
	var sim: Sim = game.sim
	var l := sim.loc
	var out: Array = []
	for s in l.staff:
		if s.absentToday:
			out.append(["%s (%s) is absent today" % [s.name, sim.role(s.role).to_lower()], UI.BAD])
	for r in sim.uncoveredRoles():
		out.append(["No cook in today: you will cook at the pass, slowly" if r == "cook" else "Nobody on %s duty today" % sim.role(r).to_lower(), UI.WARN])
	var risks := sim.runOutRisks()
	for ing in risks:
		out.append(["%s runs out by about %d:00" % [game.content.ingredients[ing].name, 11 + floori(12 * risks[ing])], UI.WARN])
	for e in l.equipment:
		if e.broken:
			out.append(["%s is broken" % game.content.equipment[e.type].name, UI.BAD])
	return out

func _top_bar() -> void:
	var st: M.GameState = game.sim.state
	var bar := UI.hbox(14)
	var c := UI.vbox(0)
	c.add_child(UI.kicker("Cash"))
	c.add_child(UI.label(UI.money(st.cash), 18, UI.BAD if st.cash < 0 else UI.INK, UI.sans(800)))
	bar.add_child(c)
	var r := UI.vbox(0)
	r.add_child(UI.kicker("Rating"))
	r.add_child(UI.label(UI.stars(game.sim.loc.reputation), 18, UI.WARN, UI.sans(800)))
	bar.add_child(r)
	var e := UI.vbox(0)
	e.add_child(UI.kicker("Energy"))
	e.add_child(UI.label("%d" % roundi(st.owner.energy), 18, UI.INK, UI.sans(800)))
	bar.add_child(e)
	var p := UI.panel(bar, Color(UI.BG, 0.88), 14)
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.position = Vector2(14, 44)
	screen.add_child(p)

func _notices() -> void:
	var st: M.GameState = game.sim.state
	var shown := 0
	for n in st.pendingNotices:
		if n.begins_with("@"):
			continue
		toast(n, UI.MUTED, 6.0)
		shown += 1
		if shown >= 3:
			break
	if not st.pendingNotices.is_empty():
		game.apply({"type": "AckNotices"})

# ================================================================ tabs

func show_tab(name: String) -> void:
	_clear()
	current = "tab"
	_shade(0.82)
	var v := UI.vbox(12)
	var hd := UI.hbox()
	hd.add_child(UI.button("‹ Back", func():
		tab = ""
		current = ""
		_route()))
	var t := UI.label(name, 24, UI.INK, UI.serif(700))
	hd.add_child(t)
	v.add_child(hd)
	var body := UI.vbox(10)
	match name:
		"Staff": _tab_staff(body)
		"Stock": _tab_stock(body)
		"Menu": _tab_menu(body)
		"Money": _tab_money(body)
	v.add_child(UI.scroll(body))
	var m := UI.margin(v, 16, 52, 16, 20)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(m)

func _refresh_tab() -> void:
	current = ""
	_route()

func _tab_staff(v: VBoxContainer) -> void:
	var sim: Sim = game.sim
	v.add_child(UI.kicker("The brigade · team happiness %d of 100" % roundi(sim.outletHappiness()), UI.BRASS))
	for s in sim.loc.staff:
		var row := UI.vbox(6)
		var top := UI.hbox()
		var nm := UI.vbox(0)
		nm.add_child(UI.label(s.name, 16, UI.INK, UI.sans(700)))
		var status := "on shift" if s.workingToday else ("absent" if s.absentToday else ("training" if s.trainingUntil > sim.state.dayIndex else "day off"))
		nm.add_child(UI.label("%s · %s · %s/day" % [sim.role(s.role), status, UI.money(s.wage)], 12, UI.MUTED))
		top.add_child(UI.grow(nm))
		var sk := UI.label("%d" % roundi(s.skill) if s.skillKnown else "?", 22, UI.BRASS, UI.sans(800))
		top.add_child(sk)
		row.add_child(top)
		row.add_child(UI.kicker("Happiness"))
		row.add_child(UI.meter(s.morale / 100.0, UI.OK if s.morale >= 60 else (UI.WARN if s.morale >= 35 else UI.BAD)))
		var acts := UI.hbox(6)
		var sid: int = s.id
		acts.add_child(UI.grow(UI.button("Train", func():
			_result(game.apply({"type": "Train", "staffId": sid}))
			_refresh_tab())))
		if s.workingToday and sim.state.phase == "prep":
			acts.add_child(UI.grow(UI.button("Day off", func():
				_result(game.apply({"type": "GiveDayOff", "staffId": sid}))
				_refresh_tab())))
		acts.add_child(UI.grow(UI.button("Fire", func():
			_result(game.apply({"type": "Fire", "staffId": sid}))
			_refresh_tab())))
		row.add_child(acts)
		v.add_child(UI.panel(row))
	if not sim.state.applicants.is_empty():
		v.add_child(UI.kicker("Looking for work", UI.BRASS))
		for a in sim.state.applicants:
			var row := UI.hbox()
			var nm := UI.vbox(0)
			nm.add_child(UI.label(a.name, 15, UI.INK, UI.sans(700)))
			nm.add_child(UI.label("%s · skill about %d · asks %s/day" % [sim.role(a.role), roundi(a.skill / 10.0) * 10, UI.money(a.askingWage)], 12, UI.MUTED))
			row.add_child(UI.grow(nm))
			var aid: int = a.id
			row.add_child(UI.button("Hire", func():
				_result(game.apply({"type": "Hire", "applicantId": aid}))
				_refresh_tab(), true))
			v.add_child(UI.panel(row))

func _tab_stock(v: VBoxContainer) -> void:
	var sim: Sim = game.sim
	var l := sim.loc
	var use := sim.expectedDailyUse()
	var risks := sim.runOutRisks()
	v.add_child(UI.kicker("The larder · %s" % ("%d running out" % risks.size() if not risks.is_empty() else "stocked for tomorrow"), UI.BRASS))
	var sug := sim.suggestedOrder("sup_standard")
	var total := sim.orderTotal("sup_standard", sug) if not sug.is_empty() else 0
	if not sug.is_empty():
		v.add_child(UI.cta("ORDER THE USUAL · %s" % UI.money(total), func():
			_result(game.apply({"type": "PlaceOrder", "supplierId": "sup_standard", "lines": sug}))
			_refresh_tab()))
	if not risks.is_empty() and sim.state.phase == "prep":
		var lines := {}
		for ing in risks:
			lines[ing] = ceili(use.get(ing, 1.0)) - l.stockOf(ing) + 1
		v.add_child(UI.button("Cash & Carry run for today's gaps · %s" % UI.money(sim.orderTotal("sup_cash_carry", lines)), func():
			_result(game.apply({"type": "PlaceOrder", "supplierId": "sup_cash_carry", "lines": lines}))
			_refresh_tab()))
	for o in l.orders:
		v.add_child(UI.label("On order: %s, %s, arrives day %d" % [game.content.suppliers[o.supplierId].name, UI.money(o.total), o.dueDay + 1], 13, UI.MUTED))
	var ids: Array = use.keys()
	ids.sort_custom(func(a, b): return game.content.ingredients[a].name < game.content.ingredients[b].name)
	var box := UI.vbox(4)
	for ing in ids:
		var have := l.stockOf(ing)
		var per: float = use[ing]
		var row := UI.hbox()
		row.add_child(UI.grow(UI.label(game.content.ingredients[ing].name, 14)))
		var days := have / maxf(0.1, per)
		row.add_child(UI.label("%d in stock · %.1f days" % [have, days], 13, UI.BAD if days < 1 else (UI.WARN if days < 2 else UI.MUTED)))
		box.add_child(row)
	v.add_child(UI.panel(box))

func _tab_menu(v: VBoxContainer) -> void:
	var sim: Sim = game.sim
	v.add_child(UI.kicker("The carte · prices against par", UI.BRASS))
	for id in sim.loc.menu:
		var m: M.MenuItem = sim.loc.menu[id]
		var d: Content.Dish = game.content.dishes[id]
		var row := UI.hbox(8)
		var nm := UI.vbox(0)
		nm.add_child(UI.label(d.name, 15, UI.INK if m.enabled else UI.MUTED, UI.sans(700)))
		nm.add_child(UI.label("%s · par %s · %d sold yesterday" % [d.course, UI.money(d.basePrice), m.soldYesterday], 11, UI.MUTED))
		row.add_child(UI.grow(nm))
		var did: String = id
		row.add_child(UI.button("−", func():
			_result(game.apply({"type": "SetPrice", "dishId": did, "price": m.price - 1}))
			_refresh_tab()))
		row.add_child(UI.label(UI.money(m.price), 16, UI.BRASS, UI.sans(800)))
		row.add_child(UI.button("+", func():
			_result(game.apply({"type": "SetPrice", "dishId": did, "price": m.price + 1}))
			_refresh_tab()))
		var on := UI.button("ON" if m.enabled else "OFF", func():
			_result(game.apply({"type": "SetDishEnabled", "dishId": did, "enabled": not m.enabled}))
			_refresh_tab(), m.enabled)
		on.custom_minimum_size.x = 56
		row.add_child(on)
		v.add_child(UI.panel(row, UI.SURFACE, 12))

func _tab_money(v: VBoxContainer) -> void:
	var sim: Sim = game.sim
	var st := sim.state
	v.add_child(UI.kicker("The books · cash in hand", UI.BRASS))
	v.add_child(UI.label(UI.money(st.cash), 38, UI.BAD if st.cash < 0 else UI.INK, UI.serif(700)))
	for exp in [sim.explain("cash"), sim.explain("profit")]:
		var box := UI.vbox(4)
		box.add_child(UI.label(exp.title, 15, UI.INK, UI.sans(700)))
		for f in exp.factors:
			var row := UI.hbox()
			row.add_child(UI.grow(UI.label(f.label, 13, UI.MUTED)))
			row.add_child(UI.label(f.display, 13, UI.BAD if f.value < 0 else UI.INK, UI.sans(600)))
			box.add_child(row)
		if exp.howToImprove != null:
			box.add_child(UI.label(exp.howToImprove, 12, UI.BRASS, null, true))
		v.add_child(UI.panel(box))
	for ln in st.loans:
		v.add_child(UI.label("Loan: %s left · %s a week" % [UI.money(ln.outstanding), UI.money(ln.instalment)], 13, UI.MUTED))

# ================================================================ service

func show_service() -> void:
	_clear()
	current = "service"
	if room.loc_id != game.sim.loc.id:
		room.build(game.sim)
	var top := UI.vbox(6)
	var row := UI.hbox(12)
	var clk := UI.label("11:00", 30, UI.INK, UI.serif(700))
	_hud.clock = clk
	row.add_child(clk)
	var mid := UI.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sv := UI.label("", 13, UI.INK, UI.sans(700))
	_hud.served = sv
	mid.add_child(sv)
	var mt := UI.meter(0, UI.BRASS, 4)
	_hud.meter = mt
	mid.add_child(mt)
	var lost := UI.label("", 11, UI.MUTED)
	_hud.lost = lost
	mid.add_child(lost)
	row.add_child(mid)
	var cash := UI.label("", 16, UI.INK, UI.sans(800))
	_hud.cash = cash
	row.add_child(cash)
	top.add_child(row)
	var speeds := UI.hbox(6)
	var names := ["II", "1×", "2×", "4×"]
	_hud.speeds = []
	for i in 4:
		var b := UI.button(names[i], func():
			game.set_speed(i)
			_update_hud())
		b.custom_minimum_size = Vector2(52, 36)
		speeds.add_child(b)
		_hud.speeds.append(b)
	var fav := UI.label("", 12, UI.BRASS, UI.sans(700))
	_hud.favours = fav
	speeds.add_child(UI.grow(UI.spacer()))
	speeds.add_child(fav)
	top.add_child(speeds)
	var tp := UI.panel(top, Color(UI.BG, 0.9), 16)
	tp.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tp.offset_left = 10
	tp.offset_right = -10
	tp.offset_top = 36
	screen.add_child(tp)
	# Bottom: where you stand.
	var bot := UI.vbox(6)
	var hint := UI.label("Tap a party to help them · tap a job to do it yourself", 11, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot.add_child(hint)
	var zr := UI.hbox(6)
	_hud.zones = []
	for z in Restaurant3D.ZONES:
		var b := UI.button(Sim.areaNames[z], func():
			_result(game.apply({"type": "OwnerStand", "area": z}))
			_update_hud())
		b.custom_minimum_size = Vector2(0, 46)
		zr.add_child(UI.grow(b))
		_hud.zones.append(b)
	bot.add_child(zr)
	var bp := UI.panel(bot, Color(UI.BG, 0.9), 16)
	bp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bp.offset_left = 10
	bp.offset_right = -10
	bp.offset_bottom = -18
	bp.offset_top = -112
	screen.add_child(bp)
	_update_hud()

func _update_hud() -> void:
	if current != "service" or _hud.is_empty():
		return
	var sim: Sim = game.sim
	var s := sim.ss
	if s == null:
		return
	var t := sim.loc.today
	_hud.clock.text = sim.clock(s.tick)
	_hud.served.text = "%d served · %d of %d walk-outs" % [t.groupsServed, s.lost, s.target]
	var meter: Control = _hud.meter
	meter.queue_redraw()
	_hud.lost.text = "Lost %d. Keep it at %d or fewer." % [s.lost, s.target]
	_hud.lost.add_theme_color_override("font_color", UI.BAD if s.lost > s.target else UI.MUTED)
	_hud.cash.text = UI.money(sim.state.cash)
	_hud.favours.text = "FAVOURS %d" % s.favours
	for i in 4:
		var b: Button = _hud.speeds[i]
		b.add_theme_stylebox_override("normal", UI.flat(Color("2a2416"), 10, UI.BRASS) if game.speed == i else UI.flat(UI.SURFACE2, 10, UI.LINE))
	for i in 4:
		var b: Button = _hud.zones[i]
		var on: bool = s.ownerArea == Restaurant3D.ZONES[i]
		b.add_theme_stylebox_override("normal", UI.flat(Color("17323a"), 10, UI.OWNER) if on else UI.flat(UI.SURFACE2, 10, UI.LINE))
	# Meter shows walk-out budget used.
	meter.draw.connect(func(): pass) if false else null

func _unhandled_input(ev: InputEvent) -> void:
	if current != "service" or game.sim == null:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_drag_from = ev.position
			_dragging = false
		elif not _dragging:
			_tap(ev.position)
	elif ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if ev.position.distance_to(_drag_from) > 12:
			_dragging = true
			room.pan_camera(-ev.relative.y * 0.012)

func _tap(pos: Vector2) -> void:
	_close_popup()
	var hit := room.pick(pos)
	if hit.is_empty():
		return
	match hit.kind:
		"task":
			var r = game.apply({"type": "OwnerQueueTask", "taskId": hit.id})
			if r.ok:
				toast("You'll do that next.", UI.OWNER, 1.6)
			else:
				_result(r)
		"group":
			_group_popup(hit.id, pos)
		"zone":
			game.apply({"type": "OwnerStand", "area": Restaurant3D.ZONES[hit.id]})
			_update_hud()

func _group_popup(gid: int, at: Vector2) -> void:
	var sim: Sim = game.sim
	var g := sim.ss.group(gid)
	if g == null:
		return
	var v := UI.vbox(8)
	var words := {"waitTable": "waiting for a table", "waitOrder": "waiting to order", "waitFood": "waiting for food",
		"eating": "eating", "waitBill": "waiting for the bill"}
	v.add_child(UI.kicker("Party of %d · %s" % [g.size, M.segments[0] if false else g.segment], UI.BRASS))
	v.add_child(UI.label(words.get(g.state, g.state).capitalize(), 17, UI.INK, UI.serif(700)))
	if g.waiting:
		var left := 1.0 - float(g.counter) / maxi(1, sim.patienceLimit(g))
		v.add_child(UI.meter(left, UI.OK if left > 0.5 else (UI.WARN if left > 0.25 else UI.BAD), 5))
	var acts := UI.hbox(6)
	if g.state == "waitFood" and not g.rushed:
		acts.add_child(UI.grow(UI.button("Rush", func():
			_result(game.apply({"type": "OwnerRush", "groupId": gid}))
			_close_popup(), true)))
	if g.waiting and not g.treated:
		acts.add_child(UI.grow(UI.button("Treat (%s)" % UI.money(game.content.balance.i("TREAT_COST")), func():
			_result(game.apply({"type": "OwnerTreat", "groupId": gid}))
			_close_popup())))
	if g.state == "eating" and not g.broughtBill:
		acts.add_child(UI.grow(UI.button("Bring the bill", func():
			_result(game.apply({"type": "OwnerBringBill", "groupId": gid}))
			_close_popup())))
	if acts.get_child_count() > 0:
		v.add_child(acts)
	else:
		v.add_child(UI.label("Nothing you can do for them right now.", 12, UI.MUTED))
	var p := UI.panel(v, Color(UI.BG, 0.96), 14, UI.BRASS.darkened(0.4))
	p.custom_minimum_size.x = 300
	overlay.add_child(p)
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	p.position = Vector2(clampf(at.x - p.size.x / 2, 10, vp.x - p.size.x - 10), clampf(at.y - p.size.y - 30, 150, vp.y - p.size.y - 130))
	_popup = p

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

func _process(_d: float) -> void:
	var snd = get_node_or_null("/root/Sound")
	if snd != null and game.sim != null and game.sim.state.hasLocation and game.sim.ss != null:
		var people := 0
		for g in game.sim.ss.groups:
			if not g.gone and not g.delivery:
				people += g.size
		snd.room_level = people / 40.0
		var cooking := 0
		for k in game.sim.ss.tasks:
			if k.type == "cook" and k.started:
				cooking += 1
		snd.kitchen_level = cooking / 6.0
	if current == "service" and _hud.has("meter") and game.sim != null and game.sim.ss != null:
		var s: M.ServiceState = game.sim.ss
		var meter: Control = _hud.meter
		var used := float(s.lost) / maxi(1, s.target)
		if not meter.has_meta("v") or meter.get_meta("v") != used:
			meter.set_meta("v", used)
			for c in meter.draw.get_connections():
				meter.draw.disconnect(c.callable)
			meter.draw.connect(func():
				meter.draw_rect(Rect2(Vector2.ZERO, meter.size), Color(UI.LINE, 0.8))
				meter.draw_rect(Rect2(Vector2.ZERO, Vector2(meter.size.x * clampf(used, 0, 1), meter.size.y)), UI.BAD if used > 1 else (UI.WARN if used > 0.6 else UI.OK)))
			meter.queue_redraw()

# ================================================================ close

func show_close() -> void:
	_clear()
	current = "close"
	var sim: Sim = game.sim
	var t := sim.loc.today
	var s: M.ServiceState = sim.loc.service
	_shade(0.5)
	var v := UI.vbox(12)
	var met: bool = s != null and s.lost <= s.target and not t.closed
	var day0 := t.dayIndex == 0
	var goal := _opening_goal(t.forecast) if day0 and t.forecast > 0 else -1
	var kick := "Opening night · after service" if day0 else "%s · after service" % sim.dateLabel()
	v.add_child(UI.kicker(kick, UI.BRASS))
	var verdict := ""
	if t.closed:
		verdict = "CLOSED"
	elif goal > 0:
		verdict = "GOAL MET" if t.groupsServed >= goal else "GOAL MISSED"
	else:
		verdict = "TARGET MET" if met else "TARGET MISSED"
	var good := verdict.ends_with("MET")
	var stamp := UI.label(verdict, 34, UI.OK if good else UI.BAD, UI.serif(800))
	v.add_child(stamp)
	stamp.pivot_offset = Vector2(120, 20)
	stamp.scale = Vector2(1.6, 1.6)
	stamp.modulate.a = 0
	var tw := stamp.create_tween().set_parallel()
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.2).set_delay(0.25)
	v.add_child(UI.label(sim.dayInOneLine(t), 14, UI.MUTED, null, true))
	if goal > 0:
		v.add_child(UI.label("Served %d of %d." % [t.groupsServed, goal], 16, UI.INK, UI.sans(700)))
	var stats := UI.hbox(0)
	stats.add_child(_stat("SERVED", str(t.groupsServed), "parties"))
	stats.add_child(_stat("WALK-OUTS", str(t.walkouts), "of %d allowed" % (s.target if s != null else 0)))
	stats.add_child(_stat("REVIEWS", "%.1f" % t.avgStars, "stars"))
	v.add_child(UI.panel(stats, UI.SURFACE, 12))
	var money := UI.vbox(4)
	for row in [["Sales", t.revenue], ["Ingredients", -t.ingredientSpend], ["Wages", -t.wages], ["Rent", -t.rent], ["Utilities", -t.utilities], ["Other", -(t.upkeep + t.marketing + t.other)]]:
		if row[1] == 0 and row[0] != "Sales":
			continue
		var r := UI.hbox()
		r.add_child(UI.grow(UI.label(row[0], 14, UI.MUTED)))
		r.add_child(UI.label(UI.money(row[1]), 14, UI.BAD if row[1] < 0 else UI.INK, UI.sans(600)))
		money.add_child(r)
	var pr := UI.hbox()
	pr.add_child(UI.grow(UI.label("Profit today", 16, UI.INK, UI.sans(800))))
	pr.add_child(UI.label(UI.money(t.profit), 18, UI.OK if t.profit >= 0 else UI.BAD, UI.sans(800)))
	money.add_child(pr)
	v.add_child(UI.panel(money))
	var causes := sim.topCauses(t, 3)
	if not causes.is_empty():
		v.add_child(UI.kicker("What cost you tonight"))
		for e in causes:
			v.add_child(UI.label("• " + e.text, 13, UI.INK, null, true))
	var sp := UI.spacer()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var tabs := UI.hbox(6)
	for tb in ["Staff", "Stock", "Menu", "Money"]:
		tabs.add_child(UI.grow(UI.button(tb, func():
			tab = tb
			current = ""
			_route())))
	v.add_child(tabs)
	v.add_child(UI.cta("SLEEP · START DAY %d" % (sim.state.dayIndex + 2), func():
		game.apply({"type": "EndDay"})))
	_sheet(UI.scroll(v), 0.8)

func show_game_over() -> void:
	_clear()
	current = "gameOver"
	_shade(0.8)
	var v := UI.vbox(14)
	v.add_child(UI.kicker("The end of the road", UI.BAD))
	v.add_child(UI.title("Closed for good", 34))
	var reason = game.sim.state.gameOverReason
	v.add_child(UI.label(reason if reason != null else "", 16, UI.INK, null, true))
	v.add_child(UI.cta("TRY AGAIN", func():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.SAVE_PATH))
		_new_game()))
	var m := UI.margin(v, 28, 200, 28, 40)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(m)

# ================================================================ incident cards

func _maybe_card() -> void:
	if _card_open or game.sim == null:
		return
	var open: Array = game.sim.state.openIncidents.filter(func(i): return i.locationId == game.sim.loc.id)
	if open.is_empty():
		game.paused_by_card = false
		return
	_show_card(open[0])

func _show_card(inst: M.IncidentInstance) -> void:
	_card_open = true
	var sim: Sim = game.sim
	var def: Content.IncidentDef = game.content.incidents[inst.incidentId]
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var v := UI.vbox(10)
	v.add_child(UI.kicker(def.category + (" · decide now" if inst.countdown > 0 else ""), UI.WARN))
	v.add_child(UI.title(sim.incidentText(inst, def.title), 24))
	v.add_child(UI.label(sim.incidentText(inst, def.text), 15, Color("d9cfbf"), UI.sans(400), true))
	for o in def.options:
		var why = sim.optionBlocked(inst, o)
		var cost := sim.optionCash(inst, o)
		var odds = sim.optionOdds(o)
		var txt := sim.incidentText(inst, o.label)
		var sub: Array = []
		if cost != 0: sub.append(UI.money(cost))
		if odds != null: sub.append(odds)
		if why != null: sub.append(why)
		var b := UI.button(txt + ("   ·   " + " · ".join(sub) if not sub.is_empty() else ""), func():
			var r = game.apply({"type": "ResolveIncident", "instanceId": inst.id, "optionId": o.id})
			shade.queue_free()
			_card_open = false
			game.paused_by_card = false
			if r.ok and r.value != null:
				toast(str(r.value), UI.INK, 5.0)
			current = "" if current != "service" else current
			_route(), o.id == def.defaultOption)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 52)
		b.disabled = why != null
		v.add_child(b)
	var p := UI.panel(v, UI.BG, 20, UI.WARN.darkened(0.4))
	p.set_anchors_preset(Control.PRESET_CENTER)
	shade.add_child(p)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.remove_child(p)
	shade.add_child(c)
	var mw := MarginContainer.new()
	mw.add_theme_constant_override("margin_left", 16)
	mw.add_theme_constant_override("margin_right", 16)
	p.custom_minimum_size.x = minf(get_viewport().get_visible_rect().size.x - 32, 420)
	c.add_child(p)

# ================================================================ feedback

func _result(r) -> void:
	if r == null or r.ok:
		return
	toast(r.message if r.message != null else "That is not possible right now.", UI.BAD, 3.0)

func toast(text: String, color := UI.INK, secs := 3.0) -> void:
	var l := UI.label(text, 13, color, UI.sans(600), true)
	var p := UI.panel(l, Color(UI.BG, 0.94), 12, Color(color, 0.4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	if toasts.get_child_count() > 4:
		toasts.get_child(0).queue_free()
	p.modulate.a = 0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(secs)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

func _on_events(events: Array) -> void:
	var snd = get_node_or_null("/root/Sound")
	for e in events:
		if snd != null:
			match e.type:
				"groupPaid": snd.play("coin", -6.0, 0.15)
				"groupWalkedOut": snd.play("walkout", -4.0, 0.4)
				"incidentRaised": snd.play("incident", -3.0, 0.5)
				"equipmentBroke": snd.play("breakdown", -3.0, 0.5)
				"stageReached", "objectiveDone": snd.play("stageup", -3.0, 1.0)
				"dishReady": snd.play("bell", -16.0, 1.2, 0.02)
				"groupSeated": snd.play("tap", -18.0, 0.3)
		match e.type:
			"groupPaid":
				var tid = e.args.get("tableId")
				if tid != null and room.tables.has(tid):
					_float_money(room.tables[tid].pos + Vector3(0, 0.5, 0), "+" + UI.money(e.args.amount), UI.OK)
			"groupWalkedOut":
				var tid = e.args.get("tableId")
				var where: Vector3 = room.tables[tid].pos if tid != null and room.tables.has(tid) else room.spots.get("door", Vector3.ZERO)
				_float_money(where + Vector3(0, 0.6, 0), "WALKED OUT", UI.BAD)
			"dishUnavailable":
				toast("%s has sold out." % game.content.dishes[e.args.dishId].name, UI.WARN, 3.0)
			"equipmentBroke":
				toast("Something in the kitchen broke down.", UI.BAD, 3.0)
			"platesFull":
				toast("Out of clean plates: the kitchen has stopped. Send someone to Dishes.", UI.BAD, 4.0)
			"objectiveDone":
				toast("Goal complete!", UI.BRASS, 3.0)

func _float_money(world: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UI.sans(800)
	l.font_size = 48
	l.pixel_size = 0.0035
	l.outline_size = 12
	l.outline_modulate = Color("0b0a09")
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = world
	room.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", world.y + 0.6, 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

# ================================================================ autoplay (for recording)

func _autoplay() -> void:
	game.new_game(5, "normal")
	_intro_seen = true
	room.build(game.sim)
	current = ""
	_route()
