extends SceneTree
## Headless check: plays bot-vs-bot games and a few rule assertions.
## Run: godot --headless --path . --script res://tools/sim_check.gd

func _initialize() -> void:
	_run()

func _run() -> void:
	var fails := 0
	fails += _rules_checks()
	for s in range(1, 41):
		var g := Game.new()
		g.setup(["A", "B"], [true, true], s)
		g.max_rounds = 25
		await g.run()
		if not g.game_over:
			print("seed %d did not finish" % s)
			fails += 1
		elif s <= 3:
			for l in g.log_lines.slice(-4):
				print("  ", l)
		print("seed %d: rounds %d, legends done %d, winner %s, scores %s" % [s, g.round_num, g.legends_done.size(), g.players[g.winner].name, g.final_scores.map(func(x): return x.total)])
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)

func _check(cond: bool, what: String) -> int:
	if not cond:
		print("CHECK FAILED: ", what)
		return 1
	return 0

func _rules_checks() -> int:
	var f := 0
	var g := Game.new()
	g.setup(["A", "B"], [true, true], 7)
	var m := g.new_merc("varn", 0)          # M2 S1 I0
	g.players[0].guild = "IW"
	g.players[0].mercs.append(m)
	f += _check(g.attack_power(0, [m]) == 9, "Varn L1 Iron Wolves attack = (2+1)+1+0 + Might 3 = 7? got %d" % g.attack_power(0, [m])) if false else 0
	f += _check(g.attack_power(0, [m]) == 7, "Varn L1 IW attack power 7, got %d" % g.attack_power(0, [m]))
	m.xp = 3
	f += _check(g.level(m) == 2, "level 2 at 3 XP")
	m.xp = 10
	f += _check(g.level(m) == 3, "level 3 at 10 XP")
	var c := g.new_merc("corvina", 0)
	var b := g.new_merc("brenna", 0)
	g.players[1].mercs = [c, b]
	c.order = {"t": "defend"}
	b.order = {"t": "defend"}
	# Corvina 3 +1 (one other) = 4; Brenna 3 + Might 2 = 5
	f += _check(g.garrison_power(1) == 9, "garrison 9, got %d" % g.garrison_power(1))
	var k := g.new_merc("kael", 0)
	f += _check(g.quest_power(0, [k], "wolf_pack") == 4, "Kael alone 4")
	g.fame_tiles = {5: "treasure", 10: "builders", 20: "stipend", 30: "lumber", 50: "quarry"}
	var gold0: int = g.players[1].gold
	g.add_fame(1, 6)
	f += _check(g.players[1].gold == gold0 + 10 and g.fame_taken.get(5, -1) == 1, "treasure tile")
	g.add_fame(0, 6)
	f += _check(not "treasure" in g.players[0].tiles, "second player gets nothing")
	g.players[0].fame = 0
	g.players[1].fame = 3
	f += _check(g.tie_winner([0, 1]) == 0, "tie: less fame wins")
	g.players[1].fame = 0
	f += _check(g.tie_winner([0, 1]) == g.priority, "tie: priority holder")
	# defense with wall and ward stone
	g.players[1].locs.append({"id": "quarry", "level": 1, "wall": "stone"})
	var lid := "quarry"
	var base: int = Cards.LOC_DEF[0]
	f += _check(base == 5, "base defense 5 at level 1")
	f += _check(g.loc_defense(lid) == base + 5, "stone wall")
	f += _check(g.loc_defense(lid, 2) == base + 3, "rook -2")
	f += _check(g.loc_defense(lid, 0, true) == base, "ignore walls")
	g.players[1].relics.append("ward_stone")
	f += _check(g.loc_defense(lid) == base + 7, "ward stone")
	# restocked locations get walls: first n wooden, next n stone, then iron
	var g2 := Game.new()
	g2.setup(["A", "B"], [true, true], 3)
	f += _check(g2.players[0].locs.is_empty() and g2.players[1].locs.is_empty(), "no starting locations")
	var walls := []
	g2.round_num = 1
	for r in 5:
		g2.restock_location()
		walls.append(g2.row_walls[g2.loc_row[-1]])
	f += _check(walls == ["", "", "wooden", "wooden", "stone"], "restock walls %s" % [walls])
	var rl: String = g2.loc_row[0]
	f += _check(g2.loc_defense(rl) == 5, "first restocked location has no wall")
	f += _check(g2.loc_defense(g2.loc_row[2]) == 5 + 3, "third restocked location has a wooden wall")
	# one worker per player on an unowned location
	var w1 := g2.new_merc("tomas", 0)
	var w2 := g2.new_merc("ultor", 0)
	g2.players[0].mercs = [w1, w2]
	g2.apply_morning(0, {"orders": {w1.uid: {"t": "work", "loc": rl}, w2.uid: {"t": "work", "loc": rl}}, "bids": {}})
	f += _check(w1.order.t == "work" and w2.order.t == "defend", "second worker on unowned location refused")
	# pass: "none" orders are allowed
	g2.apply_morning(0, {"orders": {w1.uid: {"t": "none"}, w2.uid: {"t": "none"}}, "bids": {}})
	f += _check(w1.order.t == "none" and w2.order.t == "none", "passing gives no orders")
	# unpaid wages: lost mercenaries cost fame equal to their level
	w2.xp = 3
	g2.players[0].gold = 0
	g2.players[0].fame = 5
	g2.players[0].today.wage_cut = 0
	g2.wages(0)
	f += _check(g2.players[0].mercs.is_empty() and g2.players[0].fame == 5 - 3, "unpaid L1 + L2 cost 3 fame, got fame %d" % g2.players[0].fame)
	print("rule checks done, failures: %d" % f)
	var g3 := Game.new()
	g3.setup(["A", "B"], [true, true], 3)
	f += _check(g3.projected_production(0, false).gold == Cards.GUILDS[g3.players[0].guild].income, "fresh guild projects only its base income")
	var bid: String = Cards.BUILDINGS.keys().filter(func(k): return Cards.BUILDINGS[k].prod != "" and Cards.BUILDINGS[k].guild == "")[0]
	g3.players[0].gold = 50
	g3.players[0].wood = 50
	g3.players[0].stone = 50
	g3.players[0].metal = 50
	g3.do_build(0, bid)
	f += _check(g3.projected_production(0, false)[Cards.BUILDINGS[bid].prod] == (Cards.GUILDS[g3.players[0].guild].income if Cards.BUILDINGS[bid].prod == "gold" else 0), "a building built tonight does not produce tonight")
	g3.reset_today(0)
	f += _check(g3.projected_production(0, false)[Cards.BUILDINGS[bid].prod] >= 1, "the building produces from the next night")
	for q in Cards.QUESTS:
		f += _check(Cards.QUESTS[q].reward.get("xp", 0) >= 1, "quest %s gives XP" % q)
	var g4 := Game.new()
	g4.setup(["A", "B"], [true, true], 4)
	var w4 := g4.new_merc("kael", 0)   # Might 1: Arena pays only its base 2 gold
	g4.players[0].mercs.append(w4)
	var gold4: int = g4.players[0].gold
	g4.do_work(0, w4, "arena")
	f += _check(g4.players[0].gold == gold4 + 2, "Arena level I pays 2 gold base to a Might 1 worker, got %d" % (g4.players[0].gold - gold4))
	var g5 := Game.new()
	g5.setup(["A", "B"], [true, true], 6)
	# Wolf Pack: equal Power, Might decides; then fame; then priority
	f += _check(g5.contest_winner({0: [4, 2], 1: [4, 3]}) == 1, "second requirement breaks a Power tie")
	g5.players[0].fame = 5
	g5.players[1].fame = 2
	f += _check(g5.contest_winner({0: [4, 3], 1: [4, 3]}) == 1, "then the lowest fame wins")
	g5.players[0].gold = 9
	g5.players[1].gold = 4
	f += _check(g5.quest_contest_key(0, "loan", [])[0] == 9, "contracts compare reserves of the paid resource")
	return f
