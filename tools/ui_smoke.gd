extends SceneTree
## UI smoke test: opens the main scene, starts a hot-seat game and plays through it by
## clicking cards and popup menus like a person would, for several rounds.
## Run: godot --headless --path . --script res://tools/ui_smoke.gd

var main: Control
var frames := 0
var shot_path := OS.get_environment("GM_SHOT")   # optional: save a screenshot of Morning here
var shot_done := false
var quests_sent := 0

func _initialize() -> void:
	main = load("res://src/scenes/main/main.tscn").instantiate()
	root.add_child(main)

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

func _menu_pick_first_enabled() -> void:
	var pms := []
	_find(main, "PopupMenu", pms)
	for pm in pms:
		for i in pm.item_count:
			if not pm.is_item_disabled(i):
				pm.id_pressed.emit(pm.get_item_id(i))
				pm.hide()
				return
		pm.hide()

func _process(_d: float) -> bool:
	frames += 1
	if frames % 4 != 0:
		return false
	var g: Game = main.g
	if g != null and (g.round_num > 8 or g.game_over):
		print("UI smoke reached round %d, phase %s, quest teams sent %d" % [g.round_num, g.phase, quests_sent])
		return true
	if frames > 40000 or (frames > 50 and main.get_script() == null):
		print("UI smoke timeout")
		return true
	if main.cover.visible:
		main.cover_btn.pressed.emit()
		return false
	if g == null:
		_press(main.bar, "Start game")
		return false
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
				_menu_pick_first_enabled()          # "Work at a location…" -> targeting
				var lid: String = p.locs[0].id if not p.locs.is_empty() else g.loc_row[0]
				main._on_card({"k": "loc" if not p.locs.is_empty() else "rowloc", "pi": main.mode_pi, "lid": lid})
				if not g.merc_row.is_empty():
					main._on_card({"k": "rowmerc", "uid": g.merc_row[0].uid})
					_press(main, "Place bid")
				# quest team picker: click a lit quest, pick its team, confirm (only possible when it meets the needs)
				for q in g.quest_row + g.legends:
					if main._quest_lit(q):
						main._on_card({"k": "quest", "q": q})
						for m in g.quest_feasible(main.mode_pi, q, p.mercs):
							if not m.uid in main.team.sel:
								main._on_card({"k": "merc", "pi": main.mode_pi, "uid": m.uid})
						if not main._team_problems().is_empty():
							print("UI smoke: feasible team rejected")
						main._confirm_team()
						quests_sent += 1
						break
				if shot_path != "" and not shot_done and g.round_num >= 3:
					shot_done = true
					main._refresh()
					return false
				return false
			if shot_path != "" and shot_done and g.round_num >= 3 and frames % 40 == 0:
				root.get_texture().get_image().save_png(shot_path)
				print("saved ", shot_path)
				shot_path = ""
			if shot_path == "" or not shot_done:
				var ev := InputEventKey.new()
				ev.keycode = KEY_SPACE
				ev.pressed = true
				main._input(ev)   # Space confirms orders
		"build":
			if frames % 8 == 0:
				main._on_card({"k": "guild", "pi": main.mode_pi})
				_menu_pick_first_enabled()
			_press(main.bar, "Done building")
		_:
			var bs := _buttons(main.bar)
			for pref in ["No offer", "Decline", "Sell nothing", "Don't", "Skip", "Nobody"]:
				if _press(main.bar, pref):
					return false
			if not bs.is_empty():
				bs[(frames / 4) % bs.size()].pressed.emit()
	return false
