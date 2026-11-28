extends Control
## Hot-seat UI for GuildMasters. Everything is built in code; the rules live in src/game/game.gd.
## Interaction model: during Morning / first hire / Build the player clicks cards; a popup
## offers the actions that make sense, and cards that can't be used right now are dimmed.

const ICONS := "res://assets/icons/"
const ART := "res://assets/cards/"
const C_MERC := Color("2f6aa3")
const C_LOC := Color("2f7d50")
const C_QUEST := Color("a33a3a")
const C_LEGEND := Color("9a7410")
const C_GUILD := Color("5a479a")
const C_BG := Color("17191e")
const PCOL := [Color("6fa8ff"), Color("ff7a6f")]
const STAT_COL := ["b03a3a", "2f8a4e", "2f5fb0"]
const ORDER_ICON := {"work": "work", "act": "activate", "quest": "quest", "attack": "attack", "defend": "defend", "none": "night"}
const DIM := Color(0.38, 0.38, 0.40)
const C_ITEM := Color("8a5a2b")

var g: Game
var top: RichTextLabel
var market: VBoxContainer
var guild_box: VBoxContainer
var guild_row: HBoxContainer
var view_pi := -1        # whose team (mercenaries, locations) the board shows
var strip_scroll := {}   # sideways scroll of each card strip, kept across refreshes
const TEAM_W := 236
var fame_box: HBoxContainer
var log_box: RichTextLabel
var bar: VBoxContainer
var cover: ColorRect
var cover_label: Label
var cover_btn: Button
var dirty := false
var tex_cache := {}
var word_res := []   # [RegEx, replacement]
var card_re := RegEx.new()
var card_refs := []  # [[kind, id], ...]; fmt() links card names as [url=cN]
var preview: Control
var card_names := {}

# interaction state
var mode := ""        # "", "morning", "first_bid", "build"
var mode_pi := -1
var req := {}
var draft_orders := {}
var draft_bids := {}
var targeting := {}   # {"uid": int, "t": "work"|"quest"|"attack"}
var team := {}        # quest team picker: {"q": quest id, "sel": [uid, ...]}
var primary_btn: Button   # what the Space bar presses

# online play (web build): see src/game/online.gd
var net: Online
var me := -1          # my player index online; -1 = hot-seat
var log_sent := 0     # host: log lines already sent to the guest
var sync_queued := false
var net_js = null     # tests: stand-in for window.gmnet

func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 16
	theme = th
	_ensure_icons()
	Cards.load_edits()
	_init_format()
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var topbar := HBoxContainer.new()
	root.add_child(topbar)
	top = _rich("", 0, 16)
	topbar.add_child(top)
	var end_btn := Button.new()
	end_btn.text = "End game now & score"
	end_btn.tooltip_text = "Playtest helper: stop here and apply the final scoring."
	end_btn.pressed.connect(func():
		if net and not net.is_host:
			net.send({"t": "end"})
		elif g and not g.game_over:
			g.end_game()
			_show_game_over())
	topbar.add_child(_btn("Rules", _open_rules, false, "quest"))
	topbar.add_child(end_btn)
	fame_box = HBoxContainer.new()
	fame_box.add_theme_constant_override("separation", 8)
	root.add_child(fame_box)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	root.add_child(mid)
	market = _scroll_column(mid, 548)
	var gcol := VBoxContainer.new()   # both guilds pinned on top, the shown team scrolls below
	gcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gcol.add_theme_constant_override("separation", 6)
	mid.add_child(gcol)
	guild_row = HBoxContainer.new()
	guild_row.add_theme_constant_override("separation", 8)
	gcol.add_child(guild_row)
	guild_box = _scroll_column(gcol, 0)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	_link_cards(log_box)
	log_box.custom_minimum_size = Vector2(300, 0)
	log_box.add_theme_font_size_override("normal_font_size", 14)
	log_box.add_theme_font_size_override("bold_font_size", 14)
	mid.add_child(log_box)
	var bottom := PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, 120)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("262a33")
	sb.border_color = Color("e8d9a8")
	sb.border_width_top = 2
	sb.set_content_margin_all(10)
	bottom.add_theme_stylebox_override("panel", sb)
	root.add_child(bottom)
	var ps := ScrollContainer.new()
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ps.custom_minimum_size = Vector2(0, 150 if Online.available() else 110)
	bottom.add_child(ps)
	bar = VBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ps.add_child(bar)
	cover = ColorRect.new()
	cover.color = Color(0.06, 0.06, 0.08, 1)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.visible = false
	add_child(cover)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(cc)
	var cv := VBoxContainer.new()
	cc.add_child(cv)
	cover_label = Label.new()
	cover_label.add_theme_font_size_override("font_size", 32)
	cover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cover_label)
	cover_btn = Button.new()
	cover_btn.text = "I'm ready: show my screen"
	cover_btn.add_theme_font_size_override("font_size", 22)
	cv.add_child(cover_btn)
	_show_setup()

func _scroll_column(parent: Control, width: int) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if width > 0:
		s.custom_minimum_size = Vector2(width, 0)
	else:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	s.add_child(v)
	return v

# ------------------------------------------------------------------ text formatting (icons, stat colours)

func ii(name: String, size := 18) -> String:
	return "[img=%dx%d]%s%s.svg[/img]" % [size, size, ICONS, name]

func icon(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load(ICONS + name + ".svg")
	return tex_cache[name]

## Running the game before the editor has imported the SVGs (e.g. straight from the
## command line) would leave every icon blank, so when the raw SVGs are present we
## build the textures ourselves and register them under their res:// paths, where
## [img] tags find them. Exported builds have no raw SVGs and use the imported ones.
func _ensure_icons() -> void:
	for f in DirAccess.get_files_at(ICONS):
		if not f.ends_with(".svg"):
			continue
		var path := ICONS + f
		if not FileAccess.file_exists(path):
			continue
		var img := Image.new()
		if img.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0) != OK:
			continue
		var t := ImageTexture.create_from_image(img)
		t.take_over_path(path)
		tex_cache[f.get_basename()] = t

## Card picture, e.g. "mercs/bertram" (assets/cards/). Null when the card has none.
## Like _ensure_icons, falls back to the raw SVG when the editor hasn't imported it yet.
func card_art(key: String) -> Texture2D:
	if not tex_cache.has(ART + key):
		var path := ART + key + ".svg"
		var t: Texture2D = null
		if ResourceLoader.exists(path):
			t = load(path)
		elif FileAccess.file_exists(path):
			var img := Image.new()
			if img.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0) == OK:
				t = ImageTexture.create_from_image(img)
		tex_cache[ART + key] = t
	return tex_cache[ART + key]

func _init_format() -> void:
	word_res.clear()
	card_refs.clear()
	var pairs := [
		["\\bgold\\b", ii("gold")], ["\\bwood\\b", ii("wood")], ["\\bstone\\b", ii("stone")], ["\\bmetal\\b", ii("metal")],
		["\\bfame\\b", ii("fame")], ["\\bXP\\b", ii("xp")], ["\\b[Dd]efense\\b", ii("defense")],
		["\\bNight:", ii("night") + " Night:"], ["\\bActivate:", ii("activate") + " Activate:"], ["\\bWork:", ii("work") + " [b]Work:[/b]"],
		["\\bWhen attacking:", ii("attack") + " When attacking:"], ["\\bOwner:", "[b]Owner:[/b]"],
		["\\bMight\\b", ii("might") + "[color=#ff8a7a][b]Might[/b][/color]"], ["\\bSkill\\b", ii("skill") + "[color=#7fe0a0][b]Skill[/b][/color]"],
		["\\bIntellect\\b", ii("intellect") + "[color=#8fb8ff][b]Intellect[/b][/color]"]]
	for p in pairs:
		var r := RegEx.new()
		r.compile(p[0])
		word_res.append([r, p[1]])
	var names := {}
	for kind in ["mercs", "locs", "items", "quests", "legends"]:
		var src: Dictionary = {"mercs": Cards.MERCS, "locs": Cards.LOCS, "items": Cards.ITEMS, "quests": Cards.QUESTS, "legends": Cards.LEGENDS}[kind]
		for id in src:
			var nm: String = str(src[id].get("name", ""))
			if nm != "" and not names.has(nm):
				names[nm] = card_refs.size()
				card_refs.append(["quests" if kind == "legends" else kind, id])
	var keys := names.keys()
	keys.sort_custom(func(a, b): return a.length() > b.length())
	var esc_keys := keys.map(func(k): return _re_escape(k))
	card_re.compile("\\b(" + "|".join(esc_keys) + ")\\b")
	card_names = names

func _re_escape(t: String) -> String:
	var out := ""
	for ch in t:
		out += ("\\" + ch) if ch in ".^$*+?()[]{}|\\/" else ch
	return out

## Plain rules text -> bbcode with icons. Each pattern runs once, so icon paths are never re-matched.
func fmt(t: String) -> String:
	t = _esc(t)
	var out := ""
	var at := 0
	for m in card_re.search_all(t):
		out += t.substr(at, m.get_start() - at) + "[url=c%d]%s[/url]" % [card_names[m.get_string()], m.get_string()]
		at = m.get_end()
	t = out + t.substr(at)
	for p in word_res:
		t = p[0].sub(t, p[1], true)
	return t

func chips(s: Array) -> String:
	var out := ""
	for i in 3:
		out += "[bgcolor=#%s][color=#ffffff][b] %s %d [/b][/color][/bgcolor] " % [STAT_COL[i], ii(["might", "skill", "intellect"][i], 16), s[i]]
	return out

func roman(n: int) -> String:
	return ["I", "II", "III"][clamp(n, 1, 3) - 1]

## Resources with this night's expected production (+N) printed above each amount; gold is net of wages.
func res_table(pi: int) -> String:
	var p: Dictionary = g.players[pi]
	var prod := g.projected_production(pi, g.phase != "Morning")
	var t := "[table=5]"
	prod.gold -= g.wages_due(pi)   # gold is shown net of tonight's wages
	for r in ["fame", "gold", "wood", "stone", "metal"]:
		var n: int = prod.get(r, 0)
		var col := "7fe0a0" if n > 0 else "667"
		if n < 0:
			col = "ff5a4f" if p[r] + n < 0 else "ffb84f"   # red: can't pay every wage, someone leaves
		t += "[cell][center][font_size=14][color=#%s]%s[/color][/font_size][/center][/cell]" % [col, ("%+d/night" % n) if n != 0 else ""]
	for r in ["fame", "gold", "wood", "stone", "metal"]:
		t += "[cell][center]%s %d   [/center][/cell]" % [ii(r, 20), p[r]]
	return t + "[/table]"

func res_line(p: Dictionary) -> String:
	return "%s %d   %s %d   %s %d   %s %d   %s %d" % [ii("fame", 20), p.fame, ii("gold", 20), p.gold, ii("wood", 20), p.wood, ii("stone", 20), p.stone, ii("metal", 20), p.metal]

# ------------------------------------------------------------------ small widgets

func _rich(text: String, width := 0, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0:
		r.custom_minimum_size = Vector2(width, 0)
	else:
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(k, size)
	r.text = text
	_link_cards(r)
	return r

## Card names in a label become hoverable: hovering shows a preview of that card.
func _link_cards(r: RichTextLabel) -> void:
	if "[url=c" in r.text and r.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.meta_hover_started.connect(func(m): _show_preview(str(m)))
	r.meta_hover_ended.connect(func(_m): _hide_preview())

func _hide_preview() -> void:
	if preview:
		preview.queue_free()
		preview = null

func _show_preview(m: String) -> void:
	_hide_preview()
	if not m.begins_with("c") or g == null:
		return
	var ref: Array = card_refs[int(m.substr(1))]
	var id: String = ref[1]
	var pc: PanelContainer
	match ref[0]:
		"mercs":
			var inst := {}
			for mm in g.merc_row + g.players.reduce(func(a, p): return a + p.mercs, []):
				if mm.id == id:
					inst = mm
			var shown: Dictionary = inst if not inst.is_empty() else {"uid": -1, "id": id, "xp": 0, "equip": [], "perm": [0, 0, 0], "horn": 0, "order": {}, "hired_today": false}
			pc = _card({"k": "preview"}, Cards.MERCS[id].name, "Lv " + roman(g.level(shown)), _merc_body(-1, shown), C_MERC, 252, "mercs/" + id)
		"locs":
			pc = _card({"k": "preview"}, Cards.LOCS[id].name, "Lv " + roman(g.loc_level(id)), _loc_body(id, g.owner_of(id)), C_LOC, 252, "locs/" + id)
		"items":
			var d: Dictionary = Cards.ITEMS[id]
			var t := "[color=#aab]%s · value %d[/color]\n" % ["Equipment" if d.kind == "equip" else "Relic", d.value]
			pc = _card({"k": "preview"}, d.name, ii("equip" if d.kind == "equip" else "relic", 20), t + fmt(d.text), C_ITEM, 252, "items/" + id)
		"quests":
			pc = _card({"k": "preview"}, g.qname(id), "", _quest_body(id), C_LEGEND if Cards.LEGENDS.has(id) else C_QUEST, 252, "quests/" + id)
	pc.modulate = Color.WHITE
	pc.top_level = true
	pc.z_index = 100
	_ignore_mouse(pc)
	add_child(pc)
	preview = pc
	var mp := get_global_mouse_position() + Vector2(18, 18)
	var place := func():
		pc.reset_size()
		var vs := get_viewport_rect().size
		var at := mp
		if at.x + pc.size.x > vs.x:
			at.x -= pc.size.x + 36
		if at.y + pc.size.y > vs.y:
			at.y = max(0.0, vs.y - pc.size.y)
		pc.global_position = at
	pc.minimum_size_changed.connect(place)
	place.call()

func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("e8d9a8"))
	return l

func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	return f

func _btn(text: String, cb: Callable, disabled := false, ico := "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	if ico != "":
		b.icon = icon(ico)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 22)
	b.pressed.connect(cb)
	return b

func _spin(mn: int, mx: int, val: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = max(mn, mx)
	s.step = 1
	s.rounded = true
	s.value = clamp(val, mn, max(mn, mx))
	return s

func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _esc(s: String) -> String:
	return s.replace("[", "(").replace("]", ")")

func _pname(pi: int) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [PCOL[pi % 2].to_html(false), _esc(g.players[pi].name)]

## A card: coloured frame, title row with an optional badge, body text.
func _card(meta: Dictionary, title: String, badge: String, body: String, col: Color, width := 252, art := "") -> PanelContainer:
	var pc := PanelContainer.new()
	if width > 0:
		pc.custom_minimum_size = Vector2(width, 0)
	else:
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.62)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 3)
	pc.add_child(v)
	var hdr := HBoxContainer.new()
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hdr)
	var tex: Texture2D = card_art(art) if art != "" else null
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hdr.add_child(tr)
	var tl := _rich("[b]%s[/b]" % title, 0, 18)
	hdr.add_child(tl)
	if badge != "":
		var bl := _rich("[right]%s[/right]" % badge, 70, 18)
		bl.size_flags_horizontal = Control.SIZE_SHRINK_END
		hdr.add_child(bl)
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	var body_rtl := _rich(body, 0, 15)
	v.add_child(body_rtl)
	var interactive := _interactive(meta)
	var own_info: bool = meta.get("k", "") == "guild" and targeting.is_empty()
	# the rival's team, opened from its guild panel, is for reading: don't dim it
	own_info = own_info or (meta.get("k", "") in ["merc", "loc"] and meta.pi != mode_pi and mode_pi >= 0)
	if (mode != "" or not targeting.is_empty()) and not interactive and not own_info:
		pc.modulate = DIM
	if interactive:
		if not targeting.is_empty() or (mode == "morning" and meta.get("k", "") == "rowloc" and _conquerable(meta.lid)):
			sb.border_color = Color("ffd23f")
			sb.set_border_width_all(3)
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		body_rtl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pc.tooltip_text = _tooltip(meta)
		var base_col := sb.border_color
		pc.mouse_entered.connect(func():
			sb.border_color = Color.WHITE
			sb.set_border_width_all(3))
		pc.mouse_exited.connect(func():
			sb.border_color = base_col
			sb.set_border_width_all(3 if not targeting.is_empty() else 2))
		pc.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_card(meta))
	var lv_ref := _levels_ref(meta)
	if not lv_ref.is_empty():
		pc.tooltip_text = (pc.tooltip_text + "\n" if pc.tooltip_text != "" else "") + "Right-click: see every level"
		pc.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				_show_levels(lv_ref[0], lv_ref[1], lv_ref[2]))
	return pc

## [table, id, current level] for cards that have levels (mercenaries and locations), else [].
func _levels_ref(meta: Dictionary) -> Array:
	match meta.get("k", ""):
		"merc", "rowmerc":
			var m := g.find_merc(meta.pi, meta.uid) if meta.k == "merc" else g.row_merc(meta.uid)
			return [] if m.is_empty() else ["MERCS", m.id, g.level(m)]
		"loc", "rowloc":
			return ["LOCS", meta.lid, g.loc_level(meta.lid)]
	return []

## Popup with every level of a mercenary or location (the editor's card view), the current one named on top.
func _show_levels(t: String, id: String, lv: int) -> void:
	var ed = preload("res://src/scenes/editor/editor.gd").new()
	ed.ui = self
	var c: Control = ed._card_view(t, id)
	ed.free()
	c.modulate = Color.WHITE
	var p := PopupPanel.new()
	var v := VBoxContainer.new()
	v.add_child(_rich("[b]%s[/b]: now level %s" % [_esc(Cards.table(t)[id].name), roman(lv)], 290, 14))
	v.add_child(c)
	p.add_child(v)
	_place(p)

func _tooltip(meta: Dictionary) -> String:
	if not targeting.is_empty():
		return "Choose this target"
	match mode:
		"morning":
			return "Give an order" if meta.k == "merc" else "Place or change a bid"
		"first_bid":
			return "Bid on this mercenary"
		"build":
			return {"loc": "Upgrade or build a wall", "guild": "Construct guild buildings", "merc": "Move equipment"}.get(meta.k, "")
	return ""

# ------------------------------------------------------------------ setup / game over

func _show_setup() -> void:
	mode = ""
	net = null
	me = -1
	_clear(bar)
	top.text = "[b]GuildMasters[/b]: hot-seat playtest build"
	if Online.available():
		top.text = "[b]GuildMasters[/b]: online and hot-seat playtest build"
		_online_setup_row()
	bar.add_child(_header("New game (2 players, hot-seat on this computer)"))
	var row := HBoxContainer.new()
	bar.add_child(row)
	var n1 := LineEdit.new()
	n1.text = "Player 1"
	n1.custom_minimum_size = Vector2(200, 0)
	var n2 := LineEdit.new()
	n2.text = "Player 2"
	n2.custom_minimum_size = Vector2(200, 0)
	var bot := CheckBox.new()
	bot.text = "Player 2 is a bot (solo practice)"
	var seed_box := _spin(0, 999999, 0)
	row.add_child(n1)
	row.add_child(n2)
	row.add_child(bot)
	var sl := Label.new()
	sl.text = "  Seed (0 = random):"
	row.add_child(sl)
	row.add_child(seed_box)
	row.add_child(_btn("Rules", _open_rules, false, "quest"))
	row.add_child(_btn("Editor", _open_editor, false, "build"))
	row.add_child(_btn("Start game", func(): _new_game([n1.text.strip_edges(), n2.text.strip_edges()], [false, bot.button_pressed], int(seed_box.value))))

func _new_game(names: Array, bots: Array, seed_val: int) -> void:
	g = Game.new()
	view_pi = -1
	g.changed.connect(_mark_dirty)
	g.logged.connect(_on_log)
	g.need_choice.connect(_on_need)
	log_box.clear()
	g.setup(names, bots, seed_val)   # its log lines arrive through `logged`
	_clear(bar)
	_refresh()
	_start()

func _start() -> void:
	await g.run()
	_show_game_over()
	_sync()

func _show_game_over() -> void:
	mode = ""
	targeting = {}
	_refresh()
	_clear(bar)
	bar.add_child(_header("Game over: %s wins!" % g.players[g.winner].name))
	for pi in g.n:
		var s: Dictionary = g.final_scores[pi]
		bar.add_child(_rich("%s: %d %s + %d location levels + %d mercenary levels + %d from leftover resources = [b]%d[/b] (legendary quests: %d)" % [_pname(pi), s.fame, ii("fame"), s.locs, s.mercs, s.res, s.total, g.players[pi].legends]))
	bar.add_child(_btn("New game", _show_setup))

func _on_log(t: String) -> void:
	if t.begins_with("==="):
		log_box.append_text("\n[b][color=#e8d9a8]%s[/color][/b]\n" % _esc(t))
	else:
		log_box.append_text(fmt(t) + "\n")

func _mark_dirty() -> void:
	if not dirty:
		dirty = true
		call_deferred("_refresh")
	if net and net.is_host and not sync_queued:
		sync_queued = true
		call_deferred("_sync")

# ------------------------------------------------------------------ board rendering

func _refresh() -> void:
	dirty = false
	_hide_preview()
	if g == null:
		return
	top.text = "[b]Round %d[/b]  ·  [b]%s[/b]  ·  Priority: %s" % [g.round_num, g.phase, _pname(g.priority)]
	_render_fame_track()
	_clear(market)
	_clear(guild_box)
	_render_market()
	if view_pi < 0 or view_pi >= g.n:
		view_pi = max(me, 0)
	_clear(guild_row)
	var order_list := range(g.n)
	if me >= 0:   # online: my guild always on the left
		order_list.erase(me)
		order_list.push_front(me)
	for pi in order_list:
		guild_row.add_child(_render_guild(pi))
	_render_team(view_pi)
	if mode != "":
		_render_mode_bar()

## Fame track: where each player stands, and each milestone's tile, effect and owner.
func _render_fame_track() -> void:
	_clear(fame_box)
	var who := _rich("%s [b]Fame track[/b]\n%s" % [ii("fame", 22), "\n".join(range(g.n).map(func(pi): return "%s  %s [b]%d[/b]" % [_pname(pi), ii("fame"), g.players[pi].fame]))], 190, 16)
	fame_box.add_child(_framed(who, Color("2a6f6a"), 1.0))
	for s in Cards.FAME_SPACES:
		var tile: String = g.fame_tiles[s]
		var taken: int = g.fame_taken.get(s, -1)
		var status := "[color=#8fe0a0]Open[/color]"
		if taken >= 0:
			status = "Taken by %s" % _pname(taken)
		else:
			var close := []
			for pi in g.n:
				close.append("%s needs %d" % [_esc(g.players[pi].name), s - g.players[pi].fame])
			status += "  [color=#aab]%s[/color]" % ", ".join(close)
		var t := "%s [b]%d[/b]  ·  [b]%s[/b]\n%s\n%s" % [ii("fame"), s, Cards.TILES[tile].name, fmt(Cards.TILES[tile].text), status]
		var panel := _framed(_rich(t, 0, 15), Color("2a6f6a") if taken < 0 else Color("444"), 1.0 if taken < 0 else 0.55)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fame_box.add_child(panel)

func _framed(c: Control, col: Color, alpha: float) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.6)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	pc.add_theme_stylebox_override("panel", sb)
	pc.modulate = Color(1, 1, 1, alpha) if alpha >= 1.0 else DIM
	pc.add_child(c)
	return pc

func _render_market() -> void:
	market.add_child(_header("Legendary quests  (game ends when all are completed)"))
	var f := _flow()
	for q in g.legends:
		f.add_child(_card({"k": "legend", "q": q}, g.qname(q), "", _quest_body(q), C_LEGEND, 252, "quests/" + q))
	for q in g.legends_done:
		f.add_child(_card({"k": "done"}, "[s]%s[/s]" % g.qname(q), "", "Completed", C_LEGEND.darkened(0.4), 252, "quests/" + q))
	market.add_child(f)
	market.add_child(_header("Quests  (deck %d · discard %d)" % [g.quest_deck.size(), g.quest_discard.size()]))
	f = _flow()
	for q in g.quest_row:
		f.add_child(_card({"k": "quest", "q": q}, g.qname(q), "", _quest_body(q), C_QUEST, 252, "quests/" + q))
	market.add_child(f)
	market.add_child(_header("Locations for sale  (deck %d · discard %d)" % [g.loc_deck.size(), g.loc_discard.size()]))
	f = _flow()
	for l in g.loc_row:
		f.add_child(_card({"k": "rowloc", "lid": l}, g.lname(l), "%s %d" % [ii("gold", 20), g.bid_min("L" + l, mode_pi if mode == "morning" else -1)], _loc_body(l, -1) + ("\n[color=#ffd23f]%s [b]You can conquer this[/b][/color]" % ii("attack") if mode == "morning" and _conquerable(l) else ""), C_LOC, 252, "locs/" + l))
	market.add_child(f)
	market.add_child(_header("Mercenaries for hire  (deck %d)" % g.merc_deck.size()))
	f = _flow()
	for m in g.merc_row:
		f.add_child(_card({"k": "rowmerc", "uid": m.uid}, g.mname(m), "%s %d" % [ii("gold", 20), Cards.MERCS[m.id].bid], _merc_body(-1, m), C_MERC, 252, "mercs/" + m.id))
	market.add_child(f)
	market.add_child(_header("Item deck (%d left)" % g.item_deck.size()))
	market.add_child(_rich(fmt(", ".join(g.item_deck.map(func(it): return Cards.ITEMS[it].name))), 0, 14))

## A guild panel (both are always shown side by side). Clicking one shows that guild's team below.
func _render_guild(pi: int) -> PanelContainer:
	var p: Dictionary = g.players[pi]
	var gd: Dictionary = Cards.GUILDS[p.guild]
	var t := "%s\n" % res_table(pi)
	t += fmt("Night: +%d gold base income. %s" % [gd.income + (3 if g.has_keep(pi, "kraken") else 0), gd.text])
	var b := []
	for k in p.buildings:
		b.append("%s ×%d" % [Cards.BUILDINGS[k].name, p.buildings[k]])
	if not b.is_empty():
		t += "\n%s [b]Buildings:[/b] %s" % [ii("build"), ", ".join(b)]
	if not p.relics.is_empty():
		t += "\n%s [b]Relics:[/b] %s" % [ii("relic"), fmt("; ".join(p.relics.map(func(r): return "%s (%s)" % [Cards.ITEMS[r].name, Cards.ITEMS[r].text])))]
	if not p.stash.is_empty():
		t += "\n%s [b]Unequipped:[/b] %s" % [ii("equip"), fmt(", ".join(p.stash.map(func(r): return Cards.ITEMS[r].name)))]
	if not p.keeps.is_empty():
		t += "\n[b]Kept bonuses:[/b] " + fmt("; ".join(p.keeps.map(func(k): return Cards.KEEP_TEXT[k])))
	if not p.tiles.is_empty():
		t += "\n[b]Fame tiles:[/b] " + ", ".join(p.tiles.map(func(k): return Cards.TILES[k].name))
	if p.tokens.upgrade > 0 or p.tokens.wall > 0:
		t += "\n[b]Tokens:[/b] free upgrades %d, free stone walls %d" % [p.tokens.upgrade, p.tokens.wall]
	if p.legends > 0:
		t += "\nLegendary quests completed: %d" % p.legends
	var shown := pi == view_pi
	var title := "%s  [font_size=15][color=#aab]%s[/color]%s[/font_size]" % [_pname(pi), gd.name, "  [color=#ffd23f]★ priority[/color]" if g.priority == pi else ""]
	var pc := _card({"k": "guild", "pi": pi}, title, "", t, C_GUILD, 0, "guilds/" + p.guild)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = pc.get_theme_stylebox("panel")
	if shown:
		sb.border_color = Color("e8d9a8")
		sb.set_border_width_all(3)
		sb.bg_color = C_GUILD.darkened(0.5)
	if not shown:
		pc.tooltip_text = (pc.tooltip_text + "\n" if pc.tooltip_text != "" else "") + "Click: show this guild's mercenaries and locations"
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and view_pi != pi:
			view_pi = pi
			_mark_dirty())
	return pc

## The shown guild's team: mercenaries in two rows and locations in one row, each scrolling sideways.
func _render_team(pi: int) -> void:
	var p: Dictionary = g.players[pi]
	guild_box.add_child(_rich("[b]%s's team[/b]   [color=#aab][font_size=14]Click a guild above to see its team.[/font_size][/color]" % _pname(pi), 0, 18))
	var cards := []
	for m in p.mercs:
		cards.append(_card({"k": "merc", "pi": pi, "uid": m.uid}, g.mname(m), "Lv " + roman(g.level(m)), _merc_body(pi, m), C_MERC, TEAM_W, "mercs/" + m.id))
	guild_box.add_child(_header("Mercenaries (%d)%s" % [p.mercs.size(), "   ·   scroll sideways for more  →" if p.mercs.size() > 6 else ""]))
	guild_box.add_child(_strip(cards, 2, "m%d" % pi) if not cards.is_empty() else _rich("[i]none[/i]"))
	cards = []
	for l in p.locs:
		cards.append(_card({"k": "loc", "pi": pi, "lid": l.id}, g.lname(l.id), "Lv " + roman(l.level), _loc_body(l.id, pi), C_LOC, TEAM_W, "locs/" + l.id))
	guild_box.add_child(_header("Locations (%d)%s" % [p.locs.size(), "   ·   scroll sideways for more  →" if p.locs.size() > 3 else ""]))
	guild_box.add_child(_strip(cards, 1, "l%d" % pi) if not cards.is_empty() else _rich("[i]none[/i]"))

## Cards in a fixed number of rows (rows line up), scrolling sideways; keeps its scroll across refreshes.
## The mouse wheel still scrolls the board up and down; Shift+wheel or the scrollbar scrolls sideways.
func _strip(cards: Array, rows: int, key: String) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = ceili(cards.size() / float(rows))
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	for c in cards:
		grid.add_child(c)
	var keep: int = strip_scroll.get(key, 0)
	sc.get_h_scroll_bar().value_changed.connect(func(v): strip_scroll[key] = int(v))
	sc.ready.connect(func(): sc.set_deferred("scroll_horizontal", keep))
	sc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not ev.shift_pressed:
			if ev.pressed:
				var vs: VScrollBar = guild_box.get_parent().get_v_scroll_bar()
				vs.value += vs.page / 8.0 * ev.factor * (1 if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			sc.accept_event())
	return sc

func _rounds(tm: Array) -> String:
	if tm.is_empty():
		return "quest reward"
	if tm[0] <= 1 and tm[1] >= 99:
		return "any round"
	if tm[1] >= 99:
		return "rounds %d+" % tm[0]
	if tm[0] <= 1:
		return "until round %d" % tm[1]
	return "rounds %d-%d" % [tm[0], tm[1]]

func _order_line(pi: int, o: Dictionary, m: Dictionary) -> String:
	if o.is_empty() or not ORDER_ICON.has(o.get("t", "")):
		return ""
	var save: Dictionary = m.order
	m.order = o
	var s := g.order_text(pi, m)
	m.order = save
	return "\n[bgcolor=#3a3320][color=#ffd27f] %s %s [/color][/bgcolor]" % [ii(ORDER_ICON[o.t]), _esc(s)]

func _merc_body(pi: int, m: Dictionary) -> String:
	var d: Dictionary = Cards.MERCS[m.id]
	var lv := g.level(m)
	var s := g.stats(pi, m)
	var t := "[color=#aab]%s%s[/color]\n" % [d.role, "" if d.guild == "" else " · " + Cards.GUILDS[d.guild].name]
	t += "%s  Power [b]%d[/b]\n" % [chips(s), s[0] + s[1] + s[2]]
	t += "%s %d%s   wage %d %s\n" % [ii("xp"), m.xp, "" if lv == 3 else "/%d" % (3 if lv == 1 else 10), lv, ii("gold")]
	t += fmt(d.text[lv - 1])
	if not m.equip.is_empty():
		t += "\n" + ii("equip") + " " + fmt("; ".join(m.equip.map(func(e): return "%s: %s" % [Cards.ITEMS[e].name, Cards.ITEMS[e].text])))
	if m.perm != [0, 0, 0]:
		t += "\nPermanent: M+%d S+%d I+%d" % m.perm
	if pi < 0:
		if draft_bids.has("M%d" % m.uid) and mode in ["morning", "first_bid"]:
			t += "\n[bgcolor=#3a3320][color=#ffd27f] %s Your bid: %d [/color][/bgcolor]" % [ii("bid"), draft_bids["M%d" % m.uid]]
		return t
	if m.hired_today:
		t += "\n[i]Hired today: no order, no wage[/i]"
	elif mode == "morning" and pi == mode_pi:
		t += _order_line(pi, draft_orders.get(m.uid, {}), m)
		if not team.is_empty() and m.uid in team.sel:
			t += "\n[bgcolor=#2f5a2f][color=#c8ffc8][b] ✔ In the team for %s [/b][/color][/bgcolor]" % _esc(g.qname(team.q))
		if targeting.get("uid", -1) == m.uid:
			t += "\n[color=#ffd23f][b]Choosing a target…[/b][/color]"
	elif g.phase != "Morning":
		t += _order_line(pi, m.order, m)
	return t

func _loc_body(lid: String, pi: int) -> String:
	var d: Dictionary = Cards.LOCS[lid]
	var e := g.loc_entry(lid)
	var lv := g.loc_level(lid)
	var t := ""
	if d.guild != "":
		t += "[color=#aab]%s[/color]\n" % Cards.GUILDS[d.guild].name
	if pi < 0:
		t += "[color=#aab]%s[/color]\n" % _rounds(d.timing).capitalize()
	t += "%s [b]%d[/b]" % [ii("defense"), g.loc_defense(lid)]
	var wall := g.loc_wall(lid)
	if wall != "":
		t += "  (%s %s +%d)" % [ii("wall"), Cards.WALLS[wall].name, Cards.WALLS[wall].def]
	if pi < 0:
		t += "\n[color=#aab]Unowned: anyone may work here (1 mercenary per player), no owner bonus[/color]"
	t += "\n" + fmt(d.levels[lv - 1].text)
	if lv < 3:
		t += "\n%s [color=#aab]to Lv %s: %s[/color]" % [ii("upgrade", 16), roman(lv + 1), fmt(g.cost_str(d.levels[lv].up))]
	if pi < 0 and draft_bids.has("L" + lid) and mode == "morning":
		t += "\n[bgcolor=#3a3320][color=#ffd27f] %s Your bid: %d [/color][/bgcolor]" % [ii("bid"), draft_bids["L" + lid]]
	return t

func _quest_body(q: String) -> String:
	var d := g.qdef(q)
	var t := "[color=#aab]%s%s%s[/color]\n" % ["Legendary · " if not d.has("timing") else "", d.kind.capitalize(),
		"" if not d.has("timing") else " · " + _rounds(d.timing)]
	if d.guild != "":
		t = t.replace("[/color]\n", " · %s[/color]\n" % Cards.GUILDS[d.guild].name)
	return t + fmt(g.qsummary(q)).replace("Monster: ", ii("attack") + " ").replace("Reward:", "[b]Reward:[/b]").replace("Keep:", "[b]Keep:[/b]")

# ------------------------------------------------------------------ interactivity rules

func _bids_total(except := "") -> int:
	var t := 0
	for k in draft_bids:
		if k != except:
			t += draft_bids[k]
	return t

func _interactive(meta: Dictionary) -> bool:
	if g == null:
		return false
	var k: String = meta.get("k", "")
	if not team.is_empty():
		return k == "merc" and meta.pi == mode_pi
	if not targeting.is_empty():
		match targeting.t:
			"work":
				if k == "rowloc":
					for uid in draft_orders:
						var o: Dictionary = draft_orders[uid]
						if uid != targeting.uid and o.get("t", "") == "work" and o.get("loc", "") == meta.lid:
							return false   # 1 mercenary per player on an unowned location
				return k in ["loc", "rowloc"]
			"quest":
				return k in ["quest", "legend"] and _quest_lit(meta.q)
			"attack":
				return (k == "guild" and meta.pi != mode_pi) or (k == "rowloc" and _conquerable(meta.lid))
		return false
	var p: Dictionary = g.players[mode_pi] if mode_pi >= 0 else {}
	match mode:
		"morning":
			if k == "merc":
				return meta.pi == mode_pi
			if k in ["quest", "legend"]:
				return _quest_lit(meta.q)
			if k == "rowloc" and _conquerable(meta.lid):
				return true
			if k in ["rowmerc", "rowloc"]:
				var key: String = ("M%d" % meta.uid) if k == "rowmerc" else "L" + meta.lid
				return draft_bids.has(key) or p.gold - _bids_total() >= g.bid_min(key, mode_pi)
		"first_bid":
			if k == "rowmerc":
				return p.gold >= g.bid_min("M%d" % meta.uid) or g.players[mode_pi].gold > 0
		"build":
			if k == "loc" and meta.pi == mode_pi:
				return not _loc_actions(meta.lid).filter(func(a): return not a[2]).is_empty()
			if k == "guild" and meta.pi == mode_pi:
				return Cards.BUILDINGS.keys().any(func(b): return g.can_build(mode_pi, b))
			if k == "merc" and meta.pi == mode_pi:
				return not _equip_actions(meta.uid).filter(func(a): return not a[2]).is_empty()
	return false

# ------------------------------------------------------------------ clicks and popups

## A quest lights up when some team of the current player's mercenaries could complete it.
func _quest_lit(q: String) -> bool:
	return mode_pi >= 0 and not g.quest_feasible(mode_pi, q, g.players[mode_pi].mercs.filter(func(m): return not m.hired_today)).is_empty()

## A location for sale lights up when the current player's mercenaries together could conquer it.
func _conquerable(lid: String) -> bool:
	if mode_pi < 0 or not lid in g.loc_row:
		return false
	var grp: Array = g.players[mode_pi].mercs.filter(func(m): return not m.hired_today)
	if grp.is_empty():
		return false
	var wm := 0
	for m in grp:
		wm += g.block_sum(mode_pi, m, "attack", "wall", {"group": grp})
	return g.attack_power(mode_pi, grp) > g.loc_defense(lid, wm, wm >= 99)

func _start_team(q: String, extra := -1) -> void:
	var sel := []
	for uid in draft_orders:
		if draft_orders[uid].get("t", "") == "quest" and draft_orders[uid].get("q", "") == q:
			sel.append(uid)
	if extra >= 0 and not extra in sel:
		sel.append(extra)
	targeting = {}
	team = {"q": q, "sel": sel}
	_refresh()

func _team_problems() -> Array:
	var group: Array = team.sel.map(func(uid): return g.find_merc(mode_pi, uid))
	return g.quest_problems(mode_pi, team.q, group)

func _confirm_team() -> void:
	if not _team_problems().is_empty():
		return
	for uid in draft_orders:
		if draft_orders[uid].get("t", "") == "quest" and draft_orders[uid].get("q", "") == team.q and not uid in team.sel:
			draft_orders[uid] = {"t": "defend"}
	for uid in team.sel:
		draft_orders[uid] = {"t": "quest", "q": team.q}
	team = {}
	_refresh()

func _on_card(meta: Dictionary) -> void:
	if not team.is_empty():
		if meta.get("k", "") == "merc":
			if meta.uid in team.sel:
				team.sel.erase(meta.uid)
			else:
				team.sel.append(meta.uid)
			_refresh()
		return
	if not targeting.is_empty() and targeting.t == "quest":
		_start_team(meta.q, targeting.uid)
		return
	if mode == "morning" and meta.get("k", "") in ["quest", "legend"]:
		_start_team(meta.q)
		return
	if not targeting.is_empty():
		var o := {"t": targeting.t}
		match targeting.t:
			"work":
				o["loc"] = meta.lid
			"quest":
				o["q"] = meta.q
			"attack":
				o["target"] = ("P%d" % meta.pi) if meta.k == "guild" else "L" + meta.lid
		draft_orders[targeting.uid] = o
		targeting = {}
		_refresh()
		return
	match mode:
		"morning":
			if meta.k == "merc":
				_order_menu(meta.uid)
			else:
				_bid_popup(("M%d" % meta.uid) if meta.k == "rowmerc" else "L" + meta.lid)
		"first_bid":
			_bid_popup("M%d" % meta.uid)
		"build":
			match meta.k:
				"loc":
					_action_menu(_loc_actions(meta.lid))
				"guild":
					_action_menu(_building_actions())
				"merc":
					_action_menu(_equip_actions(meta.uid))

func _place(p: Window) -> void:
	add_child(p)
	p.popup_hide.connect(func(): p.queue_free())
	p.reset_size()
	var pos := get_global_mouse_position()
	var vs := get_viewport_rect().size
	pos.x = min(pos.x, vs.x - p.size.x - 8)
	pos.y = min(pos.y, vs.y - p.size.y - 8)
	p.position = Vector2i(pos)
	p.popup()

## actions: [[icon, label, disabled, callable], ...]
func _action_menu(actions: Array) -> void:
	var pm := PopupMenu.new()
	pm.add_theme_font_size_override("font_size", 17)
	pm.add_theme_constant_override("icon_max_width", 24)
	for i in actions.size():
		var a: Array = actions[i]
		pm.add_icon_item(icon(a[0]), a[1], i)
		pm.set_item_disabled(i, a[2])
	pm.id_pressed.connect(func(id: int):
		actions[id][3].call()
		_refresh())
	_place(pm)

func _order_menu(uid: int) -> void:
	var m := g.find_merc(mode_pi, uid)
	var act = Cards.abil_text(g.blocks(m, "activate")) if g.can_activate(m) else null
	var has_quests := not (g.quest_row + g.legends).is_empty()
	_action_menu([
		["work", "Work at a location…  (then click the location)", false, func(): targeting = {"uid": uid, "t": "work"}],
		["activate", act if act != null else "Activate (this mercenary has no Activate ability)", act == null,
			func(): draft_orders[uid] = {"t": "act"}],
		["quest", "Go on a quest…  (then click a lit quest and pick the team)", not has_quests, func(): targeting = {"uid": uid, "t": "quest"}],
		["attack", "Attack…  (then click a rival guild or a location for sale)", false, func(): targeting = {"uid": uid, "t": "attack"}],
		["defend", "Defend (stay in the garrison)", false, func(): draft_orders[uid] = {"t": "defend"}],
	])

func _bid_popup(key: String) -> void:
	var p: Dictionary = g.players[mode_pi]
	var mn := g.bid_min(key, mode_pi)
	var others := 0 if mode == "first_bid" else _bids_total(key)
	var avail: int = p.gold - others
	var pp := PopupPanel.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pp.add_child(v)
	var info := _rich("%s [b]Bid on %s[/b]\nMinimum %d %s. You have %d %s%s." % [ii("bid"), g.bid_name(key), mn, ii("gold"), p.gold, ii("gold"),
		"" if others == 0 else ", %d already bid elsewhere" % others], 360, 16)
	v.add_child(info)
	if key.begins_with("L") and _conquerable(key.substr(1)):
		v.add_child(_rich("%s Or conquer it: click your mercenaries, choose Attack, then click this location." % ii("attack"), 360, 15))
	var row := HBoxContainer.new()
	v.add_child(row)
	var spin := _spin(mn, avail, draft_bids.get(key, mn))
	row.add_child(spin)
	row.add_child(_btn("Place bid", func():
		if mode == "first_bid":
			draft_bids = {}
		draft_bids[key] = int(spin.value)
		pp.hide()
		_refresh(), avail < mn, "bid"))
	if draft_bids.has(key):
		row.add_child(_btn("Remove bid", func():
			draft_bids.erase(key)
			pp.hide()
			_refresh()))
	row.add_child(_btn("Cancel", func(): pp.hide()))
	_place(pp)

func _loc_actions(lid: String) -> Array:
	var pi := mode_pi
	var p: Dictionary = g.players[pi]
	var e := g.loc_entry(lid)
	var out := []
	if e.level < 3:
		var c := g.upgrade_cost(pi, lid)
		out.append(["upgrade", "Upgrade to level %s  (%s)" % [roman(e.level + 1), g.cost_str(c)], not g.can_pay(pi, c), func(): _act("do_upgrade", [pi, lid])])
		if p.tokens.upgrade > 0:
			out.append(["upgrade", "Upgrade to level %s for FREE (Master Builders)" % roman(e.level + 1), false, func(): _act("do_upgrade", [pi, lid, true])])
	else:
		out.append(["upgrade", "Already at level III", true, func(): pass])
	for wid in Cards.WALLS:
		var w: String = wid
		if e.wall == "" or Cards.WALLS[e.wall].def < Cards.WALLS[w].def:
			var c := g.wall_cost(pi, w)
			out.append(["wall", "Build %s: +%d defense  (%s)" % [Cards.WALLS[w].name, Cards.WALLS[w].def, g.cost_str(c)], not g.can_pay(pi, c), func(): _act("do_wall", [pi, lid, w])])
			if w == "stone" and p.tokens.wall > 0:
				out.append(["wall", "Build Stone Wall for FREE (Royal Engineers)", false, func(): _act("do_wall", [pi, lid, w, true])])
	return out

func _building_actions() -> Array:
	var pi := mode_pi
	var out := []
	for bid in Cards.BUILDINGS:
		var bd: Dictionary = Cards.BUILDINGS[bid]
		if bd.guild != "" and bd.guild != g.players[pi].guild:
			continue
		var k: String = bid
		out.append(["build", "%s  (%s): %s" % [bd.name, g.cost_str(bd.cost), bd.get("text", "Night: +1 " + bd.prod)], not g.can_build(pi, k), func(): _act("do_build", [pi, k])])
	return out

func _equip_actions(uid: int) -> Array:
	var pi := mode_pi
	var p: Dictionary = g.players[pi]
	var m := g.find_merc(pi, uid)
	var out := []
	for it in p.stash:
		var item: String = it
		out.append(["equip", "Equip %s: %s" % [Cards.ITEMS[it].name, Cards.ITEMS[it].text], m.equip.size() >= g.slots(m), func(): _act("do_equip", [pi, item, uid])])
	for it in m.equip:
		var item: String = it
		out.append(["equip", "Unequip %s" % Cards.ITEMS[it].name, false, func(): _act("do_unequip", [pi, uid, item])])
	return out

# ------------------------------------------------------------------ requests from the engine

func _humans() -> int:
	return g.bots.count(false)

func _on_need(r: Dictionary) -> void:
	mode = ""
	targeting = {}
	_clear(bar)
	_refresh()
	var pi: int = r.player
	if net:
		if net.is_host:
			waiting_guest = pi != me
			_sync()
			net.send({"t": "req", "r": r})
		if pi == me:
			_begin(r)
		else:
			_waiting(r)
		return
	if r.kind in ["morning", "first_bid"] and _humans() > 1:
		cover_label.text = "Pass the device to %s\n(secret: %s)" % [g.players[pi].name, "Morning orders and bids" if r.kind == "morning" else "first hire bid"]
		cover.visible = true
		for c in cover_btn.pressed.get_connections():
			cover_btn.pressed.disconnect(c.callable)
		cover_btn.pressed.connect(func():
			cover.visible = false
			_begin(r), CONNECT_ONE_SHOT)
	else:
		_begin(r)

func _begin(r: Dictionary) -> void:
	req = r
	mode_pi = r.player
	if r.kind in ["morning", "build"]:
		view_pi = r.player   # your own team, where your orders and builds happen
	draft_bids = {}
	draft_orders = {}
	match r.kind:
		"morning":
			mode = "morning"
			for m in g.players[mode_pi].mercs:
				draft_orders[m.uid] = {"t": "defend"}
			_refresh()
		"first_bid", "build":
			mode = r.kind
			_refresh()
		_:
			mode = ""
			_refresh()
			_build_request(r)

func _answer(a) -> void:
	mode = ""
	targeting = {}
	team = {}
	primary_btn = null
	_clear(bar)
	if net and not net.is_host:
		net.send({"t": "answer", "a": a})
		bar.add_child(_rich("[i]Sent. Waiting for the game to go on…[/i]"))
		return
	g.call_deferred("provide", a)

func _render_mode_bar() -> void:
	_clear(bar)
	primary_btn = null
	var pi := mode_pi
	var p: Dictionary = g.players[pi]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	match mode:
		"morning":
			if not team.is_empty():
				var why := _team_problems()
				var qd := g.qdef(team.q)
				bar.add_child(_rich("%s · Team for [b]%s[/b]: click your mercenaries to add or remove them.  %s" % [_pname(pi), _esc(g.qname(team.q)),
					fmt(g.qsummary(team.q).get_slice("\n", 0))], 0, 17))
				var group: Array = team.sel.map(func(uid): return g.find_merc(pi, uid))
				var status := "[color=#7fe0a0][b]Ready: this team completes the quest.[/b][/color]" if why.is_empty() else "[color=#ff7a6f]Not yet: %s[/color]" % ", ".join(why)
				if qd.kind == "monster" and not group.is_empty():
					status = "Power [b]%d[/b] / %d   " % [g.quest_power(pi, group, team.q), qd.power] + status
				bar.add_child(_rich(status, 0, 16))
				primary_btn = _btn("Confirm team", _confirm_team, not why.is_empty(), "quest")
				row.add_child(primary_btn)
				row.add_child(_btn("Cancel", func():
					team = {}
					_refresh()))
			elif not targeting.is_empty():
				var m := g.find_merc(pi, targeting.uid)
				bar.add_child(_rich("%s: [b]%s[/b] %s. The highlighted cards are valid targets." % [_pname(pi), g.mname(m),
					{"work": "works where? Click a location", "quest": "goes on which quest? Click a quest", "attack": "attacks what? Click a rival guild or a location for sale"}[targeting.t]], 0, 17))
				row.add_child(_btn("Cancel", func():
					targeting = {}
					_refresh()))
			else:
				bar.add_child(_rich("%s · [b]Morning (secret)[/b]: click each of your mercenaries to give an order, and click market mercenaries or locations to bid. Bids: [b]%d[/b] of your %d %s." % [_pname(pi), _bids_total(), p.gold, ii("gold")], 0, 17))
				var parts := []
				for m in p.mercs:
					var o: Dictionary = draft_orders.get(m.uid, {})
					if ORDER_ICON.has(o.get("t", "")):
						parts.append("%s %s" % [ii(ORDER_ICON[o.t]), g.mname(m)])
				for k in draft_bids:
					parts.append("%s %s %d" % [ii("bid"), _esc(g.bid_name(k)), draft_bids[k]])
				if not parts.is_empty():
					bar.add_child(_rich("  ·  ".join(parts), 0, 15))
				row.add_child(_btn("Pass (no orders, no bids)", func():
					var none := {}
					for m in p.mercs:
						none[m.uid] = {"t": "none"}
					_answer({"orders": none, "bids": {}})))
				primary_btn = _btn("Confirm orders and bids", func():
					if _bids_total() > p.gold:
						return
					_answer({"orders": draft_orders.duplicate(), "bids": draft_bids.duplicate()}), _bids_total() > p.gold)
				row.add_child(primary_btn)
		"first_bid":
			bar.add_child(_rich("%s · [b]Round 1 (secret)[/b]: click one mercenary for hire and place a bid (at least its cost). You have %d %s." % [_pname(pi), p.gold, ii("gold")], 0, 17))
			var has_bid := not draft_bids.is_empty()
			if has_bid:
				var k: String = draft_bids.keys()[0]
				bar.add_child(_rich("Your bid: %s %s %d" % [ii("bid"), _esc(g.bid_name(k)), draft_bids[k]], 0, 15))
			primary_btn = _btn("Confirm bid", func():
				var k: String = draft_bids.keys()[0]
				_answer({"uid": int(k.substr(1)), "amount": draft_bids[k]}), not has_bid)
			row.add_child(primary_btn)
		"build":
			bar.add_child(_rich("%s · [b]Build[/b]: click your locations to upgrade or wall them, your guild panel to construct buildings, your mercenaries to move equipment.   %s%s" % [_pname(pi), res_line(p),
				"   ·  Mira discount active" if p.today.mira_all or p.today.mira_next else ""], 0, 17))
			primary_btn = _btn("Done building", func(): _answer(null))
			row.add_child(primary_btn)
	bar.add_child(row)

## Generic requests (open decisions at Noon, Evening and Night) stay in the bottom bar.
func _build_request(r: Dictionary) -> void:
	_clear(bar)
	var pi: int = r.player
	bar.add_child(_rich("%s: %s" % [_pname(pi), fmt(r.prompt)], 0, 17))
	match r.kind:
		"pick":
			var f := _flow()
			for i in r.options.size():
				var idx: int = i
				f.add_child(_btn(r.options[i], func(): _answer(idx)))
			bar.add_child(f)
		"amounts":
			var row := HBoxContainer.new()
			bar.add_child(row)
			var spins := {}
			for fd in r.fields:
				var l := _rich("%s max %d" % [ii(fd.key) if fd.key in Game.RES else fd.label, fd.max], 90, 16)
				row.add_child(l)
				var s := _spin(fd.min, fd.max, fd.min)
				row.add_child(s)
				spins[fd.key] = s
			var warn := Label.new()
			warn.add_theme_color_override("font_color", Color("ff8a80"))
			row.add_child(_btn(r.get("ok_label", "OK"), func():
				var a := {}
				var tot := 0
				for k in spins:
					a[k] = int(spins[k].value)
					tot += a[k]
				if r.has("total_max") and tot > r.total_max:
					warn.text = "Total can't exceed %d." % r.total_max
					return
				_answer(a)))
			if r.get("can_cancel", false):
				row.add_child(_btn(r.get("cancel_label", "Cancel"), func(): _answer(null)))
			bar.add_child(warn)

# ------------------------------------------------------------------ online play (web build)

var my_name := ""
var room_code := ""
var waiting_guest := false   # host: the pending request is the guest's

func _online_setup_row() -> void:
	bar.add_child(_header("Play online with a friend, each on their own computer"))
	var row := HBoxContainer.new()
	bar.add_child(row)
	var nm := LineEdit.new()
	nm.placeholder_text = "Your name"
	nm.custom_minimum_size = Vector2(200, 0)
	row.add_child(nm)
	row.add_child(_btn("Host a game", func(): _go_online(nm.text, ""), false, "fame"))
	var sl := Label.new()
	sl.text = "   or join a friend's game:"
	row.add_child(sl)
	var code := LineEdit.new()
	code.placeholder_text = "Room code"
	code.text = Online.url_room()
	code.custom_minimum_size = Vector2(140, 0)
	row.add_child(code)
	row.add_child(_btn("Join", func(): _go_online(nm.text, code.text), false, "quest"))

func _go_online(nm: String, code: String) -> void:
	code = code.strip_edges().to_upper()
	my_name = nm.strip_edges().substr(0, 24)
	if my_name == "":
		my_name = "Host" if code == "" else "Guest"
	net = Online.new(net_js)
	net.message.connect(_on_net)
	net.status.connect(_on_net_status)
	_clear(bar)
	if code == "":
		me = 0
		bar.add_child(_rich("Opening a room…", 0, 17))
		net.host()
	else:
		me = 1
		room_code = code
		bar.add_child(_rich("Joining room [b]%s[/b]…" % _esc(code), 0, 17))
		net.join(code)

func _on_net_status(s: String) -> void:
	if net == null:
		return
	if s.begins_with("code:"):
		room_code = s.substr(5)
		if g == null:
			_clear(bar)
			var link := Online.invite_link(room_code)
			bar.add_child(_header("Room code:  %s" % room_code))
			bar.add_child(_rich("Send your friend this invite link: [b]%s[/b]\nThey open it, type their name and press [b]Join[/b] (the code is already filled in). The game starts as soon as they join." % _esc(link), 0, 17))
			var row := HBoxContainer.new()
			bar.add_child(row)
			var done := Label.new()
			done.add_theme_color_override("font_color", Color("7fe0a0"))
			row.add_child(_btn("Copy invite link", func():
				Online.copy(link)
				done.text = "  Invite link copied: paste it to your friend."))
			row.add_child(_btn("Copy code only", func():
				Online.copy(room_code)
				done.text = "  Code copied."))
			row.add_child(_btn("Cancel", _show_setup))
			row.add_child(done)
	elif s == "connected":
		if not net.is_host:
			net.send({"t": "hello", "name": my_name})
	elif s == "closed":
		if net.is_host:
			log_box.append_text("\n[color=#ff8a80][b]Your friend is disconnected. They can rejoin with room code %s.[/b][/color]\n" % room_code)
		else:
			mode = ""
			targeting = {}
			team = {}
			_clear(bar)
			bar.add_child(_rich("[color=#ff8a80][b]Connection to the host lost.[/b][/color] The game goes on as long as the host keeps their page open.", 0, 17))
			bar.add_child(_btn("Rejoin room %s" % room_code, func():
				_clear(bar)
				bar.add_child(_rich("Rejoining…"))
				net.join(room_code)))
	elif s.begins_with("error:"):
		_clear(bar)
		bar.add_child(_rich("[color=#ff8a80][b]Online play problem:[/b][/color] %s" % _esc(s.substr(6)), 0, 17))
		bar.add_child(_btn("Back", _show_setup))

func _on_net(d: Dictionary) -> void:
	if net.is_host:
		match d.get("t", ""):
			"hello":
				var guest := str(d.get("name", "Guest")).strip_edges().substr(0, 24)
				net.send({"t": "start", "edits": Cards.current_edits(), "me": 1})
				log_sent = 0
				if g == null:
					_new_game([my_name, guest if guest != "" else "Guest"], [false, false], 0)
				else:   # the guest rejoined: send everything again
					_sync()
					if not g.pending.is_empty():
						net.send({"t": "req", "r": g.pending})
			"answer":
				if waiting_guest and not g.pending.is_empty():
					waiting_guest = false
					g.call_deferred("provide", Online.sanitize(g.pending, d.get("a")))
			"act":
				var fn = d.get("fn")
				var args = d.get("args")
				if waiting_guest and g.pending.get("kind", "") == "build" and fn in Online.BUILD_FNS and args is Array and not args.is_empty():
					args[0] = 1 - me
					g.callv(fn, args)
			"end":
				if g and not g.game_over:
					g.end_game()
					_show_game_over()
		return
	match d.get("t", ""):
		"start":
			if d.get("edits") is Dictionary:
				Cards.apply_edits(d.edits)
				_init_format()
			me = int(d.get("me", 1))
			g = Game.new()
			log_box.clear()
			_clear(bar)
			bar.add_child(_rich("Connected. Waiting for the host…", 0, 17))
		"state":
			if g == null:
				return
			var fresh := Online.apply(g, d)
			if int(d.get("log_from", 0)) == 0:
				log_box.clear()
			for l in fresh:
				_on_log(l)
			if g.game_over:
				_show_game_over()
			else:
				_refresh()
		"req":
			if g != null and d.get("r") is Dictionary:
				_on_need(d.r)

## Shown while the other player decides.
func _waiting(r: Dictionary) -> void:
	mode = ""
	targeting = {}
	team = {}
	_clear(bar)
	_refresh()
	var what: String = {"morning": "is giving secret orders and placing bids", "first_bid": "is placing a secret bid on a mercenary",
		"build": "is building"}.get(r.kind, "is deciding: " + fmt(r.prompt))
	bar.add_child(_rich("[i]Waiting:[/i] %s %s…" % [_pname(r.player), what], 0, 17))

## Host: send the board to the guest (only the log lines it hasn't had yet).
func _sync() -> void:
	sync_queued = false
	if net and net.is_host and g:
		net.send(Online.snapshot(g, log_sent))
		log_sent = g.log_lines.size()

## Build actions: the host runs them; the guest sends them to the host.
func _act(fn: String, args: Array) -> void:
	if net and not net.is_host:
		net.send({"t": "act", "fn": fn, "args": args})
	else:
		g.callv(fn, args)

# ------------------------------------------------------------------ card editor

func _open_editor() -> void:
	var ed: Control = preload("res://src/scenes/editor/editor.gd").new()
	ed.ui = self
	if g == null:
		g = Game.new()   # bare rules object: card bodies call its lookup helpers
		ed.temp_game = true
	add_child(ed)
	ed.closed.connect(func():
		if ed.temp_game:
			g = null
		_init_format())

func _open_rules() -> void:
	var rb: Control = preload("res://src/scenes/rules/rulebook.gd").new()
	rb.ui = self
	add_child(rb)

## Space: the main button of the current step (confirm orders, confirm team, confirm bid, done building),
## or "I'm ready" on the hand-over screen. Ignored while typing in a text field.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if cover.visible:
		cover_btn.pressed.emit()
	elif primary_btn and is_instance_valid(primary_btn) and primary_btn.is_visible_in_tree() and not primary_btn.disabled:
		primary_btn.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
