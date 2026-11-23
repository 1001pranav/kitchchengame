class_name UI
extends RefCounted
## House style: dark premium, brass accent, one ember call to action.
## Builders for the few widgets every screen uses.

const BG := Color("12100e")
const SURFACE := Color("1c1916")
const SURFACE2 := Color("28231f")
const LINE := Color("39322b")
const INK := Color("f1e8d8")
const MUTED := Color("9e9384")
const BRASS := Color("c9a55b")
const ON_BRASS := Color("17120c")
const EMBER := Color("c4553a")
const OK := Color("74c08f")
const WARN := Color("e2ae52")
const BAD := Color("e3705c")
const OWNER := Color("3f8c9a")

static var _fonts := {}

static func font(name: String) -> Font:
	if not _fonts.has(name):
		_fonts[name] = load("res://assets/fonts/%s.ttf" % name)
	return _fonts[name]

static func sans(weight := 500) -> Font:
	return font("Inter-%d" % weight)

static func serif(weight := 700) -> Font:
	return font("PlayfairDisplay-%d" % weight)

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = sans(500)
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	var sb := flat(SURFACE2, 10)
	t.set_stylebox("normal", "Button", flat(SURFACE2, 10, LINE))
	t.set_stylebox("hover", "Button", flat(Color("312a25"), 10, BRASS.darkened(0.3)))
	t.set_stylebox("pressed", "Button", flat(Color("3a322b"), 10, BRASS))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", flat(Color("1a1715"), 10, LINE))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_font("font", "Button", sans(700))
	t.set_font_size("font_size", "Button", 14)
	t.set_stylebox("panel", "PanelContainer", sb)
	t.set_stylebox("panel", "Panel", sb)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(1, 1, 1, 0.12)
	sc.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", sc)
	t.set_stylebox("grabber_highlight", "VScrollBar", sc)
	t.set_stylebox("grabber_pressed", "VScrollBar", sc)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	return t

static func flat(bg: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s

static func label(text: String, size := 15, color := INK, f: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if f != null:
		l.add_theme_font_override("font", f)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Small caps kicker: "OPENING NIGHT · YOUR GOAL".
static func kicker(text: String, color := MUTED) -> Label:
	var l := label(text.to_upper(), 11, color, sans(700))
	l.add_theme_constant_override("line_spacing", 0)
	return l

static func title(text: String, size := 30) -> Label:
	return label(text, size, INK, serif(700), true)

static func panel(content: Control, bg := SURFACE, radius := 14, border := LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, radius, border))
	p.add_child(content)
	return p

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h := 0, w := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c

static func grow(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

## The one ember call to action per screen.
static func cta(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_override("font", sans(800))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", flat(EMBER, 14))
	b.add_theme_stylebox_override("hover", flat(EMBER.lightened(0.08), 14))
	b.add_theme_stylebox_override("pressed", flat(EMBER.darkened(0.15), 14))
	b.add_theme_color_override("font_color", Color("fff3ea"))
	b.add_theme_color_override("font_hover_color", Color("fff3ea"))
	b.add_theme_color_override("font_pressed_color", Color("fff3ea"))
	b.pressed.connect(cb)
	_juice(b)
	return b

static func button(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	if primary:
		b.add_theme_stylebox_override("normal", flat(BRASS, 10))
		b.add_theme_stylebox_override("hover", flat(BRASS.lightened(0.1), 10))
		b.add_theme_stylebox_override("pressed", flat(BRASS.darkened(0.15), 10))
		b.add_theme_color_override("font_color", ON_BRASS)
		b.add_theme_color_override("font_hover_color", ON_BRASS)
		b.add_theme_color_override("font_pressed_color", ON_BRASS)
	b.pressed.connect(cb)
	_juice(b)
	return b

static func chip(text: String, color := BRASS) -> PanelContainer:
	var s := flat(Color(color.r, color.g, color.b, 0.14), 20, Color(color.r, color.g, color.b, 0.5))
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.content_margin_left = 9
	s.content_margin_right = 9
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text.to_upper(), 10, color, sans(700)))
	return p

## Squash on press: small, but it makes every button feel physical.
static func _juice(b: Button) -> void:
	b.button_down.connect(func():
		b.pivot_offset = b.size / 2
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.06))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

static func money(v) -> String:
	var n := roundi(v)
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("−" if n < 0 else "") + out

static func stars(r: float) -> String:
	return "%.1f★" % r

## A thin horizontal meter.
static func meter(value: float, color := BRASS, h := 4) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(LINE, 0.8))
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x * clampf(value, 0, 1), c.size.y)), color))
	return c

static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s

static func margin(c: Control, l := 16, t := 12, r := 16, b := 12) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(c)
	return m
