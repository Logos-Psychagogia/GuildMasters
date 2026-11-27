extends SceneTree
## Opens the rulebook and shows every section (errors show up in the output).
## GM_SHOT=dir saves a screenshot of each section there.
## Run: godot --path . -s tools/rules_check.gd

var main: Control
var rb: Control
var frames := 0
var sec := 0
var count := 0
var shot_dir := OS.get_environment("GM_SHOT")

func _initialize() -> void:
	main = load("res://src/scenes/main/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		main._open_rules()
		rb = main.get_child(main.get_child_count() - 1)
		count = rb.SECTIONS.size()
	if frames > 5 and frames % 10 == 0:
		if shot_dir != "":
			root.get_texture().get_image().save_png("%s/rules_%02d.png" % [shot_dir, sec])
		sec += 1
		if sec == count:
			rb._close()
			# right-click level popups on a live game
			main.g = Game.new()
			main.g.setup(["A", "B"], [false, false], 1)
			main.g.merc_row.append(main.g.new_merc(Cards.MERCS.keys()[0], 4))
			main.g.loc_row.append(Cards.LOCS.keys()[0])
			main._refresh()
			main._show_levels("MERCS", main.g.merc_row[0].id, 2)
			main._show_levels("LOCS", main.g.loc_row[0], 1)
			for m in main.g.merc_row:
				assert(main._levels_ref({"k": "rowmerc", "uid": m.uid})[1] == m.id)
			return false
		if sec > count:
			print("Rulebook OK: %d sections, level popups OK" % (sec - 1))
			return true
		if sec < count:
			rb._go(sec)
	return false
