extends Control
## In-game card editor (opened from "Editor" on the setup screen). One tab per card table in
## Cards; each card can be edited, duplicated, deleted or restored to its default. Every change
## is saved at once as a diff against the defaults (Cards.save_edits), and loaded at start-up.
## Card text is what players read; the rules use the numbers and the "rules data" fields.

signal closed

const TABS := [
	["MERCS", "Mercenaries"], ["GUILDS", "Guilds"], ["ITEMS", "Items"], ["LOCS", "Locations"], ["QUESTS", "Quests"],
	["LEGENDS", "Legendary quests"], ["BUILDINGS", "Buildings"], ["WALLS", "Walls"], ["TILES", "Fame track"],
	["KEEP_TEXT", "Kept bonuses"], ["RULES", "Rules numbers"]]
const HINTS := {
	"MERCS": "Stats are [Might, Skill, Intellect] per level and should total 3 / 5 / 7. Level 2 at 3 XP, level 3 at 10 XP. Wage = 1 gold per level.",
	"GUILDS": "Starting gold, gold per Night and the guild power text.",
	"ITEMS": "Kind is equip (1 per mercenary) or relic (guild-wide). Value is used when a location searches the deck.",
	"LOCS": "Rounds [first, last] (99 = no end; empty = quest reward only). Min bid is before wall surcharges. Defense comes from Rules numbers.",
	"QUESTS": "Rounds [first, last] (99 = no end). Stat needs use 0 = Might, 1 = Skill, 2 = Intellect. XP is given to each mercenary sent.",
	"LEGENDS": "Legendary quests are always available. The game ends when all are completed.",
	"BUILDINGS": "Produces: gold, wood, stone or metal each Night (empty = special effect in the rules).",
	"WALLS": "One wall per location; a stronger wall replaces a weaker one.",
	"TILES": "One tile is placed on each fame space (see Rules numbers). The effect of each tile is coded by its id.",
	"KEEP_TEXT": "Text of the bonuses you keep from quests. The effect is coded by its id.",
	"RULES": "Location defense by level, the walls given to restocked locations, and the fame track spaces.",
}
const LABELS := {
	"name": "Name", "role": "Role", "guild": "Guild", "bid": "Min bid", "stats": "Stats per level (Might, Skill, Intellect)",
	"abil": "Abilities per level (rules data)", "text": "Card text", "start": "Starting gold", "income": "Gold per Night",
	"timing": "Rounds (first, last)", "levels": "Levels", "up": "Upgrade cost", "w": "Work effect (rules data)",
	"owner": "Owner bonus", "kind": "Kind", "value": "Value", "power": "Power", "need": "Stat needs (0 M, 1 S, 2 I)",
	"pay": "Pays", "reward": "Reward", "cost": "Cost", "prod": "Produces", "def": "Defense",
	"loc_def": "Location defense by level", "restock_walls": "Walls on restocked locations, in order",
	"fame_spaces": "Fame track spaces", "item": "Item (id)", "loc": "Location (id)", "base": "Base production (when worked)", "min_mercs": "At least N mercenaries", "max_mercs": "At most N mercenaries (0 = no limit)", "loc_discount": "Location bid discount", "keep": "Kept bonus (id)", "xp": "XP shared by the team",
	"k": "Kind", "div": "Divide by", "res": "Resource", "stat": "Stat (0 M, 1 S, 2 I, 3 highest)", "mult": "Multiplier",
	"plus": "Plus", "min": "Minimum", "scope": "Scope",
}
const GUILD_OPTS := [["", "Generalist"], ["GL", "Golden Ledger"], ["IW", "Iron Wolves"]]
const ROUNDS := 12

var ui            # main.gd
var temp_game := false
var tab := "MERCS"
var query := ""
var faction := "all"
var pending_delete := ""
var tab_btns := {}
var grid: HFlowContainer
var supply: RichTextLabel
var hint: Label
var status: Label
var faction_opt: OptionButton
var dialog: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("17191e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title: RichTextLabel = ui._rich("[font_size=26][b]GuildMasters Card Editor[/b][/font_size]\n[color=#aab]Every card and table the game uses. Changes are saved at once to %s and used by the next game.[/color]" % Cards.edits_path(), 0, 15)
	top.add_child(title)
	top.add_child(ui._btn("Add card", _add, false, "build"))
	top.add_child(ui._btn("Export edits", _export))
	top.add_child(ui._btn("Import edits", _import))
	top.add_child(ui._btn("Reset all edits", _reset_all))
	top.add_child(ui._btn("Back", func():
		closed.emit()
		queue_free()))
	var tabs := HFlowContainer.new()
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t[0] == tab
		b.pressed.connect(func():
			tab = t[0]
			pending_delete = ""
			_render())
		tabs.add_child(b)
		tab_btns[t[0]] = b
	root.add_child(tabs)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var search := LineEdit.new()
	search.placeholder_text = "Search names and effects"
	search.custom_minimum_size = Vector2(320, 0)
	search.text_changed.connect(func(t):
		query = t.to_lower()
		_render())
	bar.add_child(search)
	faction_opt = OptionButton.new()
	for o in ["All guilds", "Golden Ledger", "Iron Wolves", "Generalist"]:
		faction_opt.add_item(o)
	faction_opt.item_selected.connect(func(i):
		faction = ["all", "GL", "IW", ""][i]
		_render())
	bar.add_child(faction_opt)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color("aab0c0"))
	bar.add_child(hint)
	status = Label.new()
	status.add_theme_color_override("font_color", Color("ffd27f"))
	root.add_child(status)
	supply = ui._rich("", 0, 14)
	root.add_child(supply)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	grid = ui._flow()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	_render()

# ------------------------------------------------------------------ grid

func _render() -> void:
	ui._hide_preview()
	tab_btns[tab].button_pressed = true
	for t in TABS:
		tab_btns[t[0]].text = "%s (%d)" % [t[1], Cards.table(t[0]).size()]
	hint.text = HINTS[tab]
	faction_opt.visible = tab in ["MERCS", "ITEMS", "LOCS", "QUESTS", "LEGENDS", "BUILDINGS"]
	_render_supply()
	ui._clear(grid)
	var tb := Cards.table(tab)
	var ids := tb.keys()
	if tab == "MERCS" or tab == "LOCS":
		ids.sort_custom(func(a, b): return [tb[a].bid, tb[a].name] < [tb[b].bid, tb[b].name])
	elif tab == "QUESTS":
		ids.sort_custom(func(a, b): return [tb[a].timing[0], tb[a].timing[1], tb[a].name] < [tb[b].timing[0], tb[b].timing[1], tb[b].name])
	for id in ids:
		var e = tb[id]
		if query != "" and not (id + var_to_str(e)).to_lower().contains(query):
			continue
		if faction_opt.visible and faction != "all" and (e.get("guild", "") if e is Dictionary else "") != faction:
			continue
		grid.add_child(_cell(id))
	if grid.get_child_count() == 0:
		grid.add_child(ui._rich("[i]No cards %s.[/i]" % ("match your search" if query != "" else "yet")))

func _cell(id: String) -> Control:
	var v := VBoxContainer.new()
	v.add_child(_card_view(tab, id))
	var e = Cards.table(tab)[id]
	if tab == "MERCS":
		var bad := []
		for i in 3:
			var s: Array = e.stats[i]
			if s[0] + s[1] + s[2] != [3, 5, 7][i]:
				bad.append(ui.roman(i + 1))
		if not bad.is_empty():
			v.add_child(ui._rich("[color=#ff7a6f][b]Stat totals should be 3 / 5 / 7 (level %s)[/b][/color]" % ", ".join(bad), 290, 13))
	var foot := HBoxContainer.new()
	if pending_delete == id:
		foot.add_child(ui._rich("Delete this card?", 0, 14))
		foot.add_child(ui._btn("Delete", func(): _delete(id)))
		foot.add_child(ui._btn("Keep", func():
			pending_delete = ""
			_render()))
	else:
		foot.add_child(ui._btn("Edit", func(): _open_form(id, Cards.table(tab)[id], false)))
		if tab != "RULES":
			foot.add_child(ui._btn("Duplicate", func(): _open_form(id, Cards.table(tab)[id], true)))
			foot.add_child(ui._btn("Delete", func():
				pending_delete = id
				_render()))
		var d = Cards.default_of(tab, id)
		if d == null or var_to_str(d) != var_to_str(e):
			var tag: RichTextLabel = ui._rich("[color=#ffd27f]%s[/color]" % ("new" if d == null else "edited"), 50, 13)
			foot.add_child(tag)
			if d != null:
				foot.add_child(ui._btn("Restore", func():
					Cards.table(tab)[id] = d.duplicate(true) if d is Dictionary else d
					_saved("Restored %s to its default." % _title(tab, id))))
	v.add_child(foot)
	return v

func _title(t: String, id: String) -> String:
	var e = Cards.table(t)[id]
	return str(e.get("name", id)) if e is Dictionary else id.capitalize()

func _res(c: Dictionary) -> String:
	return ui.fmt(ui.g.cost_str(c))

## The card as shown in the editor: every level at once.
func _card_view(t: String, id: String) -> Control:
	var e = Cards.table(t)[id]
	var meta := {"k": "ed"}
	var gname := func(k): return "" if k == "" else Cards.GUILDS[k].name if Cards.GUILDS.has(k) else k
	match t:
		"MERCS":
			var b := "[color=#aab]%s%s[/color]" % [e.role, "" if e.guild == "" else " · " + gname.call(e.guild)]
			for i in 3:
				var s: Array = e.stats[i]
				b += "\n[b]Lv %s[/b] [color=#aab](%d XP, wage %d)[/color]\n%s\n%s" % [ui.roman(i + 1), [0, 3, 10][i], i + 1, ui.chips(s), ui.fmt(e.text[i])]
			return ui._card(meta, e.name, "%s %d" % [ui.ii("gold", 20), e.bid], b, ui.C_MERC, 290)
		"GUILDS":
			return ui._card(meta, e.name, "", ui.fmt("Start: %d gold\nNight: +%d gold\n%s" % [e.start, e.income, e.text]), ui.C_GUILD, 290)
		"ITEMS":
			var b := "[color=#aab]%s · value %d[/color]" % ["Equipment" if e.kind == "equip" else "Relic", e.value]
			if e.get("stats", [0, 0, 0]) != [0, 0, 0]:
				b += "\n" + ui.chips(e.stats)
			return ui._card(meta, e.name, ui.ii("equip" if e.kind == "equip" else "relic", 20), b + "\n" + ui.fmt(e.text), ui.C_ITEM, 290)
		"LOCS":
			var b := "[color=#aab]%s%s[/color]" % [gname.call(e.guild) + " · " if e.guild != "" else "", ui._rounds(e.timing).capitalize()]
			for i in e.levels.size():
				var L: Dictionary = e.levels[i]
				b += "\n[b]Lv %s[/b]  %s %d" % [ui.roman(i + 1), ui.ii("defense"), Cards.LOC_DEF[min(i, Cards.LOC_DEF.size() - 1)]]
				if L.has("up"):
					b += "  %s %s" % [ui.ii("upgrade", 16), _res(L.up)]
				b += "\n" + ui.fmt(L.text)
			return ui._card(meta, e.name, ("%s %d" % [ui.ii("gold", 20), e.bid]) if not e.timing.is_empty() else "", b, ui.C_LOC, 290)
		"QUESTS", "LEGENDS":
			return ui._card(meta, e.name, "", ui._quest_body(id), ui.C_LEGEND if t == "LEGENDS" else ui.C_QUEST, 290)
		"BUILDINGS":
			var b := "[color=#aab]%s[/color]\nCost: %s" % ["Any guild" if e.guild == "" else gname.call(e.guild) + " only", _res(e.cost)]
			if e.prod != "":
				b += "\n" + ui.fmt("Night: +1 %s" % e.prod)
			if e.has("text"):
				b += "\n" + ui.fmt(e.text)
			return ui._card(meta, e.name, ui.ii("build", 20), b, ui.C_GUILD, 290)
		"WALLS":
			return ui._card(meta, e.name, ui.ii("wall", 20), "%s [b]+%d[/b]\nCost: %s" % [ui.ii("defense"), e.def, _res(e.cost)], ui.C_LOC, 290)
		"TILES":
			return ui._card(meta, e.name, ui.ii("fame", 20), ui.fmt(e.text), Color("1f6f78"), 290)
		"KEEP_TEXT":
			return ui._card(meta, id.capitalize(), "", ui.fmt(e), ui.C_LEGEND, 290)
	return ui._card(meta, e.name, "", "Location defense by level: %s\nWalls on restocked locations: none ×players, then %s\nFame track spaces: %s" % [
		", ".join(e.loc_def.map(str)), ", then ".join(e.restock_walls), ", ".join(e.fame_spaces.map(str))], Color("6b6f7a"), 0)

func _render_supply() -> void:
	supply.visible = tab in ["QUESTS", "LOCS"]
	if not supply.visible:
		return
	var t := "[b]Cards available each round[/b] [color=#aab](a 2-player row needs at least 2; red means fewer)[/color]\n[table=%d][cell]Round  [/cell]" % (ROUNDS + 1)
	for r in range(1, ROUNDS + 1):
		t += "[cell][center] %d [/center][/cell]" % r
	for row in [["Quests", Cards.QUESTS], ["Locations", Cards.LOCS]]:
		t += "[cell]%s  [/cell]" % row[0]
		for r in range(1, ROUNDS + 1):
			var k := 0
			for id in row[1]:
				var tm: Array = row[1][id].timing
				if not tm.is_empty() and r >= tm[0] and r <= tm[1]:
					k += 1
			t += "[cell][center][bgcolor=#%s] %d [/bgcolor][/center][/cell]" % ["7a2a2a" if k < 2 else "24502f", k]
	supply.text = t + "[/table]"

# ------------------------------------------------------------------ actions

func _saved(msg: String) -> void:
	if tab == "RULES":
		Cards.sync_rules()
	Cards.refresh_texts()
	var err := Cards.save_edits()
	status.text = msg if err == OK else "Could not save to %s (error %d). The change is kept until you quit." % [Cards.edits_path(), err]
	_render()

func _add() -> void:
	if tab == "RULES":
		status.text = "Rules numbers is a single entry: edit it instead."
		return
	var tb := Cards.table(tab)
	var src = tb[tb.keys()[0]]
	var e = src.duplicate(true) if src is Dictionary else ""
	if e is Dictionary:
		e["name"] = "New card"
	_open_form("", e, true)

func _delete(id: String) -> void:
	pending_delete = ""
	if tab == "GUILDS":
		status.text = "The game needs both guilds, so guilds can't be deleted."
	elif tab == "TILES" and Cards.TILES.size() <= Cards.FAME_SPACES.size():
		status.text = "Each fame space needs a tile, so keep at least %d tiles." % Cards.FAME_SPACES.size()
	else:
		var used := []
		for t in Cards.TABLES:
			var tb := Cards.table(t)
			for other in tb:
				if (t != tab or other != id) and var_to_str(tb[other]).contains('"%s"' % id):
					used.append(_title(t, other))
		if not used.is_empty():
			status.text = "%s is used by %s. Change those first." % [_title(tab, id), ", ".join(used.slice(0, 4))]
		else:
			var nm := _title(tab, id)
			Cards.table(tab).erase(id)
			_saved("Deleted %s." % nm)
			return
	_render()

func _export() -> void:
	DisplayServer.clipboard_set(var_to_str(Cards.current_edits()))
	status.text = "Copied all edits to the clipboard. Paste them into Import edits on another computer to load them."

func _import() -> void:
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 360)
	te.placeholder_text = "Paste the text from Export edits here."
	var err := Label.new()
	err.add_theme_color_override("font_color", Color("ff7a6f"))
	_dialog("Import edits", [te, err], func():
		var v = str_to_var(te.text)
		if not v is Dictionary:
			err.text = "That isn't the text from Export edits."
			return false
		Cards.apply_edits(v)
		_saved("Imported edits.")
		return true)

func _reset_all() -> void:
	var l := Label.new()
	l.text = "Put every card and table back to its default? This deletes all your edits."
	var ok := func():
		Cards.apply_edits({})
		_saved("All cards are back to their defaults.")
		return true
	_dialog("Reset all edits", [l], ok, "Reset everything")

# ------------------------------------------------------------------ edit form

func _open_form(id: String, entry, as_new: bool) -> void:
	var holder := VBoxContainer.new()
	var form_box := VBoxContainer.new()
	var built := _field("", entry)
	form_box.add_child(built[0])
	var st := {"get": built[1]}   # lambdas capture by value, so the current getter lives here
	var text := TextEdit.new()
	text.custom_minimum_size = Vector2(0, 460)
	text.visible = false
	var err := Label.new()
	err.add_theme_color_override("font_color", Color("ff7a6f"))
	var toggle: Button = ui._btn("Edit as text (add or remove fields)", func(): pass)
	toggle.pressed.connect(func():
		if text.visible:
			var v = str_to_var(text.text)
			if v == null:
				err.text = "The text has a mistake; fix it before going back to the form."
				return
			ui._clear(form_box)
			var nb := _field("", v)
			form_box.add_child(nb[0])
			st.get = nb[1]
		else:
			text.text = var_to_str(st.get.call())
		text.visible = not text.visible
		form_box.visible = not text.visible
		toggle.text = "Edit as form" if text.visible else "Edit as text (add or remove fields)"
		err.text = "")
	holder.add_child(toggle)
	holder.add_child(form_box)
	holder.add_child(text)
	var head := "%s %s" % ["New" if as_new else "Edit", _title(tab, id) if id != "" and not as_new else "card"]
	_dialog(head, [holder, err], func():
		var v = str_to_var(text.text) if text.visible else st.get.call()
		if v == null or (entry is Dictionary and not v is Dictionary) or (entry is String and not v is String):
			err.text = "The text has a mistake, or isn't the same kind of entry."
			return false
		if v is Dictionary and v.has("name") and str(v.name).strip_edges() == "":
			err.text = "Give the card a name."
			return false
		var tb := Cards.table(tab)
		var key := id
		if as_new:
			if v is Dictionary and id != "" and v.get("name", "") == _title(tab, id):
				v["name"] += " (copy)"
			key = _new_id(v.get("name", "bonus") if v is Dictionary else "bonus", tb)
		tb[key] = v
		_saved("Saved %s." % _title(tab, key))
		return true)

func _new_id(nm: String, tb: Dictionary) -> String:
	var base := nm.to_lower().strip_edges().replace("'", "").replace(" ", "_").validate_node_name()
	if base == "":
		base = "card"
	var k := base
	var i := 2
	while tb.has(k):
		k = "%s_%d" % [base, i]
		i += 1
	return k

## A form for any value: returns [Control, getter]. Dictionaries and arrays nest; numbers get
## spin boxes; "guild" gets a guild picker; long text gets a text box.
func _field(key, value) -> Array:
	var label: String = LABELS.get(str(key), str(key).capitalize() if str(key) == str(key).to_lower() else str(key))
	if str(key) == "abil" and value is Array:
		if value.all(func(x): return x is Array):
			var box := _group("Abilities per level")
			var gets := []
			for i in value.size():
				var f := _blocks_field("Level " + ui.roman(i + 1), value[i])
				box[1].add_child(f[0])
				gets.append(f[1])
			return [box[0], func(): return gets.map(func(gg): return gg.call())]
		return _blocks_field("Abilities", value)
	if value is bool:
		var c := CheckBox.new()
		c.text = label
		c.button_pressed = value
		return [c, func(): return c.button_pressed]
	if value is int or value is float:
		var sp := SpinBox.new()
		sp.min_value = -999
		sp.max_value = 9999
		sp.step = 1 if value is int else 0.1
		sp.value = value
		sp.custom_minimum_size = Vector2(90, 0)
		return [_labeled(label, sp), func(): return int(sp.value) if value is int else sp.value]
	if value is String:
		if str(key) == "guild":
			var o := OptionButton.new()
			for gopt in GUILD_OPTS:
				o.add_item(gopt[1])
			o.selected = max(0, GUILD_OPTS.map(func(x): return x[0]).find(value))
			return [_labeled(label, o), func(): return GUILD_OPTS[o.selected][0]]
		if str(key) in ["text", ""] or value.length() > 40:
			var te := TextEdit.new()
			te.text = value
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.custom_minimum_size = Vector2(0, 64)
			te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return [_labeled(label, te, true), func(): return te.text]
		var le := LineEdit.new()
		le.text = value
		le.custom_minimum_size = Vector2(220, 0)
		return [_labeled(label, le), func(): return le.text]
	if value is Array and value.all(func(x): return x is int or x is float) and value.size() <= 4 and not value.is_empty():
		var row := HBoxContainer.new()
		var gets := []
		for i in value.size():
			var f := _field("", value[i])
			row.add_child(f[0])
			gets.append(f[1])
		return [_labeled(label, row), func(): return gets.map(func(gg): return gg.call())]
	if value is Array:
		var box := _group(label)
		var gets := []
		for i in value.size():
			var f := _field(("Level " + ui.roman(i + 1)) if value.size() == 3 else "#%d" % (i + 1), value[i])
			box[1].add_child(f[0])
			gets.append(f[1])
		if value.is_empty():
			box[1].add_child(ui._rich("[color=#aab](none: use Edit as text to add)[/color]", 0, 13))
		return [box[0], func(): return gets.map(func(gg): return gg.call())]
	if value is Dictionary:
		var box: Array = _group(label) if str(key) != "" else [VBoxContainer.new(), null]
		var inner: Container = box[1] if box[1] != null else box[0]
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 16)
		flow.add_theme_constant_override("v_separation", 6)
		inner.add_child(flow)
		var gets := {}
		for k in value:
			if str(k) == "text" and value.has("abil"):
				# written from the ability blocks when the card is saved
				inner.add_child(ui._rich("[color=#aab]Card text is written from the abilities when you save.[/color]", 0, 13))
				gets[k] = (func(v): return func(): return v).call(value[k])
				continue
			var f := _field(k, value[k])
			var simple: bool = value[k] is int or value[k] is float or value[k] is bool or (value[k] is String and str(k) != "text" and value[k].length() <= 40)
			if simple or (value[k] is Array and value[k].size() <= 4 and value[k].all(func(x): return x is int)):
				flow.add_child(f[0])
			else:
				inner.add_child(f[0])
			gets[k] = f[1]
		if value.is_empty():
			inner.add_child(ui._rich("[color=#aab](none: use Edit as text to add)[/color]", 0, 13))
		return [box[0], func():
			var out := {}
			for k in gets:
				out[k] = gets[k].call()
			return out]
	# Anything else (null, other types) stays as it was.
	return [ui._rich("[color=#aab]%s: %s[/color]" % [label, ui._esc(var_to_str(value))], 0, 13), func(): return value]

## Ability blocks: one row per block, Trigger → Effect → Amount, plus a live card-text preview.
func _blocks_field(label: String, blocks: Array) -> Array:
	var box := _group(label)
	var rows_box := VBoxContainer.new()
	box[1].add_child(rows_box)
	var preview: RichTextLabel = ui._rich("", 0, 14)
	var rows := []   # getters, shared by reference with the lambdas below
	var refresh := func():
		var bl := rows.map(func(r): return r.call())
		preview.text = "[color=#aab]Card text:[/color] " + (ui.fmt(Cards.abil_text(bl)) if not bl.is_empty() else "[i]no ability[/i]")
	var add_row := func(b: Dictionary):
		var r := _block_row(b, refresh)
		rows.append(r[1])
		rows_box.add_child(r[0])
		r[0].get_meta("remove").pressed.connect(func():
			rows.erase(r[1])
			r[0].queue_free()
			refresh.call())
	for b in blocks:
		add_row.call(b)
	box[1].add_child(ui._btn("Add ability", func():
		add_row.call({"when": "work", "do": "gain", "res": "gold", "n": 1})
		refresh.call(), false, "build"))
	box[1].add_child(preview)
	refresh.call()
	return [box[0], func(): return rows.map(func(r): return r.call())]

func _opt(items: Array, current: String, on_change: Callable) -> OptionButton:
	# items: [id, label, icon]
	var o := OptionButton.new()
	o.add_theme_constant_override("icon_max_width", 20)
	o.get_popup().add_theme_constant_override("icon_max_width", 20)
	for it in items:
		if it.size() > 2 and it[2] != "":
			o.add_icon_item(ui.icon(it[2]), it[1])
		else:
			o.add_item(it[1])
	o.selected = max(0, items.map(func(x): return x[0]).find(current))
	o.item_selected.connect(func(_i): on_change.call())
	return o

func _block_row(b: Dictionary, changed: Callable) -> Array:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	var trig := Cards.TRIGGERS.map(func(t): return [t[0], t[3], t[2]])
	var eff := Cards.EFFECTS.map(func(t): return [t[0], t[1], t[2]])
	var res := Cards.GAIN_RES.map(func(r): return [r, "XP" if r == "xp" else r.capitalize(), r])
	var pers := Cards.PERS.map(func(t): return [t[0], "fixed amount" if t[0] == "" else "per " + t[1], ""])
	var codes := Cards.SPECIALS.map(func(t): return [t[0], t[1].replace("%d", "N"), ""])
	var st := {}   # lambdas capture by value: the visibility updater is stored here once built
	var on := func():
		st.vis.call()
		changed.call()
	var o_when := _opt(trig, b.get("when", "work"), on)
	var o_do := _opt(eff, b.get("do", "gain"), on)
	var o_res := _opt(res, b.get("res", "gold"), on)
	var o_code := _opt(codes, b.get("code", "rework"), on)
	var sp_n := SpinBox.new()
	sp_n.min_value = -99
	sp_n.max_value = 999
	sp_n.value = b.get("n", 1)
	sp_n.prefix = "N"
	sp_n.value_changed.connect(func(_v): on.call())
	var o_per := _opt(pers, b.get("per", ""), on)
	var sp_div := SpinBox.new()
	sp_div.min_value = 1
	sp_div.max_value = 99
	sp_div.value = b.get("div", 1)
	sp_div.prefix = "every"
	sp_div.value_changed.connect(func(_v): on.call())
	var rm := Button.new()
	rm.text = "Remove"
	row.set_meta("remove", rm)
	for c in [o_when, ui._rich("→", 20, 16), o_do, o_res, o_code, sp_n, o_per, sp_div, rm]:
		row.add_child(c)
	var getter := func() -> Dictionary:
		var d := {"when": trig[o_when.selected][0], "do": eff[o_do.selected][0]}
		if d.do == "gain":
			d["res"] = res[o_res.selected][0]
		if d.do == "special":
			d["code"] = codes[o_code.selected][0]
			if not "%d" in Cards.SPECIALS[o_code.selected][1]:
				return d
		d["n"] = int(sp_n.value)
		if not d.do in ["special", "wall", "xp_choose"] and pers[o_per.selected][0] != "":
			d["per"] = pers[o_per.selected][0]
			if int(sp_div.value) != 1:
				d["div"] = int(sp_div.value)
		return d
	st.vis = func():
		var d: String = eff[o_do.selected][0]
		o_res.visible = d == "gain"
		o_code.visible = d == "special"
		var plain := d in ["special", "wall", "xp_choose"]
		o_per.visible = not plain
		sp_div.visible = not plain and pers[o_per.selected][0] != ""
		sp_n.visible = d != "special" or "%d" in Cards.SPECIALS[o_code.selected][1]
	st.vis.call()
	return [row, getter]

func _labeled(label: String, c: Control, wide := false) -> Control:
	var b: BoxContainer = VBoxContainer.new() if wide else HBoxContainer.new()
	if wide:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color("aab0c0"))
	b.add_child(l)
	b.add_child(c)
	return b

func _group(label: String) -> Array:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.border_color = Color("3a3f4b")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	pc.add_child(v)
	v.add_child(ui._header(label))
	return [pc, v]

## Modal panel: content controls, Cancel, and an OK button running on_ok (returns true to close).
func _dialog(title: String, content: Array, on_ok: Callable, ok_text := "Save") -> void:
	if dialog:
		dialog.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dialog = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("232730")
	sb.border_color = Color("e8d9a8")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(900, 0)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	v.add_child(ui._header(title))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, min(640, get_viewport_rect().size.y - 200))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	sc.add_child(body)
	for c in content:
		body.add_child(c)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(ui._btn("Cancel", _close_dialog))
	row.add_child(ui._btn(ok_text, func():
		if on_ok.call():
			_close_dialog()))
	v.add_child(row)

func _close_dialog() -> void:
	if dialog:
		dialog.queue_free()
		dialog = null
