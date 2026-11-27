# GuildMasters

Godot 4.6 project. Digital hot-seat version of the GuildMasters board game; the
design PDFs (rulebook, cards, player aid, tokens) live one folder up.

## Codebase map

- `src/game/cards.gd` (`Cards`): all card data as consts, transcribed from the
  Card Library. Mercenary abilities per level are already accumulated
  (replaced abilities removed). Balance tweaks go here.
- `src/game/game.gd` (`Game`, RefCounted): the whole rules engine, UI-agnostic.
  `run()` loops Dawn → Morning → Noon → Evening → Night. Any player decision
  goes through `ask()` (coroutine): bots answer inline via `bot_answer()`,
  humans via the `need_choice` signal and `provide(answer)`. Request kinds:
  `pick`, `amounts`, `first_bid`, `morning`, `build`. Functions that ask must be
  awaited all the way up.
- `src/scenes/main/main.gd`: the only scene; builds all UI in code and re-renders
  the board on `changed`. `morning`, `first_bid` and `build` requests switch a
  `mode`: cards become clickable (`_interactive()` decides, everything else is
  dimmed), clicks open popups (`_action_menu`, `_bid_popup`), and Work/Quest/
  Attack orders go through `targeting`. Other requests (`pick`, `amounts`) use the
  bottom bar. `fmt()` turns rules text into bbcode with icons from
  `assets/icons/`. Secret requests get a pass-the-device cover.
- `assets/cards/<mercs|locs|items|quests|guilds>/<card id>.svg`: one picture per card, shown in the
  card header via `_card(..., art)` / `card_art()` in main.gd. A new card id without an SVG just shows no picture.
- Ability blocks: mercenary `abil` (per level) and equipment `abil` are lists of
  {when, do, n, per, div, res, code}; vocabulary in `Cards.TRIGGERS/EFFECTS/PERS/SPECIALS`, text from
  `Cards.abil_text()`. The engine reads them through `Game.blocks/amount/block_sum/gain_amounts/fire`.
- `src/scenes/rules/rulebook.gd`: in-game rulebook (Rules button on the setup screen and top bar). One `_sN()`
  function per section; example cards use main.gd's own card bodies on a blank Game. If you change a rule,
  update its section. `tools/rules_check.gd` opens every section (GM_SHOT=dir saves screenshots).
- `src/scenes/editor/editor.gd`: in-game card editor (opened from the setup screen). Card tables in
  `cards.gd` are `static var`s; edits are a diff saved by `Cards.save_edits()` to `data/card_edits.txt`
  and applied at start-up by `Cards.load_edits()`. `tools/editor_check.gd` tests it.
- `tools/sim_check.gd`: rule assertions + 40 seeded bot-vs-bot games.
  `tools/ui_smoke.gd`: drives the real UI for 8 rounds. Run both headless after
  any rules change.
- Online play (web build only): `src/game/online.gd` (`Online`) + `web/net.js` (PeerJS, peer to peer, room
  codes; `?local` in the URL links two tabs of one browser instead). The host's browser runs the Game and
  sends the guest a state snapshot (`Online.SYNC` vars + new log lines) on every `changed`, plus every
  request; the guest answers its own requests and sends Build actions (`_act()` in main.gd), which the host
  runs. If you add a Game var the board shows, add it to `Online.SYNC`. `tools/online_check.gd` links a host
  and a guest UI in one process and plays 8 rounds. Web export: preset "Web" in `export_presets.cfg`
  (no threads, so plain static hosting works), then copy `web/*.js` next to `index.html`.
- `docs/rules-gaps.md`: every ambiguous rule and the reading the engine uses.
  Update it when a reading changes.
