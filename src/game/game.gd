class_name Game
extends RefCounted
## GuildMasters rules engine. UI-agnostic: whenever a player must decide something,
## the engine calls ask(), which either answers for a bot or emits need_choice and
## waits for provide(answer).

signal changed
signal logged(text: String)
signal need_choice(req: Dictionary)
signal choice_made(ans)

const RES := ["gold", "wood", "stone", "metal"]

var rng := RandomNumberGenerator.new()
var players: Array = []
var bots: Array = []
var n := 2
var round_num := 0
var phase := "Setup"
var priority := 0
var merc_deck: Array = []
var merc_row: Array = []
var loc_deck: Array = []
var loc_discard: Array = []
var loc_row: Array = []
var row_walls := {}          # wall on each unowned location in the row
var restocked := 0           # locations restocked so far (decides their wall)
var quest_deck: Array = []
var quest_discard: Array = []
var quest_row: Array = []
var legends: Array = []       # revealed and not yet completed
var legends_done: Array = []
var item_deck: Array = []
var fame_tiles := {}          # fame space -> tile id
var fame_taken := {}          # fame space -> player index who took its tile
var pending := {}
var log_lines: Array = []
var game_over := false
var final_scores: Array = []
var winner := -1
var max_rounds := 0           # 0 = no cap (tests use a cap)
var next_uid := 0
var pending_tiles: Array = []
var bids: Array = []          # per player: {"M<uid>"|"L<id>": amount}
var conquests: Array = []
var bought: Array = []
var completed: Array = []
var cancelled_locs: Array = []

# ------------------------------------------------------------------ setup

func setup(names: Array, bot_flags: Array, seed_val: int = 0) -> void:
	Cards.refresh_texts()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	n = names.size()
	bots = bot_flags.duplicate()
	var guilds := ["GL", "IW"]
	shuffle(guilds)
	for i in n:
		var gid: String = guilds[i]
		players.append({"name": names[i], "guild": gid, "gold": Cards.GUILDS[gid].start, "wood": 0, "stone": 0, "metal": 0,
			"fame": 0, "mercs": [], "locs": [], "buildings": {}, "relics": [], "stash": [], "keeps": [], "tiles": [],
			"tokens": {"upgrade": 0, "wall": 0}, "legends": 0, "today": {}})
		reset_today(i)
		bids.append({})
	for k in Cards.MERCS:
		merc_deck.append(k)
	shuffle(merc_deck)
	for k in Cards.LOCS:
		if not Cards.LOCS[k].timing.is_empty():
			loc_deck.append(k)
	shuffle(loc_deck)
	for k in Cards.QUESTS:
		quest_deck.append(k)
	shuffle(quest_deck)
	for k in Cards.ITEMS:
		item_deck.append(k)
	var tl: Array = Cards.TILES.keys()
	shuffle(tl)
	for i in Cards.FAME_SPACES.size():
		fame_tiles[Cards.FAME_SPACES[i]] = tl[i]
	var lg: Array = Cards.LEGENDS.keys()
	shuffle(lg)
	for i in n:
		legends.append(lg[i])
	priority = rng.randi_range(0, n - 1)
	for i in n:
		var p = players[i]
		note("%s leads the %s (%d gold)." % [p.name, Cards.GUILDS[p.guild].name, p.gold])
	note("Legendary quests: %s. Priority token: %s." % [", ".join(legends.map(qname)), players[priority].name])

func shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func reset_today(pi: int) -> void:
	players[pi].today = {"rival_worked": false, "conquered": false, "attack_bonus": 0, "garrison_bonus": 0,
		"wage_cut": 0, "mira_next": false, "mira_all": false, "worked": [], "built": {}}

# ------------------------------------------------------------------ helpers

func note(t: String) -> void:
	log_lines.append(t)
	logged.emit(t)

func per(a: int, b: int) -> int:
	return 0 if b <= 0 or a <= 0 else int(floor(float(a) / b))

func order() -> Array:
	var o := []
	for k in n:
		o.append((priority + k) % n)
	return o

func prio_rank(pi: int) -> int:
	return (pi - priority + n) % n

## Ties: less fame wins, then the priority token holder (then closest after it).
func tie_winner(list: Array) -> int:
	var l := list.duplicate()
	l.sort_custom(func(a, b):
		if players[a].fame != players[b].fame:
			return players[a].fame < players[b].fame
		return prio_rank(a) < prio_rank(b))
	return l[0]

func best(values: Dictionary) -> int:
	var top := -999999
	for k in values:
		top = max(top, values[k])
	var c := []
	for k in values:
		if values[k] == top:
			c.append(k)
	return tie_winner(c)

func new_merc(id: String, xp: int) -> Dictionary:
	next_uid += 1
	return {"uid": next_uid, "id": id, "xp": xp, "equip": [], "perm": [0, 0, 0], "horn": 0, "order": {}, "hired_today": false}

func level(m: Dictionary) -> int:
	return 3 if m.xp >= 10 else (2 if m.xp >= 3 else 1)

## Ability blocks of a mercenary (current level) and its equipment that fire on `when`.
func blocks(m: Dictionary, when: String) -> Array:
	var out := []
	for b in Cards.MERCS[m.id].abil[level(m) - 1]:
		if b.get("when", "") == when:
			out.append(b)
	for e in m.equip:
		for b in Cards.ITEMS[e].get("abil", []):
			if b.get("when", "") == when:
				out.append(b)
	return out

func has_special(m: Dictionary, code: String) -> bool:
	for when in ["always", "activate"]:
		for b in blocks(m, when):
			if b.get("do", "") == "special" and b.get("code", "") == code:
				return true
	return false

func can_activate(m: Dictionary) -> bool:
	return not blocks(m, "activate").is_empty()

## Amount of a block: n, or n per `div` of a counter. ctx: "group" (mercs acting together),
## "might" (Might as modified for this attack).
func amount(pi: int, m: Dictionary, b: Dictionary, ctx := {}) -> int:
	var n: int = b.get("n", 1)
	var per_k: String = b.get("per", "")
	if per_k == "":
		return n
	var s := stats(pi, m)
	var c := 0
	match per_k:
		"might": c = ctx.get("might", s[0])
		"skill": c = s[1]
		"intellect": c = s[2]
		"relics": c = players[pi].relics.size() if pi >= 0 else 0
		"equipment": c = m.equip.size()
		"others": c = max(0, ctx.get("group", [m]).size() - 1)
	return n * per(c, max(1, b.get("div", 1)))

## Sum of a mercenary's blocks of one effect for a trigger (power, might, wall...).
func block_sum(pi: int, m: Dictionary, when: String, effect: String, ctx := {}) -> int:
	var t := 0
	for b in blocks(m, when):
		if b.get("do", "") == effect:
			t += amount(pi, m, b, ctx)
	return t

## What `gain` blocks of a trigger would give, without giving it: {res: amount}.
func gain_amounts(pi: int, m: Dictionary, when: String, ctx := {}) -> Dictionary:
	var out := {}
	for b in blocks(m, when):
		if b.get("do", "") == "gain":
			out[b.get("res", "gold")] = out.get(b.get("res", "gold"), 0) + amount(pi, m, b, ctx)
	return out

## Fire a mercenary's blocks for a trigger: gains, XP and the coded specials that act now.
## Only xp_choose and rework ask the player, so other triggers complete without waiting.
func fire(pi: int, m: Dictionary, when: String, group := []) -> void:
	var ctx := {"group": group if not group.is_empty() else [m]}
	var p = players[pi]
	for b in blocks(m, when):
		var a := amount(pi, m, b, ctx)
		match b.get("do", ""):
			"gain":
				var r: String = b.get("res", "gold")
				if r == "fame":
					add_fame(pi, a)
				elif r == "xp":
					add_xp(pi, m, a)
				else:
					gain(pi, r, a)
			"xp_others":
				for o in ctx.group:
					if o != m:
						add_xp(pi, o, a)
			"xp_choose":
				var others: Array = p.mercs.filter(func(o): return o != m)
				for _k in a:
					var i: int = await pick(pi, "%s: which mercenary gains 1 XP?" % mname(m), others.map(mname))
					if i < 0:
						break
					add_xp(pi, others[i], 1)
					others.remove_at(i)
			"special":
				if b.get("code", "") == "rework":
					var others: Array = p.mercs.filter(func(o): return o != m)
					for _k in a:
						var i: int = await pick(pi, "%s: which mercenary works again?" % mname(m), others.map(mname), "Nobody")
						if i < 0:
							break
						var locs := free_work_locations(pi, others[i])
						var j: int = await pick(pi, "Where does %s work again?" % mname(others[i]), locs.map(lname))
						await do_work(pi, others[i], locs[j])
						others.remove_at(i)

func mname(m: Dictionary) -> String:
	return Cards.MERCS[m.id].name

func stats(pi: int, m: Dictionary) -> Array:
	var s: Array = Cards.MERCS[m.id].stats[level(m) - 1].duplicate()
	for i in 3:
		s[i] += m.perm[i]
	for e in m.equip:
		var st: Array = Cards.ITEMS[e].stats
		for i in 3:
			s[i] += st[i]
	s[0] += m.horn
	if pi >= 0 and has_keep(pi, "dragon"):
		s[0] += 1
	return s

func power(pi: int, m: Dictionary) -> int:
	var s := stats(pi, m)
	return s[0] + s[1] + s[2]

func has_keep(pi: int, k: String) -> bool:
	return k in players[pi].keeps

func has_relic(pi: int, r: String) -> bool:
	return pi >= 0 and r in players[pi].relics

func slots(m: Dictionary) -> int:
	return 2 if has_special(m, "slots2") else 1

func find_merc(pi: int, uid: int) -> Dictionary:
	for m in players[pi].mercs:
		if m.uid == uid:
			return m
	return {}

func row_merc(uid: int) -> Dictionary:
	for m in merc_row:
		if m.uid == uid:
			return m
	return {}

func owner_of(lid: String) -> int:
	for i in n:
		for l in players[i].locs:
			if l.id == lid:
				return i
	return -1

func loc_entry(lid: String) -> Dictionary:
	for p in players:
		for l in p.locs:
			if l.id == lid:
				return l
	return {}

func loc_level(lid: String) -> int:
	var e := loc_entry(lid)
	return 1 if e.is_empty() else e.level

func loc_wall(lid: String) -> String:
	var e := loc_entry(lid)
	return row_walls.get(lid, "") if e.is_empty() else e.wall

func loc_defense(lid: String, wall_minus := 0, ignore_walls := false) -> int:
	var e := loc_entry(lid)
	var d: int = Cards.LOC_DEF[loc_level(lid) - 1]
	var w := loc_wall(lid)
	if w != "" and not ignore_walls:
		d += max(0, Cards.WALLS[w].def - wall_minus)
	if not e.is_empty():
		var o := owner_of(lid)
		if has_relic(o, "ward_stone"):
			d += 2
		if has_keep(o, "citadel"):
			d += 3
	return d

func work_locations() -> Array:
	var a := []
	for p in players:
		for l in p.locs:
			a.append(l.id)
	for l in loc_row:
		if not l in a:
			a.append(l)
	return a

## Unowned locations (in the row) take at most 1 mercenary per player per day.
func work_slot_free(pi: int, lid: String, m: Dictionary) -> bool:
	if owner_of(lid) >= 0:
		return true
	if lid in players[pi].today.worked:
		return false
	for o in players[pi].mercs:
		if o != m and o.order.get("t", "") == "work" and o.order.get("loc", "") == lid:
			return false
	return true

func free_work_locations(pi: int, m: Dictionary) -> Array:
	return work_locations().filter(func(l): return work_slot_free(pi, l, m))

func qdef(q: String) -> Dictionary:
	return Cards.LEGENDS[q] if Cards.LEGENDS.has(q) else Cards.QUESTS[q]

func qname(q: String) -> String:
	return qdef(q).name

func lname(lid: String) -> String:
	return Cards.LOCS[lid].name

func target_name(t: String) -> String:
	if t.begins_with("L"):
		return lname(t.substr(1)) + " (unowned)"
	return players[int(t.substr(1))].name + "'s guild"

func cost_str(c: Dictionary) -> String:
	var parts := []
	for r in RES:
		if c.get(r, 0) > 0:
			parts.append("%d %s" % [c[r], r])
	return "free" if parts.is_empty() else ", ".join(parts)

func qsummary(q: String) -> String:
	var d := qdef(q)
	var s := ""
	if d.kind == "monster":
		s = "Monster: %d Power" % d.power
	else:
		s = "Contract: pay %s, 1+ mercenary" % cost_str(d.get("pay", {}))
	for st in d.get("need", {}):
		s += ", needs %s %d" % [Cards.STAT_NAMES[int(st)], d.need[st]]
	if d.get("min_mercs", 1) > 1:
		s += ", %d+ mercenaries" % d.min_mercs
	if d.get("max_mercs", 0) > 0:
		s += ", alone" if d.max_mercs == 1 else ", at most %d mercenaries" % d.max_mercs
	var r: Dictionary = d.reward
	var parts := []
	if r.has("fame"):
		parts.append("%d fame" % r.fame)
	for res in RES:
		if r.has(res):
			parts.append("%d %s" % [r[res], res])
	if r.has("xp"):
		parts.append("%d XP shared" % r.xp)
	if r.has("item"):
		parts.append("Item: " + Cards.ITEMS[r.item].name)
	if r.has("loc"):
		parts.append("Location: " + lname(r.loc))
	s += "\nReward: " + ", ".join(parts)
	if r.has("keep"):
		s += "\nKeep: " + Cards.KEEP_TEXT[r.keep]
	return s

func gain(pi: int, res: String, amt: int) -> void:
	if amt == 0:
		return
	if res == "fame":
		add_fame(pi, amt)
		return
	players[pi][res] = max(0, players[pi][res] + amt)

func can_pay(pi: int, cost: Dictionary) -> bool:
	for r in cost:
		if players[pi][r] < cost[r]:
			return false
	return true

func pay(pi: int, cost: Dictionary) -> void:
	for r in cost:
		players[pi][r] -= cost[r]

func add_xp(pi: int, m: Dictionary, amt: int) -> void:
	if amt <= 0:
		return
	var before := level(m)
	m.xp += amt
	if level(m) > before and pi >= 0:
		note("%s's %s reaches level %d." % [players[pi].name, mname(m), level(m)])

func add_fame(pi: int, amt: int) -> void:
	var p = players[pi]
	p.fame += amt
	for s in Cards.FAME_SPACES:
		if p.fame >= s and not fame_taken.has(s):
			var t: String = fame_tiles[s]
			fame_taken[s] = pi
			p.tiles.append(t)
			note("%s reaches %d fame first and takes %s (%s)." % [p.name, s, Cards.TILES[t].name, Cards.TILES[t].text])
			match t:
				"treasure":
					p.gold += 10
				"builders":
					p.tokens.upgrade += 1
				"engineers":
					p.tokens.wall += 1
				"veteran", "armory", "hero":
					pending_tiles.append([pi, t])

func take_item(pi: int, it: String) -> void:
	item_deck.erase(it)
	if Cards.ITEMS[it].kind == "relic":
		players[pi].relics.append(it)
	else:
		players[pi].stash.append(it)
	note("%s takes %s." % [players[pi].name, Cards.ITEMS[it].name])
	if Cards.ITEMS[it].kind == "relic" or players[pi].mercs.is_empty():
		return
	# Equipment can be equipped right away; a full mercenary swaps out its oldest item to the stash.
	var ms: Array = players[pi].mercs
	var i: int = await pick(pi, "Equip %s (%s) now?" % [Cards.ITEMS[it].name, Cards.ITEMS[it].text],
		ms.map(func(m): return mname(m) + ("" if m.equip.size() < slots(m) else " (swaps out %s)" % Cards.ITEMS[m.equip[0]].name)), "Keep in stash")
	if i >= 0:
		var m: Dictionary = ms[i]
		if m.equip.size() >= slots(m):
			do_unequip(pi, m.uid, m.equip[0])
		do_equip(pi, it, m.uid)
		note("%s equips %s." % [mname(m), Cards.ITEMS[it].name])

func hire(pi: int, m: Dictionary) -> void:
	merc_row.erase(m)
	m.hired_today = true
	m.order = {}
	players[pi].mercs.append(m)

func remove_merc(pi: int, m: Dictionary) -> void:
	players[pi].mercs.erase(m)
	for e in m.equip:
		item_deck.append(e)   # ponytail: equipment of a removed mercenary goes back to the item deck (rules are silent)

func garrison(pi: int) -> Array:
	return players[pi].mercs.filter(func(m): return m.order.get("t", "") == "defend")

# ------------------------------------------------------------------ power

func attack_power(pi: int, group: Array) -> int:
	var total := 0
	var ctx := {"group": group}
	for m in group:
		var s := stats(pi, m)
		var might: int = s[0] + block_sum(pi, m, "attack", "might", ctx)
		if players[pi].guild == "IW":
			might += 1
		for o in group:
			if o != m:
				might += block_sum(pi, o, "attack", "might_others", ctx)
		var pw: int = might + s[1] + s[2] + block_sum(pi, m, "attack", "power", {"group": group, "might": might})
		total += pw
	total += players[pi].today.attack_bonus
	if has_keep(pi, "attack_plus2"):
		total += 2
	return total

func garrison_power(pi: int) -> int:
	var g := garrison(pi)
	var total := 0
	for m in g:
		total += power(pi, m) + block_sum(pi, m, "garrison", "power", {"group": g})
	total += players[pi].today.garrison_bonus
	if has_keep(pi, "garrison_plus2"):
		total += 2
	return total

func quest_power(pi: int, group: Array, q: String) -> int:
	var total := 0
	var ctx := {"group": group}
	for m in group:
		var pw := power(pi, m) + block_sum(pi, m, "questing", "power", ctx)
		if group.size() == 1:
			pw += block_sum(pi, m, "solo", "power", ctx)
		if qdef(q).kind == "monster":
			pw += block_sum(pi, m, "monster", "power", ctx)
		total += pw
	return total

# ------------------------------------------------------------------ asking

func ask(pi: int, kind: String, prompt: String, data: Dictionary = {}):
	var req := data.duplicate()
	req["player"] = pi
	req["kind"] = kind
	req["prompt"] = prompt
	if bots[pi]:
		return bot_answer(req)
	pending = req
	changed.emit()
	need_choice.emit(req)
	var a = await choice_made
	pending = {}
	return a

func provide(a) -> void:
	choice_made.emit(a)

## Returns the chosen index, or -1 for the optional none_label / no options.
func pick(pi: int, prompt: String, options: Array, none_label := "") -> int:
	if options.is_empty():
		return -1
	if options.size() == 1 and none_label == "":
		return 0
	var opts := options.duplicate()
	if none_label != "":
		opts.append(none_label)
	var i: int = await ask(pi, "pick", prompt, {"options": opts})
	if none_label != "" and i == opts.size() - 1:
		return -1
	return i

## Retreat offer: the loser may offer resources to the winner to back off.
## Returns true when the winner backs off (and is then treated as the loser).
func retreat(loser: int, win: int, what: String) -> bool:
	var fields := []
	for r in RES:
		fields.append({"key": r, "label": r.capitalize(), "min": 0, "max": players[loser][r]})
	var offer = await ask(loser, "amounts", "%s, you lost %s against %s. Make a retreat offer so they back off?" % [players[loser].name, what, players[win].name],
		{"fields": fields, "can_cancel": true, "cancel_label": "No offer", "ok_label": "Offer"})
	for _i in 6:
		if offer == null or _total(offer) == 0:
			return false
		var r: int = await ask(win, "pick", "%s, %s offers you %s to back off from %s." % [players[win].name, players[loser].name, cost_str(offer), what],
			{"options": ["Accept (back off)", "Decline (keep the win)", "Counter-offer"]})
		if r == 0:
			_transfer(loser, win, offer)
			return true
		if r == 1:
			note("%s declines the retreat offer." % players[win].name)
			return false
		var counter = await ask(win, "amounts", "%s, what do you want from %s to back off?" % [players[win].name, players[loser].name],
			{"fields": fields, "can_cancel": true, "cancel_label": "Decline instead", "ok_label": "Counter"})
		if counter == null:
			return false
		var r2: int = await ask(loser, "pick", "%s, %s counters: they want %s to back off from %s." % [players[loser].name, players[win].name, cost_str(counter), what],
			{"options": ["Accept counter", "Make a new offer", "Give up"]})
		if r2 == 0:
			_transfer(loser, win, counter)
			return true
		if r2 == 2:
			return false
		offer = await ask(loser, "amounts", "%s, your new retreat offer:" % players[loser].name,
			{"fields": fields, "can_cancel": true, "cancel_label": "Give up", "ok_label": "Offer"})
	return false

func _total(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += d[k]
	return t

func _transfer(from: int, to: int, amounts: Dictionary) -> void:
	var real := {}
	for r in amounts:
		var a: int = min(amounts[r], players[from][r])
		players[from][r] -= a
		players[to][r] += a
		real[r] = a
	note("%s pays %s %s; %s backs off." % [players[from].name, players[to].name, cost_str(real), players[to].name])

# ------------------------------------------------------------------ game loop

func run() -> void:
	while not game_over:
		round_num += 1
		await dawn()
		await morning()
		await noon()
		await evening()
		await night()
		if legends.is_empty() or (max_rounds > 0 and round_num >= max_rounds):
			end_game()
	changed.emit()

func dawn() -> void:
	phase = "Dawn"
	if round_num > 1:
		priority = (priority + 1) % n
	note("=== Round %d · Dawn · priority: %s ===" % [round_num, players[priority].name])
	for pi in order():
		for m in players[pi].mercs:
			fire(pi, m, "dawn")
	for q in quest_row.duplicate():
		if Cards.QUESTS[q].timing[1] < round_num:
			quest_row.erase(q)
			note("%s expires and leaves the game." % qname(q))
	for l in loc_row.duplicate():
		if Cards.LOCS[l].timing[1] < round_num:
			loc_row.erase(l)
			row_walls.erase(l)
			note("%s expires and leaves the game." % lname(l))
	while quest_row.size() < n:
		var c := draw_timed(quest_deck, quest_discard, Cards.QUESTS)
		if c == "":
			break
		quest_row.append(c)
	while loc_row.size() < n:
		if not restock_location():
			break
	while merc_row.size() < n and not merc_deck.is_empty():
		merc_row.append(new_merc(merc_deck.pop_back(), 0))   # design change: no catch-up XP now that nights give none
	for pi in order():
		if has_relic(pi, "ancient_map"):
			await ancient_map(pi)
	await process_tiles()
	changed.emit()

## Draws one location into the row and gives it its restock wall. False if none can be drawn.
func restock_location() -> bool:
	var c := draw_timed(loc_deck, loc_discard, Cards.LOCS)
	if c == "":
		return false
	loc_row.append(c)
	var tier: int = restocked / n - 1     # first n restocked: no wall
	row_walls[c] = "" if tier < 0 else Cards.RESTOCK_WALLS[min(tier, 2)]
	restocked += 1
	return true

func draw_timed(deck: Array, discard: Array, db: Dictionary) -> String:
	while true:
		if deck.is_empty():
			if discard.is_empty():
				return ""
			# ponytail: guard against an endless loop when every discarded card is still too early
			if discard.all(func(c): return db[c].timing[0] > round_num):
				return ""
			deck.append_array(discard)
			discard.clear()
			shuffle(deck)
		var c: String = deck.pop_back()
		var t: Array = db[c].timing
		if round_num < t[0]:
			discard.append(c)
		elif round_num > t[1]:
			note("%s was drawn too late and leaves the game." % db[c].name)
		else:
			return c
	return ""

func ancient_map(pi: int) -> void:
	var top := []
	for _i in 3:
		if quest_deck.is_empty():
			break
		top.append(quest_deck.pop_back())
	var keep := []
	for c in top:
		var i: int = await pick(pi, "Ancient Map: %s\n%s" % [qname(c), qsummary(c)], ["Keep in deck", "Discard"])
		if i == 1:
			quest_discard.append(c)
		else:
			keep.append(c)
	var ordered := []
	while keep.size() > 1:
		var i: int = await pick(pi, "Ancient Map: which quest goes on top next?", keep.map(qname))
		ordered.append(keep[i])
		keep.remove_at(i)
	ordered.append_array(keep)
	ordered.reverse()
	quest_deck.append_array(ordered)
	note("%s consults the Ancient Map." % players[pi].name)

# ------------------------------------------------------------------ morning

func morning() -> void:
	phase = "Morning"
	changed.emit()
	if round_num == 1:
		await first_hire()
		return
	for pi in order():
		bids[pi] = {}
		var ans = await ask(pi, "morning", "%s: give every mercenary an order and place bids. This is secret." % players[pi].name)
		apply_morning(pi, ans)
	phase = "Reveal"
	for pi in order():
		note(orders_text(pi))

func valid_order(pi: int, m: Dictionary, o: Dictionary) -> bool:
	match o.get("t", ""):
		"work":
			return o.get("loc", "") in work_locations() and work_slot_free(pi, o.get("loc", ""), m)
		"act":
			return can_activate(m)
		"quest":
			return o.get("q", "") in quest_row or o.get("q", "") in legends
		"attack":
			var t: String = o.get("target", "")
			if t.begins_with("L"):
				return t.substr(1) in loc_row
			return t.begins_with("P") and int(t.substr(1)) != pi and int(t.substr(1)) < n
		"defend", "none":
			return true
	return false

## Minimum bid; for a player (pi >= 0) it includes their discounts (Golden Ledger: locations -3).
func bid_min(key: String, pi := -1) -> int:
	if key.begins_with("M"):
		var m := row_merc(int(key.substr(1)))
		return -1 if m.is_empty() else Cards.MERCS[m.id].bid
	var lid := key.substr(1)
	if not lid in loc_row:
		return -1
	var b: int = Cards.LOCS[lid].bid + 2 * (["", "wooden", "stone", "iron"].find(row_walls.get(lid, "")))
	if pi >= 0:
		b -= Cards.GUILDS[players[pi].guild].get("loc_discount", 0)
	return max(1, b)

func apply_morning(pi: int, ans: Dictionary) -> void:
	var orders: Dictionary = ans.get("orders", {})
	for m in players[pi].mercs:
		m.order = {}
	for m in players[pi].mercs:
		var o: Dictionary = orders.get(m.uid, {"t": "defend"})
		m.order = o if valid_order(pi, m, o) else {"t": "defend"}
	var b := {}
	var total := 0
	var raw: Dictionary = ans.get("bids", {})
	for k in raw:
		var mn := bid_min(k, pi)
		if mn >= 0 and raw[k] >= mn and raw[k] > 0:
			b[k] = raw[k]
			total += raw[k]
	if total > players[pi].gold:
		note("%s's bids exceed their gold and are void." % players[pi].name)
		b = {}
	bids[pi] = b

func order_text(pi: int, m: Dictionary) -> String:
	var o: Dictionary = m.order
	match o.get("t", ""):
		"work":
			return "Work at " + lname(o.loc)
		"act":
			return "Activate"
		"quest":
			return "Quest: " + qname(o.q)
		"attack":
			return "Attack " + target_name(o.target)
		"defend":
			return "Defend"
		"none":
			return "No order"
	return "(no order)"

func bid_name(k: String) -> String:
	if k.begins_with("M"):
		var m := row_merc(int(k.substr(1)))
		return "?" if m.is_empty() else mname(m)
	return lname(k.substr(1))

func orders_text(pi: int) -> String:
	var parts := []
	for m in players[pi].mercs:
		if not m.hired_today:
			parts.append("%s: %s" % [mname(m), order_text(pi, m)])
	var bp := []
	for k in bids[pi]:
		bp.append("%s %d" % [bid_name(k), bids[pi][k]])
	return "%s reveals — %s. Bids: %s." % [players[pi].name, "; ".join(parts) if parts else "no mercenaries", ", ".join(bp) if bp else "none"]

func first_hire() -> void:
	var waiting := order()
	while not waiting.is_empty() and not merc_row.is_empty():
		var round_bids := {}   # uid -> {pi: amount}
		for pi in waiting:
			var ans = await ask(pi, "first_bid", "Round 1 — %s: bid on exactly one mercenary (secret). Minimum bid = its cost." % players[pi].name,
				{"mercs": merc_row.map(func(m): return m.uid)})
			var m := row_merc(int(ans.get("uid", -1)))
			if m.is_empty():
				m = merc_row[0]
			var amt: int = clamp(int(ans.get("amount", 0)), Cards.MERCS[m.id].bid, max(Cards.MERCS[m.id].bid, players[pi].gold))
			if not round_bids.has(m.uid):
				round_bids[m.uid] = {}
			round_bids[m.uid][pi] = amt
		for uid in round_bids:
			var m := row_merc(uid)
			var w: int = await auction_winner(mname(m), round_bids[uid])
			var price: int = min(round_bids[uid][w], players[w].gold)
			players[w].gold -= price
			hire(w, m)
			waiting.erase(w)
			note("%s hires %s for %d gold." % [players[w].name, mname(m), price])
		for pi in waiting:
			note("%s lost the bid and bids again." % players[pi].name)

# ------------------------------------------------------------------ noon

func noon() -> void:
	phase = "Noon"
	conquests.clear()
	bought.clear()
	completed.clear()
	cancelled_locs.clear()
	changed.emit()
	if round_num == 1:
		return
	for pi in order():
		var ms: Array = players[pi].mercs
		if has_relic(pi, "war_horn") and not ms.is_empty():
			var i: int = await pick(pi, "War Horn: +3 Might to one mercenary until the end of Night?", ms.map(mname), "Don't use")
			if i >= 0:
				ms[i].horn += 3
				note("%s sounds the War Horn for %s." % [players[pi].name, mname(ms[i])])
	# Barracks / Siege Workshop say "today": their Work bonus is applied now so it can matter at Noon.
	for pi in n:
		for m in players[pi].mercs:
			if m.order.get("t", "") == "work":
				var w: Dictionary = Cards.LOCS[m.order.loc].levels[loc_level(m.order.loc) - 1].w
				var s := stats(pi, m)
				if w.k == "garrison":
					players[pi].today.garrison_bonus += per(s[0], w.div) * w.mult
				elif w.k == "attack":
					players[pi].today.attack_bonus += per(s[1], w.div) * w.mult
	await resolve_attacks()
	await resolve_quests()
	await resolve_auctions()
	await process_tiles()
	changed.emit()

func resolve_attacks() -> void:
	var groups := {}
	for pi in n:
		for m in players[pi].mercs:
			if m.order.get("t", "") == "attack":
				var t: String = m.order.target
				if not groups.has(t):
					groups[t] = {}
				if not groups[t].has(pi):
					groups[t][pi] = []
				groups[t][pi].append(m)
	var attacks := []
	for t in groups:
		var g: Dictionary = groups[t]
		var win: int = g.keys()[0]
		if g.size() > 1:
			var pw := {}
			for pi in g:
				pw[pi] = attack_power(pi, g[pi])
			win = best(pw)
			note("Attackers clash over %s: %s." % [target_name(t), ", ".join(pw.keys().map(func(pi): return "%s %d" % [players[pi].name, pw[pi]]))])
			for pi in g:
				if pi != win:
					if await retreat(pi, win, "the clash over " + target_name(t)):
						win = pi
					break
			note("%s's attack goes on." % players[win].name)
		attacks.append([win, t])
	attacks.sort_custom(func(a, b): return prio_rank(a[0]) < prio_rank(b[0]))
	for a in attacks:
		await resolve_attack(a[0], a[1], groups[a[1]][a[0]])

func resolve_attack(pi: int, t: String, group: Array) -> void:
	var pw := attack_power(pi, group)
	var who: String = players[pi].name
	var wm := 0
	var ign := false
	for m in group:
		var w := block_sum(pi, m, "attack", "wall", {"group": group})
		if w >= 99:
			ign = true
		else:
			wm += w
	if t.begins_with("L"):
		var lid := t.substr(1)
		if not lid in loc_row or owner_of(lid) >= 0:
			return
		var d := loc_defense(lid, wm, ign)
		if pw > d:
			note("%s attacks %s with %d Power against defense %d and conquers it." % [who, lname(lid), pw, d])
			conquests.append({"pi": pi, "lid": lid})
			cancelled_locs.append(lid)
			on_conquer(pi, group)
		else:
			note("%s attacks %s with %d Power against defense %d and fails." % [who, lname(lid), pw, d])
		return
	var dj := int(t.substr(1))
	var gp := garrison_power(dj)
	for m in garrison(dj):
		fire(dj, m, "defended", garrison(dj))
	var rem := pw - gp
	var taken := conquests.map(func(c): return c.lid)
	var cands := []
	for l in players[dj].locs:
		if not l.id in taken and loc_defense(l.id, wm, ign) < rem:
			cands.append(l.id)
	note("%s attacks %s: %d Power - garrison %d = %d remaining." % [who, players[dj].name, pw, gp, rem])
	if cands.is_empty():
		note("No location has defense below %d. Nothing changes." % rem)
		return
	var i: int = await pick(pi, "%s: conquer which location of %s? (remaining power %d)" % [who, players[dj].name, rem],
		cands.map(func(l): return "%s (defense %d)" % [lname(l), loc_defense(l, wm, ign)]))
	var lid: String = cands[i]
	if await retreat(dj, pi, "the attack on " + lname(lid)):
		return
	note("%s conquers %s from %s (owned from Evening, walls removed)." % [who, lname(lid), players[dj].name])
	conquests.append({"pi": pi, "lid": lid})
	on_conquer(pi, group)

func on_conquer(pi: int, group: Array) -> void:
	var p = players[pi]
	p.today.conquered = true
	if p.guild == "IW":
		gain(pi, "gold", 3)
		note("Iron Wolves conquest bonus: %s gains 3 gold." % p.name)
	for m in group:
		fire(pi, m, "conquest", group)
	if has_relic(pi, "trophy_rack"):
		add_fame(pi, 1)

func resolve_quests() -> void:
	var groups := {}
	for pi in n:
		for m in players[pi].mercs:
			if m.order.get("t", "") == "quest":
				var q: String = m.order.q
				if not groups.has(q):
					groups[q] = {}
				if not groups[q].has(pi):
					groups[q][pi] = []
				groups[q][pi].append(m)
	for q in groups:
		var g: Dictionary = groups[q]
		var att: int = g.keys()[0]
		if g.size() > 1:
			var keys := {}
			for pi in g:
				keys[pi] = quest_contest_key(pi, q, g[pi])
			att = contest_winner(keys)
			var labels := quest_contest_labels(q)
			note("Contested quest %s (compared by %s, then lowest fame, then priority): %s." % [qname(q), ", ".join(labels),
				", ".join(keys.keys().map(func(pi): return "%s %s" % [players[pi].name, "/".join(keys[pi].map(str))]))])
			for pi in g:
				if pi != att:
					if await retreat(pi, att, "the contest for " + qname(q)):
						att = pi
					break
			for pi in g:
				if pi != att:
					note("%s's mercenaries return home." % players[pi].name)
					await reorder(pi, g[pi])
		await attempt_quest(att, q, g[att])

## Contested quests: compare each requirement in order. Monsters: Power, then each stat need.
## Contracts: the player's reserve of each resource the quest asks for, in the order listed (stat needs
## when it asks for no payment). Then lowest fame, then the priority token (tie_winner).
func quest_contest_key(pi: int, q: String, group: Array) -> Array:
	var d := qdef(q)
	var key := []
	var tot := [0, 0, 0]
	for m in group:
		var st := stats(pi, m)
		for i in 3:
			tot[i] += st[i]
	if d.kind == "monster":
		key.append(quest_power(pi, group, q))
	else:
		for r in d.get("pay", {}):
			key.append(players[pi][r])
	if d.kind == "monster" or d.get("pay", {}).is_empty():
		for st in d.get("need", {}):
			key.append(tot[int(st)])
	return key

func quest_contest_labels(q: String) -> Array:
	var d := qdef(q)
	var out := []
	if d.kind == "monster":
		out.append("Power")
	else:
		for r in d.get("pay", {}):
			out.append(r + " in reserve")
	if d.kind == "monster" or d.get("pay", {}).is_empty():
		for st in d.get("need", {}):
			out.append(Cards.STAT_NAMES[int(st)])
	return out

func contest_winner(keys: Dictionary) -> int:
	var c: Array = keys.keys()
	var depth: int = keys[c[0]].size()
	for i in depth:
		var top := -999999
		for pi in c:
			top = max(top, keys[pi][i])
		c = c.filter(func(pi): return keys[pi][i] == top)
		if c.size() == 1:
			return c[0]
	return tie_winner(c)

func reorder(pi: int, ms: Array) -> void:
	for m in ms:
		var locs := free_work_locations(pi, m)
		var opts: Array = locs.map(func(l): return "Work at " + lname(l))
		if can_activate(m):
			opts.append("Activate")
		var i: int = await pick(pi, "%s returns home from the quest. Work or Activate instead?" % mname(m), opts, "Do nothing")
		if i < 0:
			m.order = {"t": "none"}
		elif i < locs.size():
			m.order = {"t": "work", "loc": locs[i]}
		else:
			m.order = {"t": "act"}

## Why this group can't complete the quest right now (empty = it can). Used by the rules,
## the UI (quest highlighting and the team picker) and the bot.
func quest_problems(pi: int, q: String, group: Array) -> Array:
	var d := qdef(q)
	var why := []
	if group.is_empty():
		return ["no mercenaries"]
	var tot := [0, 0, 0]
	for m in group:
		var s := stats(pi, m)
		for i in 3:
			tot[i] += s[i]
	var need: Dictionary = d.get("need", {})
	for st in need:
		if tot[int(st)] < need[st]:
			why.append("%s %d < %d" % [Cards.STAT_NAMES[int(st)], tot[int(st)], need[st]])
	if group.size() < d.get("min_mercs", 1):
		why.append("needs %d+ mercenaries" % d.min_mercs)
	if d.get("max_mercs", 0) > 0 and group.size() > d.max_mercs:
		why.append("at most %d mercenar%s" % [d.max_mercs, "y" if d.max_mercs == 1 else "ies"])
	if d.kind == "monster":
		var qp := quest_power(pi, group, q)
		if qp < d.power:
			why.append("Power %d < %d" % [qp, d.power])
	elif not can_pay(pi, d.get("pay", {})):
		why.append("can't pay %s" % cost_str(d.pay))
	return why

## Can some group of these mercenaries complete the quest? Tries every merc alone, then the strongest
## groups (adding mercenaries never lowers stats; only solo bonuses and max_mercs need the singles).
func quest_feasible(pi: int, q: String, ms: Array) -> Array:
	for m in ms:
		if quest_problems(pi, q, [m]).is_empty():
			return [m]
	var sorted := ms.duplicate()
	sorted.sort_custom(func(a, b): return power(pi, a) > power(pi, b))
	for k in range(2, sorted.size() + 1):
		var gr := sorted.slice(0, k)
		if quest_problems(pi, q, gr).is_empty():
			return gr
	return []

func attempt_quest(pi: int, q: String, group: Array) -> void:
	var d := qdef(q)
	var why := quest_problems(pi, q, group)
	if why.is_empty():
		if d.kind == "contract":
			pay(pi, d.get("pay", {}))
		completed.append({"pi": pi, "q": q, "mercs": group})
		note("%s completes %s!" % [players[pi].name, qname(q)])
	else:
		note("%s fails %s (%s)." % [players[pi].name, qname(q), ", ".join(why)])

func auction_winner(what: String, bidders: Dictionary) -> int:
	var w := best(bidders)
	if bidders.size() > 1:
		var rest := bidders.duplicate()
		rest.erase(w)
		var second := best(rest)
		if await retreat(second, w, "the auction for " + what):
			w = second
	return w

func resolve_auctions() -> void:
	var keys := []
	for m in merc_row:
		keys.append("M%d" % m.uid)
	for l in loc_row:
		keys.append("L" + l)
	for k in keys:
		var bidders := {}
		for pi in n:
			if bids[pi].has(k):
				bidders[pi] = bids[pi][k]
		if bidders.is_empty():
			continue
		var what := bid_name(k)
		if k.begins_with("L") and k.substr(1) in cancelled_locs:
			note("Bids on %s are cancelled: it was conquered." % what)
			continue
		var w: int = await auction_winner(what, bidders)
		var price: int = max(0, bidders[w] - (1 if has_relic(w, "merchants_seal") else 0))
		if players[w].gold < price:
			note("%s can no longer pay %d for %s; the bid is void." % [players[w].name, price, what])
			continue
		players[w].gold -= price
		if k.begins_with("M"):
			hire(w, row_merc(int(k.substr(1))))
			note("%s hires %s for %d gold." % [players[w].name, what, price])
		else:
			bought.append({"pi": w, "lid": k.substr(1)})
			note("%s buys %s for %d gold." % [players[w].name, what, price])

# ------------------------------------------------------------------ evening

func evening() -> void:
	phase = "Evening"
	for c in conquests:
		transfer(c.lid, c.pi, "")
	for b in bought:
		transfer(b.lid, b.pi, row_walls.get(b.lid, ""))
	for c in completed:
		await reward(c)
	await process_tiles()
	changed.emit()

## Conquered locations lose their walls; bought ones keep the wall they had in the row.
func transfer(lid: String, pi: int, wall: String) -> void:
	var o := owner_of(lid)
	var lv := 1
	if o >= 0:
		var e := loc_entry(lid)
		lv = e.level
		players[o].locs.erase(e)
	loc_row.erase(lid)
	row_walls.erase(lid)
	players[pi].locs.append({"id": lid, "level": lv, "wall": wall})

func reward(c: Dictionary) -> void:
	var pi: int = c.pi
	var q: String = c.q
	var p = players[pi]
	var r: Dictionary = qdef(q).reward
	if q in legends:
		legends.erase(q)
		legends_done.append(q)
		p.legends += 1
	else:
		quest_row.erase(q)
	add_fame(pi, r.get("fame", 0))
	for res in RES:
		gain(pi, res, r.get(res, 0))
	await share_xp(pi, c.mercs, r.get("xp", 0))
	if r.has("item"):
		if r.item in item_deck:
			await take_item(pi, r.item)
		else:
			gain(pi, "gold", 2)
			note("%s is gone; %s takes 2 gold instead." % [Cards.ITEMS[r.item].name, p.name])
	if r.has("loc"):
		p.locs.append({"id": r.loc, "level": 1, "wall": ""})
		note("%s gains the %s." % [p.name, lname(r.loc)])
	if r.has("keep"):
		if r.keep == "level_up":
			await level_up(pi, qname(q))   # one-time: nothing to keep
		else:
			p.keeps.append(r.keep)
	for m in c.mercs:
		if m in p.mercs:
			fire(pi, m, "qdone", c.mercs)
	note("%s collects the reward for %s." % [p.name, qname(q)])

## Quest XP is shared: an even split first, then the leftover goes 1 at a time to the team's lowest-XP
## mercenaries to even them out. When fewer points are left than mercenaries tied at the lowest XP,
## the player picks who gets them.
func share_xp(pi: int, team: Array, total: int) -> void:
	if team.is_empty() or total <= 0:
		return
	for m in team:
		add_xp(pi, m, total / team.size())
	var left := total % team.size()
	while left > 0:
		var low: int = team.map(func(m): return m.xp).min()
		var tied: Array = team.filter(func(m): return m.xp == low)
		if tied.size() <= left:
			for m in tied:
				add_xp(pi, m, 1)
			left -= tied.size()
			continue
		for _k in left:
			var i: int = await pick(pi, "Leftover quest XP (%d to give): which mercenary gains 1 XP?" % (left - _k), tied.map(mname))
			add_xp(pi, tied[i], 1)
			tied.remove_at(i)
		left = 0

func level_up(pi: int, why: String) -> void:
	var p = players[pi]
	var ms: Array = p.mercs.filter(func(m): return level(m) < 3)
	var i: int = await pick(pi, "%s: which mercenary gains a level?" % why, ms.map(mname))
	if i >= 0:
		ms[i].xp = 3 if level(ms[i]) == 1 else 10
		note("%s's %s rises to level %d." % [p.name, mname(ms[i]), level(ms[i])])

func process_tiles() -> void:
	while not pending_tiles.is_empty():
		var t: Array = pending_tiles.pop_front()
		var pi: int = t[0]
		var p = players[pi]
		match t[1]:
			"veteran":
				await level_up(pi, "Veteran Training")
			"armory":
				var eq: Array = item_deck.filter(func(it): return Cards.ITEMS[it].kind == "equip")
				var i: int = await pick(pi, "Royal Armory: take any equipment from the deck.", eq.map(func(it): return "%s (%s)" % [Cards.ITEMS[it].name, Cards.ITEMS[it].text]))
				if i >= 0:
					await take_item(pi, eq[i])
			"hero":
				var i: int = await pick(pi, "Hero's Welcome: hire a mercenary from the row for free.", merc_row.map(func(m): return "%s (Lv %d)" % [mname(m), level(m)]))
				if i >= 0:
					var m: Dictionary = merc_row[i]
					hire(pi, m)
					note("%s hires %s for free." % [p.name, mname(m)])
	changed.emit()

# ------------------------------------------------------------------ night

## Night, in this build's order (design change, Nov 25): XP and equipment, Build,
## then Production as the last thing in the day, then Wages and Reset.
func night() -> void:
	phase = "Night"
	changed.emit()
	# Mira's Activate discounts tonight's building, so it takes effect before Build.
	for pi in n:
		for m in players[pi].mercs:
			if m.order.get("t", "") == "act":
				if has_special(m, "discount_all"):
					players[pi].today.mira_all = true
				elif has_special(m, "discount"):
					players[pi].today.mira_next = true
	# XP (design change, Nov 25: mercenaries no longer gain 1 XP every Night; XP comes from
	# quests, locations and abilities)
	for pi in n:
		if has_keep(pi, "lich"):
			for m in players[pi].mercs:
				add_xp(pi, m, 1)
		for m in garrison(pi):
			fire(pi, m, "garrison", garrison(pi))
	changed.emit()
	phase = "Build"
	for pi in order():
		await ask(pi, "build", "%s: move equipment, upgrade locations, build buildings and walls." % players[pi].name)
	await process_tiles()
	phase = "Production"
	changed.emit()
	var before := []
	for p in players:
		before.append({"gold": p.gold, "wood": p.wood, "stone": p.stone, "metal": p.metal, "fame": p.fame})
	for pi in order():
		for m in players[pi].mercs.duplicate():
			if m.order.get("t", "") == "work":
				await do_work(pi, m, m.order.loc)
	for pi in order():
		for m in players[pi].mercs.duplicate():
			if m.order.get("t", "") == "act":
				await do_activate(pi, m)
	for pi in order():
		await income(pi)
	for pi in order():
		var p = players[pi]
		var parts := []
		for r in ["gold", "wood", "stone", "metal", "fame"]:
			var d: int = p[r] - before[pi][r]
			if d != 0:
				parts.append("%+d %s" % [d, r])
		note("Production for %s: %s." % [p.name, ", ".join(parts) if parts else "nothing"])
	await process_tiles()
	phase = "Wages"
	changed.emit()
	for pi in order():
		await wages(pi)
	await process_tiles()
	for pi in n:
		reset_today(pi)
		for m in players[pi].mercs:
			m.horn = 0
			m.order = {}
			m.hired_today = false
	changed.emit()

func do_work(pi: int, m: Dictionary, lid: String) -> void:
	var p = players[pi]
	var L: Dictionary = Cards.LOCS[lid].levels[loc_level(lid) - 1]
	var w: Dictionary = L.w
	var s := stats(pi, m)
	if owner_of(lid) < 0:
		p.today.worked.append(lid)
	# base production of the location, paid whatever its special effect is (design change Nov 25)
	var base: Dictionary = w.get("base", {})
	for r in base:
		if r == "xp":
			add_xp(pi, m, base[r])
		else:
			gain(pi, r, base[r])
	match w.k:
		"per":
			var st: int = s.max() if w.stat == 3 else s[w.stat]
			var amt: int = per(st, w.div) * w.get("mult", 1) + w.get("plus", 0)
			if w.res == "xp":
				add_xp(pi, m, amt)
			else:
				gain(pi, w.res, amt)
		"bank":
			gain(pi, "gold", min(per(p.gold, w.div), s[2]))
		"chouse":
			if s[2] >= w.min:
				var cnt := 0
				for i in n:
					if w.scope == "all" or i == pi:
						cnt += players[i].locs.size()
				gain(pi, "gold", cnt * w.mult)
		"shrine", "forge":
			var res := "gold" if w.k == "shrine" else "metal"
			var kind := "relic" if w.k == "shrine" else "equip"
			var cap: int = (s[2] if w.k == "shrine" else s[0]) + w.off
			var its: Array = item_deck.filter(func(it): return Cards.ITEMS[it].kind == kind and Cards.ITEMS[it].value <= cap)
			if p[res] >= w.pay and not its.is_empty():
				var i: int = await pick(pi, "%s at %s: pay %d %s to take an item of value <= %d?" % [mname(m), lname(lid), w.pay, res, cap],
					its.map(func(it): return "%s (value %d): %s" % [Cards.ITEMS[it].name, Cards.ITEMS[it].value, Cards.ITEMS[it].text]), "Skip")
				if i >= 0:
					p[res] -= w.pay
					await take_item(pi, its[i])
		"sell":
			var cap := per(s[2], w.div)
			if cap > 0 and p.wood + p.stone + p.metal > 0:
				var fields := []
				for r in ["wood", "stone", "metal"]:
					fields.append({"key": r, "label": r.capitalize(), "min": 0, "max": min(cap, p[r])})
				var a = await ask(pi, "amounts", "%s at %s: sell up to %d resources for 2 gold each." % [mname(m), lname(lid), cap],
					{"fields": fields, "total_max": cap, "can_cancel": true, "cancel_label": "Sell nothing", "ok_label": "Sell"})
				if a != null:
					var t := 0
					for r in a:
						var k: int = min(a[r], p[r])
						p[r] -= k
						t += k
					t = min(t, cap)
					gain(pi, "gold", 2 * t)
		"wages":
			p.today.wage_cut += per(s[0], w.div)
		_:
			pass   # garrison/attack bonuses were applied at Noon
	fire(pi, m, "work")
	for o in p.mercs:
		if o != m:
			fire(pi, o, "ally_work")
	var ow := owner_of(lid)
	if ow >= 0:
		for r in L.owner:
			gain(ow, r, L.owner[r])
		var off: int = players[ow].buildings.get("office", 0)
		if off > 0:
			gain(ow, "gold", off)   # Counting Office: +1 gold per owner bonus
		if has_relic(ow, "signet_ring"):
			gain(ow, "gold", 1)
		if ow != pi:
			players[ow].today.rival_worked = true

func do_activate(pi: int, m: Dictionary) -> void:
	await fire(pi, m, "activate", players[pi].mercs)

func income(pi: int) -> void:
	var p = players[pi]
	gain(pi, "gold", Cards.GUILDS[p.guild].income + (8 if has_keep(pi, "kraken") else 0))
	for b in p.buildings:
		var cnt: int = p.buildings[b] - p.today.built.get(b, 0)
		var bd: Dictionary = Cards.BUILDINGS[b]
		if bd.prod != "":
			gain(pi, bd.prod, cnt)
		elif b == "warcamp":
			for _k in cnt:
				var i: int = await pick(pi, "War Camp: which mercenary gains 1 XP?", p.mercs.map(mname))
				if i >= 0:
					add_xp(pi, p.mercs[i], 1)
				if p.today.conquered:
					gain(pi, "gold", 2)
	var tile_prod := {"stipend": ["gold", 2], "lumber": ["wood", 1], "quarry": ["stone", 1], "mining": ["metal", 1]}
	for t in p.tiles:
		if tile_prod.has(t):
			gain(pi, tile_prod[t][0], tile_prod[t][1])
	var keep_prod := {"night_wood": "wood", "night_stone": "stone", "night_gold": "gold", "night_metal": "metal"}
	for k in p.keeps:
		if keep_prod.has(k):
			gain(pi, keep_prod[k], 1)
	if has_relic(pi, "golden_idol"):
		gain(pi, "gold", 2)
	if has_relic(pi, "venom_lore"):
		await share_xp(pi, p.mercs, 1)
	for m in garrison(pi):   # only defending mercenaries use their Night ability
		fire(pi, m, "night")
	if has_relic(pi, "trade_charter"):
		var have: Array = ["wood", "stone", "metal"].filter(func(r): return p[r] > 0)
		var i: int = await pick(pi, "Trade Charter: sell a resource for 4 gold?", have.map(func(r): return "Sell 1 " + r), "Don't sell")
		if i >= 0:
			p[have[i]] -= 1
			gain(pi, "gold", 4)

func wage_of(pi: int, m: Dictionary) -> int:
	return level(m) - (1 if level(m) >= 2 and has_relic(pi, "veterans_pact") else 0)

## Wages: 1 gold per level (Veteran's Pact -1 on levels II and III). Discounts (Mess Hall, Shrine of the Saint)
## come off the total. If you can't pay everyone, you choose who to keep; the rest leave the game
## and you lose 1 fame per level of each one.
func wages_due(pi: int) -> int:
	var p = players[pi]
	var total := 0
	for m in p.mercs.filter(func(m): return not m.hired_today):
		total += wage_of(pi, m)
	return max(0, total - p.today.wage_cut - (1 if has_keep(pi, "wages_minus1") else 0))

func wages(pi: int) -> void:
	var p = players[pi]
	var ms: Array = p.mercs.filter(func(m): return not m.hired_today)
	var cut: int = p.today.wage_cut + (1 if has_keep(pi, "wages_minus1") else 0)
	var total := 0
	for m in ms:
		total += wage_of(pi, m)
	var due := wages_due(pi)
	if p.gold >= due:
		p.gold -= due
		note("%s pays %d gold in wages." % [p.name, due])
		return
	var keep := []
	var left := ms.duplicate()
	var budget: int = p.gold + cut   # discounts make the first gold of wages free
	while true:
		var affordable: Array = left.filter(func(m): return wage_of(pi, m) <= budget)
		if affordable.is_empty():
			break
		var i: int = await pick(pi, "%s, you can't pay every wage (%d gold + %d discount for %d gold of wages). Choose a mercenary to pay and keep:" % [p.name, p.gold, cut, total],
			affordable.map(func(m): return "Keep %s (Lv %d, wage %d)" % [mname(m), level(m), wage_of(pi, m)]), "Let the rest go")
		if i < 0:
			break
		var m: Dictionary = affordable[i]
		budget -= wage_of(pi, m)
		keep.append(m)
		left.erase(m)
	var paid := 0
	for m in keep:
		paid += wage_of(pi, m)
	paid = max(0, paid - cut)
	p.gold -= paid
	for m in left:
		remove_merc(pi, m)
		add_fame(pi, -level(m))
		note("%s can't pay %s, who leaves the game (-%d fame)." % [p.name, mname(m), level(m)])
	note("%s pays %d gold in wages." % [p.name, paid])

## Expected resources from tonight's Production: fixed sources, plus revealed Work and
## Activate orders when include_orders. Not counted: optional choices (Trading Post,
## Forge, Old Shrine, Trade Charter) and the Counting Office's +2 (counted as +1).
func projected_production(pi: int, include_orders: bool) -> Dictionary:
	var p = players[pi]
	var out := {"gold": 0, "wood": 0, "stone": 0, "metal": 0}
	out.gold += Cards.GUILDS[p.guild].income + (8 if has_keep(pi, "kraken") else 0)
	for b in p.buildings:
		var bd: Dictionary = Cards.BUILDINGS[b]
		var cnt: int = p.buildings[b] - p.today.built.get(b, 0)
		if bd.prod != "":
			out[bd.prod] += cnt
		elif b == "warcamp" and p.today.conquered:
			out.gold += 2 * cnt
	var tile_prod := {"stipend": ["gold", 2], "lumber": ["wood", 1], "quarry": ["stone", 1], "mining": ["metal", 1]}
	for t in p.tiles:
		if tile_prod.has(t):
			out[tile_prod[t][0]] += tile_prod[t][1]
	var keep_prod := {"night_wood": "wood", "night_stone": "stone", "night_gold": "gold", "night_metal": "metal"}
	for k in p.keeps:
		if keep_prod.has(k):
			out[keep_prod[k]] += 1
	if has_relic(pi, "golden_idol"):
		out.gold += 2
	for m in garrison(pi):
		_add_res(out, gain_amounts(pi, m, "night"))
	if not include_orders:
		return out
	for j in n:
		for m in players[j].mercs:
			if m.order.get("t", "") != "work":
				continue
			var lid: String = m.order.loc
			var L: Dictionary = Cards.LOCS[lid].levels[loc_level(lid) - 1]
			if j == pi:
				var s := stats(pi, m)
				var w: Dictionary = L.w
				_add_res(out, w.get("base", {}))
				match w.k:
					"per":
						if w.res in out:
							var st: int = s.max() if w.stat == 3 else s[w.stat]
							out[w.res] += per(st, w.div) * w.get("mult", 1) + w.get("plus", 0)
					"bank":
						out.gold += min(per(p.gold, w.div), s[2])
					"chouse":
						if s[2] >= w.min:
							var cnt := 0
							for i in n:
								if w.scope == "all" or i == pi:
									cnt += players[i].locs.size()
							out.gold += cnt * w.mult
				_add_res(out, gain_amounts(pi, m, "work"))
				for o in p.mercs:
					if o != m:
						_add_res(out, gain_amounts(pi, o, "ally_work"))
			if owner_of(lid) == pi:
				for r in L.owner:
					if r in out:
						out[r] += L.owner[r]
				out.gold += p.buildings.get("office", 0)
				if has_relic(pi, "signet_ring"):
					out.gold += 1
	for m in p.mercs:
		if m.order.get("t", "") == "act":
			_add_res(out, gain_amounts(pi, m, "activate", {"group": p.mercs}))
	return out

func _add_res(out: Dictionary, add: Dictionary) -> void:
	for r in add:
		if r in out:
			out[r] += add[r]

# ------------------------------------------------------------------ build (called by UI / bots)

func discounted(pi: int, cost: Dictionary) -> Dictionary:
	var c := cost.duplicate()
	var t: Dictionary = players[pi].today
	if (t.mira_all or t.mira_next) and _total(c) > 1:
		var big := ""
		for r in c:
			if big == "" or c[r] > c[big]:
				big = r
		c[big] -= 1
	return c

func upgrade_cost(pi: int, lid: String) -> Dictionary:
	var lv := loc_level(lid)
	if lv >= 3:
		return {}
	return discounted(pi, Cards.LOCS[lid].levels[lv].up)

func wall_cost(pi: int, wid: String) -> Dictionary:
	return discounted(pi, Cards.WALLS[wid].cost)

func _built(pi: int) -> void:
	for m in players[pi].mercs:
		fire(pi, m, "build")
	changed.emit()

func _used_discount(pi: int) -> void:
	players[pi].today.mira_next = false

func do_upgrade(pi: int, lid: String, use_token := false) -> bool:
	var e := loc_entry(lid)
	if e.is_empty() or owner_of(lid) != pi or e.level >= 3:
		return false
	if use_token:
		if players[pi].tokens.upgrade <= 0:
			return false
		players[pi].tokens.upgrade -= 1
	else:
		var c := upgrade_cost(pi, lid)
		if not can_pay(pi, c):
			return false
		pay(pi, c)
		_used_discount(pi)
	e.level += 1
	note("%s upgrades %s to level %d." % [players[pi].name, lname(lid), e.level])
	_built(pi)
	return true

func do_wall(pi: int, lid: String, wid: String, use_token := false) -> bool:
	var e := loc_entry(lid)
	if e.is_empty() or owner_of(lid) != pi:
		return false
	if e.wall != "" and Cards.WALLS[e.wall].def >= Cards.WALLS[wid].def:
		return false
	if use_token:
		if wid != "stone" or players[pi].tokens.wall <= 0:
			return false
		players[pi].tokens.wall -= 1
	else:
		var c := wall_cost(pi, wid)
		if not can_pay(pi, c):
			return false
		pay(pi, c)
		_used_discount(pi)
	e.wall = wid
	note("%s builds a %s on %s." % [players[pi].name, Cards.WALLS[wid].name, lname(lid)])
	_built(pi)
	return true

func can_build(pi: int, bid: String) -> bool:
	var b: Dictionary = Cards.BUILDINGS[bid]
	return (b.guild == "" or b.guild == players[pi].guild) and can_pay(pi, b.cost)

func do_build(pi: int, bid: String) -> bool:
	if not can_build(pi, bid):
		return false
	pay(pi, Cards.BUILDINGS[bid].cost)
	players[pi].buildings[bid] = players[pi].buildings.get(bid, 0) + 1
	players[pi].today.built[bid] = players[pi].today.built.get(bid, 0) + 1   # produces from next Night
	note("%s builds a %s." % [players[pi].name, Cards.BUILDINGS[bid].name])
	_built(pi)
	return true

func do_equip(pi: int, item: String, uid: int) -> bool:
	var m := find_merc(pi, uid)
	if m.is_empty() or not item in players[pi].stash or m.equip.size() >= slots(m):
		return false
	players[pi].stash.erase(item)
	m.equip.append(item)
	changed.emit()
	return true

func do_unequip(pi: int, uid: int, item: String) -> bool:
	var m := find_merc(pi, uid)
	if m.is_empty() or not item in m.equip:
		return false
	m.equip.erase(item)
	players[pi].stash.append(item)
	changed.emit()
	return true

# ------------------------------------------------------------------ end

func end_game() -> void:
	game_over = true
	phase = "Game over"
	final_scores = []
	for pi in n:
		var p = players[pi]
		var lv := 0
		for l in p.locs:
			lv += l.level
		var ml := 0
		for m in p.mercs:
			ml += level(m)
		var res := per(p.gold, 5) + per(p.wood, 4) + per(p.stone, 3) + per(p.metal, 2)
		final_scores.append({"fame": p.fame, "locs": lv, "mercs": ml, "res": res, "total": p.fame + lv + ml + res})
	var order_list := range(n)
	order_list.sort_custom(func(a, b):
		if final_scores[a].total != final_scores[b].total:
			return final_scores[a].total > final_scores[b].total
		if players[a].legends != players[b].legends:
			return players[a].legends > players[b].legends
		return prio_rank(a) < prio_rank(b))
	winner = order_list[0]
	note("=== Game over ===")
	for pi in n:
		var s: Dictionary = final_scores[pi]
		note("%s: %d fame + %d location levels + %d mercenary levels + %d from resources = %d." % [players[pi].name, s.fame, s.locs, s.mercs, s.res, s.total])
	note("%s wins!" % players[winner].name)
	changed.emit()

# ------------------------------------------------------------------ bot (random legal play, used for tests and solo practice)

func bot_answer(req: Dictionary):
	var pi: int = req.player
	match req.kind:
		"pick":
			return rng.randi_range(0, req.options.size() - 1)
		"amounts":
			return null
		"first_bid":
			var best_uid: int = req.mercs[0]
			for uid in req.mercs:
				if _merc_score(row_merc(uid)) > _merc_score(row_merc(best_uid)):
					best_uid = uid
			return {"uid": best_uid, "amount": Cards.MERCS[row_merc(best_uid).id].bid}
		"morning":
			return _bot_morning(pi)
		"build":
			_bot_build(pi)
			return null
	return null
	return null

# ------------------------------------------------------------------ bot
## The bot plans instead of choosing at random: it sends the smallest team that can complete the most
## valuable quest, conquers a row location when a small group is strong enough, keeps a defender when it
## owns locations, sends everyone else to their most productive Work or Activate, bids on the best-value
## mercenary and an affordable location while keeping gold for wages, and builds production.
## ponytail: one-turn greedy heuristics, no lookahead; good enough as a sparring partner.

const _VAL := {"gold": 1.0, "wood": 1.5, "stone": 1.5, "metal": 2.0, "fame": 3.0, "xp": 1.0}

func _value(d: Dictionary) -> float:
	var v := 0.0
	for r in d:
		if _VAL.has(r):
			v += _VAL[r] * d[r]
	return v

func _merc_score(m: Dictionary) -> float:
	return float(power(-1, m)) / max(1, Cards.MERCS[m.id].bid)

func _quest_value(q: String, team: Array) -> float:
	var d := qdef(q)
	var r: Dictionary = d.reward
	var v: float = _value(r)
	v += (4.0 if r.has("item") else 0.0) + (10.0 if r.has("loc") else 0.0) + (5.0 if r.has("keep") else 0.0)
	return v - _value(d.get("pay", {}))

func _bot_morning(pi: int) -> Dictionary:
	var p = players[pi]
	var orders := {}
	var free: Array = p.mercs.duplicate()
	for m in p.mercs:
		m.order = {}
	# 1. quests: best value per mercenary, smallest team that completes it
	while true:
		var best_q := ""
		var best_team := []
		var best_v := 0.0
		for q in quest_row + legends:
			var team := quest_feasible(pi, q, free)
			if team.is_empty():
				continue
			var v := _quest_value(q, team) / team.size()
			if v > best_v:
				best_v = v
				best_q = q
				best_team = team
		if best_q == "":
			break
		for m in best_team:
			orders[m.uid] = {"t": "quest", "q": best_q}
			m.order = orders[m.uid]
			free.erase(m)
	# 2. conquest of a row location with at most 2 mercenaries
	var by_power := free.duplicate()
	by_power.sort_custom(func(a, b): return attack_power(pi, [a]) > attack_power(pi, [b]))
	for lid in loc_row:
		var grp := []
		for m in by_power:
			if grp.size() >= 2:
				break
			grp.append(m)
			var wm := 0
			for g in grp:
				wm += block_sum(pi, g, "attack", "wall", {"group": grp})
			if attack_power(pi, grp) > loc_defense(lid, wm, wm >= 99):
				for g in grp:
					orders[g.uid] = {"t": "attack", "target": "L" + lid}
					g.order = orders[g.uid]
					free.erase(g)
					by_power.erase(g)
				grp = []
				break
		if not grp.is_empty():
			continue
	# 3. a defender when we own locations
	if not p.locs.is_empty() and free.size() >= 3:
		var d = free[0]
		for m in free:
			if power(pi, m) > power(pi, d):
				d = m
		orders[d.uid] = {"t": "defend"}
		d.order = orders[d.uid]
		free.erase(d)
	# 4. everyone else: the most productive Work or Activate
	for m in free:
		var base := _value(projected_production(pi, true))
		var best_o := {"t": "defend"}
		var best_v := 0.0
		for lid in free_work_locations(pi, m):
			m.order = {"t": "work", "loc": lid}
			var v := _value(projected_production(pi, true)) - base
			if v > best_v:
				best_v = v
				best_o = m.order
		if can_activate(m):
			m.order = {"t": "act"}
			var v := _value(projected_production(pi, true)) - base
			for b in blocks(m, "activate"):
				if b.get("do", "") != "gain":
					v += 1.5 * b.get("n", 1)
			if v > best_v:
				best_v = v
				best_o = m.order
		m.order = best_o
		orders[m.uid] = best_o
	for m in p.mercs:
		m.order = {}
	# 5. bids, keeping gold for tonight's wages
	var bids_out := {}
	var left: int = p.gold - wages_due(pi) - 2
	var merc_cap := 5
	for q in legends:
		merc_cap = max(merc_cap, qdef(q).get("min_mercs", 0))
	if p.mercs.size() < merc_cap and not merc_row.is_empty():
		var bm: Dictionary = merc_row[0]
		for m in merc_row:
			if _merc_score(m) > _merc_score(bm):
				bm = m
		var k := "M%d" % bm.uid
		var amt := bid_min(k, pi) + (1 if left >= bid_min(k, pi) + 4 else 0)
		if amt <= left:
			bids_out[k] = amt
			left -= amt
	var cheapest := ""
	for lid in loc_row:
		if cheapest == "" or bid_min("L" + lid, pi) < bid_min("L" + cheapest, pi):
			cheapest = lid
	if cheapest != "" and bid_min("L" + cheapest, pi) <= left:
		bids_out["L" + cheapest] = bid_min("L" + cheapest, pi)
	return {"orders": orders, "bids": bids_out}

func _bot_build(pi: int) -> void:
	var p = players[pi]
	var reserve := wages_due(pi) + 1
	var ok := func(cost: Dictionary) -> bool: return can_pay(pi, cost) and p.gold - cost.get("gold", 0) >= reserve
	for it in p.stash.duplicate():
		for m in p.mercs:
			if do_equip(pi, it, m.uid):
				break
	for l in p.locs.duplicate():
		if p.tokens.upgrade > 0 or (l.level < 3 and ok.call(upgrade_cost(pi, l.id))):
			do_upgrade(pi, l.id, p.tokens.upgrade > 0)
		if l.wall == "":
			for w in ["iron", "stone", "wooden"]:
				if (p.tokens.wall > 0 and w == "stone") or ok.call(wall_cost(pi, w)):
					if do_wall(pi, l.id, w, p.tokens.wall > 0 and w == "stone"):
						break
	# production buildings: the resource we hold least of, gold first while it is short
	for _k in 3:
		var want := ["stall"]
		if p.gold >= reserve + 6:
			var low := ["sawmill", "stoneworks", "smelter"]
			low.sort_custom(func(a, b): return p[Cards.BUILDINGS[a].prod] < p[Cards.BUILDINGS[b].prod])
			want = low + ["stall"]
		if p.guild == "GL" and p.locs.size() >= 2:
			want.push_front("office")
		var built := false
		for b in want:
			if can_build(pi, b) and ok.call(Cards.BUILDINGS[b].cost) and do_build(pi, b):
				built = true
				break
		if not built:
			break
