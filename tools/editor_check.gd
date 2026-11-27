extends SceneTree
## Headless check of the card editor: every tab renders, the form gives back every card
## unchanged, and edits round-trip through save / load / reset.
## Run: godot --headless --path . --script res://tools/editor_check.gd

var main: Control
var f := 0
var fails := 0

func _initialize() -> void:
	main = load("res://src/scenes/main/main.tscn").instantiate()
	root.add_child(main)

func _check(c: bool, what: String) -> void:
	if not c:
		print("CHECK FAILED: ", what)
		fails += 1

func _process(_d: float) -> bool:
	f += 1
	if f < 3:
		return false
	main._open_editor()
	var ed: Control = main.get_child(main.get_child_count() - 1)
	await process_frame
	for t in Cards.TABLES:
		ed.tab = t
		ed._render()
		_check(ed.grid.get_child_count() > 0, "tab %s shows cards" % t)
		var tb := Cards.table(t)
		for id in tb:
			var built: Array = ed._field("", tb[id])
			_check(var_to_str(built[1].call()) == var_to_str(tb[id]), "form round-trip %s/%s:\n%s\n%s" % [t, id, var_to_str(built[1].call()), var_to_str(tb[id])])
			built[0].free()
		ed._open_form(tb.keys()[0], tb[tb.keys()[0]], false)
		ed._close_dialog()
	# an ability built in the editor changes the rules and the card text
	ed.tab = "MERCS"
	var kael_form: Array = ed._field("abil", Cards.MERCS.kael.abil)
	Cards.MERCS.kael.abil = kael_form[1].call()
	Cards.MERCS.kael.abil[0].append({"when": "dawn", "do": "gain", "res": "gold", "n": 2})
	Cards.refresh_texts()
	_check(Cards.MERCS.kael.text[0].contains("Dawn: +2 gold"), "card text follows the blocks: " + Cards.MERCS.kael.text[0])
	var gm := Game.new()
	gm.setup(["A", "B"], [true, true], 5)
	var k := gm.new_merc("kael", 0)
	gm.players[0].mercs.append(k)
	var before: int = gm.players[0].gold
	gm.fire(0, k, "dawn")
	_check(gm.players[0].gold == before + 2, "a Dawn block gives gold")
	kael_form[0].free()
	Cards.apply_edits({})
	# edit, save, reload, reset
	Cards.MERCS.varn.bid = 9
	Cards.RULES.rules.loc_def = [6, 10, 14]
	Cards.sync_rules()
	_check(Cards.save_edits() == OK, "save edits")
	var saved := Cards.current_edits()
	_check(saved.has("MERCS") and saved.MERCS.size() == 1 and saved.has("RULES"), "edits are a diff: %s" % [saved.keys()])
	Cards.apply_edits({})
	_check(Cards.MERCS.varn.bid == 3 and Cards.LOC_DEF == [5, 9, 13], "reset restores defaults")
	Cards.load_edits()
	_check(Cards.MERCS.varn.bid == 9 and Cards.LOC_DEF == [6, 10, 14], "load applies saved edits")
	ed.tab = "ITEMS"
	ed._delete("iron_sword")
	_check(Cards.ITEMS.has("iron_sword"), "a card used by a quest can't be deleted")
	Cards.apply_edits({})
	Cards.save_edits()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Cards.edits_path()))
	ed.closed.emit()
	ed.queue_free()
	_check(main.g == null, "closing the editor leaves no game behind")
	print("editor check failures: %d" % fails)
	quit(1 if fails > 0 else 0)
	return true
