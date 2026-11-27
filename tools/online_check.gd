extends SceneTree
## Online play check: a host and a guest UI in one process, linked by an in-memory stand-in for
## web/net.js, play several rounds by clicking like ui_smoke.gd. Checks that the guest's board
## mirrors the host's and that each side only acts on its own requests.
## Run: godot --headless --path . --script res://tools/online_check.gd

class FakeJS:
	var other: FakeJS
	var ui: Control
	func host(_a, _b) -> void:
		ui.net.status.emit.call_deferred("code:TESTS")
	func join(_c, _a, _b) -> void:
		ui.net.status.emit.call_deferred("connected")
	func send(s: String) -> void:
		if other.ui.net:
			other.ui.net._on_msg.call_deferred(s)

var host: Control
var guest: Control
var frames := 0
var fails := 0
var acted := [0, 0]

func _initialize() -> void:
	var scene := load("res://src/scenes/main/main.tscn")
	host = scene.instantiate()
	guest = scene.instantiate()
	root.add_child(host)
	root.add_child(guest)
	var hj := FakeJS.new()
	var gj := FakeJS.new()
	hj.ui = host
	gj.ui = guest
	hj.other = gj
	gj.other = hj
	host.net_js = hj
	guest.net_js = gj

func _find(n: Node, cls: String, out: Array) -> void:
	for c in n.get_children():
		if c.is_class(cls) and not c.is_queued_for_deletion():
			out.append(c)
		_find(c, cls, out)

func _buttons(n: Node) -> Array:
	var all := []
	_find(n, "Button", all)
	return all.filter(func(b): return not b is OptionButton and not b is CheckBox and b.is_visible_in_tree() and not b.disabled)

func _press(n: Node, prefix: String) -> bool:
	for b in _buttons(n):
		if b.text.begins_with(prefix):
			b.pressed.emit()
			return true
	return false

func _menu_pick_first_enabled(main: Control) -> void:
	var pms := []
	_find(main, "PopupMenu", pms)
	for pm in pms:
		for i in pm.item_count:
			if not pm.is_item_disabled(i):
				pm.id_pressed.emit(pm.get_item_id(i))
				pm.hide()
				return
		pm.hide()

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		host._go_online("Ann", "")
	if frames == 6:
		guest._go_online("Bob", "tests")
	if frames % 4 != 0 or host.g == null or guest.g == null or guest.g.players.is_empty():
		return frames > 400 and host.g == null and _done("never started")
	var g: Game = host.g
	if g.round_num > 8 or g.game_over or frames > 60000:
		var same: bool = var_to_str(g.players) == var_to_str(guest.g.players) and g.merc_row == guest.g.merc_row and g.log_lines == guest.g.log_lines
		check(same, "guest board differs from host board")
		check(guest.g.players[1].name == "Bob" and g.players[0].name == "Ann", "names")
		check(acted[0] > 5 and acted[1] > 5, "both sides acted %s" % [acted])
		check(g.round_num > 8 or g.game_over, "reached round %d only" % g.round_num)
		print("guest log lines with Bob building: ", g.log_lines.filter(func(l): return l.begins_with("Bob builds") or l.begins_with("Bob upgrades")).size())
		return _done("round %d, phase %s, actions host %d guest %d" % [g.round_num, g.phase, acted[0], acted[1]])
	for i in 2:
		var ui: Control = [host, guest][i]
		if ui.mode != "":
			check(ui.mode_pi == ui.me, "a side got the other player's request")
			_drive(ui)
			acted[i] += 1
			return false
	for i in 2:
		var ui: Control = [host, guest][i]
		if not _buttons(ui.bar).is_empty():
			check(g.pending.get("player", -1) == ui.me, "buttons for a request that isn't mine")
			for pref in ["No offer", "Decline", "Sell nothing", "Don't", "Skip", "Nobody"]:
				if _press(ui.bar, pref):
					acted[i] += 1
					return false
			var bs := _buttons(ui.bar)
			bs[(frames / 4) % bs.size()].pressed.emit()
			acted[i] += 1
			return false
	return false

func _done(msg: String) -> bool:
	print("Online check: ", msg)
	print("FAILS: ", fails)
	return true

func _drive(main: Control) -> void:
	var g: Game = main.g
	match main.mode:
		"first_bid":
			if main.draft_bids.is_empty():
				main._on_card({"k": "rowmerc", "uid": g.merc_row[0].uid})
				_press(main, "Place bid")
			else:
				_press(main.bar, "Confirm bid")
		"morning":
			var p: Dictionary = g.players[main.mode_pi]
			if not p.mercs.is_empty() and main.draft_orders.values().all(func(o): return o.t == "defend"):
				main._on_card({"k": "merc", "pi": main.mode_pi, "uid": p.mercs[0].uid})
				_menu_pick_first_enabled(main)
				var lid: String = p.locs[0].id if not p.locs.is_empty() else g.loc_row[0]
				main._on_card({"k": "loc" if not p.locs.is_empty() else "rowloc", "pi": main.mode_pi, "lid": lid})
				if not g.merc_row.is_empty():
					main._on_card({"k": "rowmerc", "uid": g.merc_row[0].uid})
					_press(main, "Place bid")
				for q in g.quest_row + g.legends:
					if main._quest_lit(q):
						main._on_card({"k": "quest", "q": q})
						for m in g.quest_feasible(main.mode_pi, q, p.mercs):
							if not m.uid in main.team.sel:
								main._on_card({"k": "merc", "pi": main.mode_pi, "uid": m.uid})
						main._confirm_team()
						break
				return
			_press(main.bar, "Confirm orders")
		"build":
			if frames % 8 == 0:
				main._on_card({"k": "guild", "pi": main.mode_pi})
				_menu_pick_first_enabled(main)
			_press(main.bar, "Done building")
