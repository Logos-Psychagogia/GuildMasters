extends Control
## In-game rulebook (opened from "Rules" on the setup screen or the top bar during play).
## Sections on the left, the page on the right. Numbers and example cards are read live from
## Cards, so edits made in the card editor show up here too.

signal closed

const SECTIONS := ["Goal of the game", "Setup", "A round", "Orders", "Mercenaries", "Locations", "Quests",
	"Attacks and defense", "Bids and retreat offers", "Night: build, produce, pay", "Fame track", "End and scoring", "Controls"]

var ui            # main.gd
var page: VBoxContainer
var scroll: ScrollContainer
var btns := []

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
	top.add_child(ui._rich("[font_size=26][b]GuildMasters Rulebook[/b][/font_size]\n[color=#aab]Hover any card name to see the card.[/color]", 0, 15))
	top.add_child(ui._btn("Back", _close))
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 14)
	root.add_child(mid)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(250, 0)
	mid.add_child(nav)
	var group := ButtonGroup.new()
	for i in SECTIONS.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, SECTIONS[i]]
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show.bind(i))
		nav.add_child(b)
		btns.append(b)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	scroll.add_child(page)
	btns[0].button_pressed = true
	_show(0)

func _close() -> void:
	closed.emit()
	queue_free()

## Space would press the game's main button underneath; Escape closes the book.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_close()
		get_viewport().set_input_as_handled()

func _show(i: int) -> void:
	ui._clear(page)
	scroll.scroll_vertical = 0
	page.add_child(ui._rich("[font_size=24][b]%s[/b][/font_size]" % SECTIONS[i], 0, 16))
	# Example cards are drawn by the game's own card code, on a blank game and with no
	# interaction mode, so they look exactly like the table but never react or dim.
	var save := [ui.g, ui.mode, ui.targeting, ui.team]
	ui.g = Game.new()
	ui.mode = ""
	ui.targeting = {}
	ui.team = {}
	call("_s%d" % i)
	ui.g = save[0]
	ui.mode = save[1]
	ui.targeting = save[2]
	ui.team = save[3]
	var nav := HBoxContainer.new()
	if i > 0:
		nav.add_child(ui._btn("← " + SECTIONS[i - 1], _go.bind(i - 1)))
	if i < SECTIONS.size() - 1:
		nav.add_child(ui._btn(SECTIONS[i + 1] + " →", _go.bind(i + 1)))
	page.add_child(nav)

func _go(i: int) -> void:
	btns[i].button_pressed = true
	_show(i)

# ------------------------------------------------------------------ building blocks

## A paragraph. Plain words like gold, Might, Work: get their icons (ui.fmt); [b] etc. still work.
func _p(t: String) -> void:
	page.add_child(ui._rich(_f(t), 0, 16))

func _f(t: String) -> String:
	# fmt escapes bbcode, so formatting tags are protected and put back afterwards
	var tags := ["[b]", "[/b]", "[i]", "[/i]"]
	for k in tags.size():
		t = t.replace(tags[k], "\u0001%d\u0002" % k)
	# in prose a resource word keeps its word and gets its icon in front (fmt alone swaps it for the icon)
	var words := []
	for m in word_re.search_all(t):
		if not m.get_string() in words:
			words.append(m.get_string())
	for k in words.size():
		t = word_re_for(words[k]).sub(t, "\u0003%d\u0004" % k, true)
	t = ui.fmt(t)
	for k in tags.size():
		t = t.replace("\u0001%d\u0002" % k, tags[k])
	for k in words.size():
		var w: String = words[k]
		t = t.replace("\u0003%d\u0004" % k, "%s %s" % [ui.ii("xp" if w == "XP" else w.to_lower()), w])
	return t

var word_re := _re("\\b(gold|wood|stone|metal|fame|XP|[Dd]efense)\\b")

func word_re_for(w: String) -> RegEx:
	return _re("\\b" + w + "\\b")

func _re(p: String) -> RegEx:
	var r := RegEx.new()
	r.compile(p)
	return r

## Icon + bold title + text rows, like a reference table.
func _rows(rows: Array) -> void:
	var gr := GridContainer.new()
	gr.columns = 2
	gr.add_theme_constant_override("h_separation", 14)
	gr.add_theme_constant_override("v_separation", 8)
	for r in rows:
		gr.add_child(ui._rich("%s [b]%s[/b]" % [ui.ii(r[0], 22) if r[0] != "" else "", r[1]], 210, 16))
		gr.add_child(ui._rich(_f(r[2]), 0, 16))
	page.add_child(gr)

## A card with numbered notes beside it.
func _anatomy(card: Control, notes: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(card)
	var t := ""
	for k in notes.size():
		t += "[bgcolor=#ffd23f][color=#000000][b] %d [/b][/color][/bgcolor]  %s\n" % [k + 1, _f(notes[k])]
	h.add_child(ui._rich(t.strip_edges(), 0, 16))
	page.add_child(h)

func _cards(list: Array) -> void:
	var f: HFlowContainer = ui._flow()
	for c in list:
		f.add_child(c)
	page.add_child(f)

func _pick(table: Dictionary, want: Array) -> String:
	for id in want:
		if table.has(id):
			return id
	return table.keys()[0] if not table.is_empty() else ""

func _merc(id: String, xp := 0) -> Control:
	var m: Dictionary = ui.g.new_merc(id, xp)
	var c: Control = ui._card({"k": "rb"}, ui.g.mname(m), "%s %d" % [ui.ii("gold", 20), Cards.MERCS[id].bid], ui._merc_body(-1, m), ui.C_MERC, 252, "mercs/" + id)
	c.modulate = Color.WHITE
	return c

func _loc(id: String) -> Control:
	var c: Control = ui._card({"k": "rb"}, ui.g.lname(id), "%s %d" % [ui.ii("gold", 20), Cards.LOCS[id].bid], ui._loc_body(id, -1), ui.C_LOC, 252, "locs/" + id)
	c.modulate = Color.WHITE
	return c

func _quest(id: String) -> Control:
	var legend := Cards.LEGENDS.has(id)
	var c: Control = ui._card({"k": "rb"}, ui.g.qname(id), "", ui._quest_body(id), ui.C_LEGEND if legend else ui.C_QUEST, 252, "quests/" + id)
	c.modulate = Color.WHITE
	return c

func _guild(id: String) -> Control:
	var e: Dictionary = Cards.GUILDS[id]
	var c: Control = ui._card({"k": "rb"}, e.name, "", ui.fmt("Start: %d gold\nNight: +%d gold\n%s" % [e.start, e.income, e.text]), ui.C_GUILD, 300, "guilds/" + id)
	c.modulate = Color.WHITE
	return c

func _guild_line(id: String) -> String:
	var e: Dictionary = Cards.GUILDS.get(id, {})
	return "" if e.is_empty() else "%s (%d gold, +%d per Night)" % [e.name, e.start, e.income]

# ------------------------------------------------------------------ sections

func _s0() -> void:
	_p("You lead a mercenary guild. Hire mercenaries, send them to work, fight and quest, and grow your guild's [b]fame[/b] and holdings.")
	_p("The game ends after the round in which the last [b]legendary quest[/b] is completed (one legendary quest per player is in play). The player with the most points wins:")
	_rows([["fame", "Fame", "1 point each."], ["upgrade", "Locations", "1 point per level of each location you own."],
		["xp", "Mercenaries", "1 point per level of each mercenary you have."],
		["gold", "Resources", "1 point per 5 gold, 4 wood, 3 stone and 2 metal."]])
	_p("Fame comes mostly from quests. Completing a legendary quest gives a lot of fame and a lasting bonus, and moves the game closer to its end.")
	var ids := Cards.LEGENDS.keys()
	_cards(ids.slice(0, 4).map(func(q): return _quest(q)))

func _s1() -> void:
	_p("Two players, hot-seat on one computer (or one player against the bot). Each player leads a guild, dealt at random:")
	_cards(Cards.GUILDS.keys().map(func(k): return _guild(k)))
	_p("The table has three rows, each with one card per player and refilled at every Dawn: [b]Mercenaries[/b] for hire, [b]Locations[/b] for sale and [b]Quests[/b]. Cards show the rounds they are available in; when that time is over they leave the game.")
	_p("One player starts with the [b]priority token[/b]. It passes to the next player every round. Whoever holds it acts first and wins ties that are still tied after fame (lower fame wins those first).")

func _s2() -> void:
	_p("Each round has five phases:")
	_rows([
		["upgrade", "1. Dawn", "Priority passes. Dawn abilities trigger. Quests and locations whose time is over leave. The rows refill."],
		["bid", "2. Morning", "In secret, each player gives every mercenary an order and places bids on mercenaries and locations in the rows. A cover screen hides your choices from the other player."],
		["attack", "3. Noon", "Orders are revealed and resolved in this order: [b]attacks[/b], then [b]quests[/b], then [b]auctions[/b]."],
		["fame", "4. Evening", "Conquered and bought locations change owner. Completed quests pay their rewards."],
		["night", "5. Night", "Build (upgrades, walls, buildings, equipment), then Production (Work, Activate, income), then Wages."]])
	_p("[b]Round 1 is special:[/b] there are no orders. Each player secretly bids on exactly one mercenary (at least its cost). Winners hire; losers bid again until everyone has one mercenary.")

func _s3() -> void:
	_p("In the Morning click one of your mercenaries, then choose its order (and click its target). A mercenary with no order defends.")
	_rows([
		["work", "Work", "Work at a location: yours, the other player's, or one for sale in the row. It produces at Night (see Locations)."],
		["activate", "Activate", "Use the mercenary's Activate: ability at Night (only mercenaries that have one)."],
		["quest", "Quest", "Join a team for a quest. Click a quest that lights up, pick the team, confirm."],
		["attack", "Attack", "Attack a location in the row, or the other player."],
		["defend", "Defend", "Stay in your Garrison and protect your locations."]])
	_p("A mercenary hired today arrives too late for orders and is paid no wage tonight.")

func _s4() -> void:
	var id := _pick(Cards.MERCS, ["brenna", "bertram"])
	if id == "":
		return
	_anatomy(_merc(id), [
		"Name and [b]hire cost[/b]: the minimum bid to hire it.",
		"Role and guild. Any guild may hire any mercenary.",
		"Stats: [b]Might[/b], [b]Skill[/b] and [b]Intellect[/b]. Their sum is the mercenary's [b]Power[/b].",
		"XP and level. A mercenary reaches level II at 3 XP and level III at 10 XP, with better stats and abilities (right-click a card to see every level).",
		"Wage: 1 gold per level, paid every Night.",
		"Abilities. The opening word says when it works: Night:, Activate:, When attacking:, Garrison:, When working: and so on. A mercenary's Night: ability works only if it defended that day."])
	_p("XP comes from quests, from some locations and from abilities. Each mercenary can carry one piece of equipment (some carry two). Equipment adds stats or abilities; when you get a piece you may equip it right away (a full mercenary swaps out its old piece to your stash). During Build, click a mercenary to equip, unequip or move equipment.")
	var ids := Cards.MERCS.keys().filter(func(k): return k != id).slice(0, 3)
	_cards(ids.map(func(k): return _merc(k)))

func _s5() -> void:
	var id := _pick(Cards.LOCS, ["arena", "lumber_camp"])
	if id == "":
		return
	var d: Array = Cards.LOC_DEF
	_anatomy(_loc(id), [
		"Name and [b]minimum bid[/b] to buy it from the row.",
		"Guild and the rounds it can be bought in.",
		"Defense: %d at level I, %d at II, %d at III, plus its wall." % [d[0], d[min(1, d.size() - 1)], d[min(2, d.size() - 1)]],
		"Work: what a mercenary working here produces at Night: a fixed amount plus a bonus from the worker's stats.",
		"Owner: the owner's bonus each time [b]anyone[/b] works here, even the other player.",
		"Cost to upgrade it to the next level (Build step, owner only)."])
	_p("Locations in the row belong to nobody: anyone may work there, one mercenary per player each day, and nobody gets the owner bonus. You get a location by winning its auction or by conquering it.")
	var w := []
	for k in Cards.WALLS:
		w.append("%s +%d (%s)" % [Cards.WALLS[k].name, Cards.WALLS[k].def, ui.g.cost_str(Cards.WALLS[k].cost)])
	_p("Walls: %s. One wall per location; a stronger wall replaces a weaker one. A location restocked into the row may come with a wall, and then its bid is 2 gold higher per wall step. A conquered location loses its wall." % ", ".join(w))

func _s6() -> void:
	var mon := _pick(Cards.QUESTS, ["wolf_pack"])
	var con := _pick(Cards.QUESTS, ["firewood"])
	if mon == "":
		return
	_anatomy(_quest(mon), [
		"[b]Monster[/b] quest, its guild and the rounds it is available.",
		"Requirements: the team's total [b]Power[/b] and stat needs (here Might). Some quests also need a number of mercenaries.",
		"Reward: fame, resources, XP shared by the team, and sometimes an item, a location or a bonus you keep."])
	if con != "" and con != mon:
		_anatomy(_quest(con), [
			"[b]Contract[/b] quest: no Power needed.",
			"The team must meet the stat needs, and you [b]pay[/b] the listed resources when it is completed."])
	_p("[b]Sending a team:[/b] in the Morning, quests your mercenaries can complete light up. Click one, click mercenaries to add or remove them, and confirm when every requirement is met.")
	_p("[b]Both players on the same quest:[/b] compare the first requirement, then the next: Power, then each stat need, for monsters; resources in reserve (in the order the quest asks for them), for contracts; stat needs, for contracts with no payment. Still tied: lower fame, then the priority token. The loser may make a retreat offer (see Bids and retreat offers). The losing team returns home and may Work or Activate instead.")
	_p("[b]Shared XP:[/b] a quest's XP is split evenly among the mercenaries sent. Any leftover goes 1 at a time to the mercenaries with the least XP, to even them out; if fewer points are left than mercenaries tied for least, you choose who gets them. Later quests give more: a quest's XP equals the last round it can appear on (12 if open-ended).")
	_p("[b]Legendary quests[/b] are always available until completed. Each gives 10 fame, 20 shared XP and a lasting bonus.")

func _s7() -> void:
	_rows([
		["attack", "Attack power", "Sum of the attackers' Power plus their When attacking: bonuses. The Iron Wolves get +1 Might per attacker."],
		["defend", "Garrison", "Sum of the Power of your mercenaries that Defend, plus their Garrison: bonuses."],
		["defense", "Attack a location in the row", "If your attack power is higher than its defense you conquer it: it is yours from Evening, and all bids on it are cancelled."],
		["attack", "Attack a player", "Your power minus their Garrison is what remains. You may take one of their locations with defense lower than that. The defender may make a retreat offer."]])
	_p("A conquered location changes owner in the Evening and loses its walls. Attacks are resolved before quests and auctions.")

func _s8() -> void:
	_p("In the Morning click a mercenary or location in a row to bid on it. Bids are secret and at least the card's minimum (the Golden Ledger bids %d less on locations). Your bids together may not exceed your gold." % Cards.GUILDS.get("GL", {}).get("loc_discount", 0))
	_p("At Noon each card goes to the highest bid, who pays it. Ties: lower fame, then the priority token.")
	_p("[b]Retreat offers.[/b] Whenever you lose an auction, a contested quest or a location to an attack, you may offer the winner resources to back off. The winner accepts (and you win instead), declines, or counters with a price of their own. You may answer a counter with a new offer.")

func _s9() -> void:
	_rows([
		["build", "Build", "Each player in turn: upgrade locations, build walls and buildings, move equipment. Buildings produce from the next Night."],
		["work", "Production", "Working mercenaries produce, Activate abilities happen, then income: your guild's gold, buildings, Night: abilities of defending mercenaries, kept bonuses and fame tiles."],
		["gold", "Wages", "Pay 1 gold per level of each mercenary. If you can't pay everyone you choose who stays; the rest leave the game and you lose 1 fame per level of each."]])
	_p("[b]Buildings[/b] (build as many as you like):")
	var b := []
	for k in Cards.BUILDINGS:
		var e: Dictionary = Cards.BUILDINGS[k]
		b.append(["build", "%s" % e.name, "Costs %s. %s%s" % [ui.g.cost_str(e.cost), ("Night: +1 %s." % e.prod) if e.prod != "" else e.get("text", "") + ".",
			"" if e.guild == "" else " " + Cards.GUILDS[e.guild].name + " only."]])
	_rows(b)
	_p("Your resource table shows [b]+N[/b] above each resource: what tonight's production should bring. Gold is shown after wages. It turns red when a mercenary would have to leave.")

func _s10() -> void:
	_p("Each fame space below holds a tile, dealt at random at setup. The first player to reach that fame takes the tile.")
	_p("Spaces: %s." % ", ".join(Cards.FAME_SPACES.map(str)))
	var rows := []
	for k in Cards.TILES:
		rows.append(["fame", Cards.TILES[k].name, Cards.TILES[k].text])
	_rows(rows)

func _s11() -> void:
	_p("After the Night of the round in which the last legendary quest is completed, score:")
	_rows([["fame", "Fame", "1 point each."], ["upgrade", "Locations", "1 point per level."], ["xp", "Mercenaries", "1 point per level."],
		["gold", "Resources", "1 per 5 gold, 1 per 4 wood, 1 per 3 stone, 1 per 2 metal (each rounded down)."]])
	_p("Ties: the player with more legendary quests wins, then the priority token.")
	_p("[i]Example:[/i] 24 fame, an Arena at level II and a Lumber Camp at level I (3), mercenaries at levels III, II and I (6), and 12 gold and 4 wood (2 + 1) score 24 + 3 + 6 + 3 = [b]36[/b].")

func _s12() -> void:
	_rows([
		["", "Click", "Cards that can be used right now are bright; the rest are dimmed. Click a bright card to act on it."],
		["", "Space", "Presses the main button: confirm orders, confirm a team or bid, done building, I'm ready."],
		["", "Hover", "Hover a card name in any text to see the card."],
		["", "Right-click", "Right-click a mercenary or location to see all its levels: stats, abilities, production and upgrade costs."],
		["", "Rules", "Opens this book at any time. Esc or Back closes it."],
		["", "Editor", "On the start screen: change any card or number. The rulebook shows your edited numbers."]])
