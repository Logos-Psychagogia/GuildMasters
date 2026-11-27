class_name Online
extends RefCounted
## Online play (web build only): two browsers linked through web/net.js.
## The host runs the Game; the guest mirrors the host's state, answers its own requests and
## sends its Build actions. Messages are Dictionaries sent as base64 Variants without objects.

signal message(d: Dictionary)
signal status(s: String)   # "code:ABCDE", "connected", "closed", "error:..."

## Game vars the guest mirrors (everything the board shows; the log goes separately).
const SYNC := ["n", "bots", "round_num", "phase", "priority", "merc_deck", "merc_row", "loc_deck", "loc_discard",
	"loc_row", "row_walls", "restocked", "quest_deck", "quest_discard", "quest_row", "legends", "legends_done",
	"item_deck", "fame_tiles", "fame_taken", "pending_tiles", "bids", "conquests", "bought", "completed",
	"cancelled_locs", "players", "next_uid", "game_over", "final_scores", "winner"]
const BUILD_FNS := ["do_upgrade", "do_wall", "do_build", "do_equip", "do_unequip"]

var is_host := false
var _js
var _cbs := [null, null]   # the JS callbacks (kept alive here)

static func available() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.get_interface("gmnet") != null

## js: the window.gmnet object, or a stand-in with host/join/send (tools/online_check.gd).
func _init(js = null) -> void:
	_js = js if js != null else JavaScriptBridge.get_interface("gmnet")
	if OS.has_feature("web"):
		_cbs = [JavaScriptBridge.create_callback(func(a): _on_msg(str(a[0]))), JavaScriptBridge.create_callback(func(a): status.emit(str(a[0])))]

func host() -> void:
	is_host = true
	_js.host(_cbs[0], _cbs[1])

func join(code: String) -> void:
	_js.join(code, _cbs[0], _cbs[1])

func send(d: Dictionary) -> void:
	_js.send(Marshalls.variant_to_base64(d))

func _on_msg(s: String) -> void:
	var v = Marshalls.base64_to_variant(s, false)
	if v is Dictionary:
		message.emit(v)

static func snapshot(g: Game, log_from: int) -> Dictionary:
	var s := {"t": "state", "log_from": log_from, "log": g.log_lines.slice(log_from)}
	for k in SYNC:
		s[k] = g.get(k)
	return s

## Guest side: copy the host's state into the local Game. Returns the new log lines.
static func apply(g: Game, s: Dictionary) -> Array:
	for k in SYNC:
		if s.has(k):
			g.set(k, s[k])
	var from: int = s.get("log_from", 0)
	if from == 0:
		g.log_lines = []
	var fresh: Array = s.get("log", [])
	g.log_lines.append_array(fresh)
	return fresh

## Host side: an answer from the guest, made safe for the request it answers (null = invalid).
static func sanitize(req: Dictionary, a):
	match req.get("kind", ""):
		"pick":
			return clampi(int(a), 0, req.options.size() - 1) if (a is int or a is float) else 0
		"amounts":
			if not a is Dictionary:
				return null
			var out := {}
			for fd in req.fields:
				out[fd.key] = clampi(int(a.get(fd.key, 0)), fd.min, fd.max)
			return out
		"morning":
			var orders := {}
			var bids := {}
			if a is Dictionary and a.get("orders") is Dictionary and a.get("bids") is Dictionary:
				for uid in a.orders:
					if uid is int and a.orders[uid] is Dictionary:
						orders[uid] = a.orders[uid]
				for k in a.bids:
					if k is String and a.bids[k] is int:
						bids[k] = a.bids[k]
			return {"orders": orders, "bids": bids}
		"first_bid":
			return a if a is Dictionary else {}
	return null
