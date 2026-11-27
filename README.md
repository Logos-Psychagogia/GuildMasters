# GuildMasters

Godot 4.6 digital playtest build

A hot-seat, 2-player digital version of GuildMasters, built from the Rulebook, Card Library, Player Aid and Tokens sheets (Nov 23, 2026 versions). Placeholder visuals; rules fidelity first.

## Open and run

1. Use Godot **4.6** (standard build, no .NET needed). Earlier 4.x versions will likely work but were not tested.
2. In the Godot Project Manager choose **Import**, select `project.godot` in this folder, then **Import & Edit**.
3. Press **F5** (or the ▶ Run button).

From a terminal you can also run: `godot --path Guild-Masters`.

## How to play

- On the setup panel, type both names and press **Start game**. Guilds, legendary quests and the priority token are dealt at random. Nobody starts with a location: locations for sale can be worked by anyone (1 mercenary per player each) and are owned by buying or conquering them. Tick "Player 2 is a random bot" to learn the interface alone.
- **Left:** legendary quests, the quest, location and mercenary rows, and the item deck. **Centre:** both guilds (resources, buildings, relics, kept bonuses, mercenaries with level, XP, stats, wages and orders, locations with defense and upgrade costs). **Right:** the game log, which narrates every resolution step. **Bottom:** whatever the current player has to decide. Each guild shows its expected production (+N/night) above every resource, and any underlined card name can be hovered to preview that card.
- **Morning is secret:** a "Pass the device" screen hides the board between players. Click one of your mercenaries to open its order menu (Work, Activate, Quest, Attack, Defend). For Work, Quest and Attack, the valid targets light up and everything else dims, so click a location, quest or rival guild. Click a mercenary or location for sale to place, change or remove a bid. Then press **Confirm orders and bids**, or **Pass** to give no orders and place no bids. Orders stay hidden until both players have confirmed.
- **Dimmed cards** are ones you can't act on right now. Greyed-out menu lines are actions you can't take (no ability, can't afford).
- Noon, Evening and Night resolve automatically in rule order. When someone must choose (which location to conquer, retreat offers, Trading Post sales, Forge or Old Shrine items, War Horn, Ancient Map, fame tiles), the bottom bar asks that player by name.
- **Quests:** in the Morning, quests that some of your mercenaries could complete light up. Click one, then click your mercenaries to build the team; **Confirm team** only unlocks when the team meets every requirement.
- **Space** presses the main button of the step: confirm orders and bids, confirm the team, confirm the bid, done building, or "I'm ready".
- **The bot** plans each turn: the smallest team that completes the most valuable quest, a conquest when a small group is strong enough, a defender when it owns locations, the most productive Work or Activate for everyone else, value bids that keep gold for wages, and production buildings.
- **Night** runs: XP from card effects (there is no automatic nightly XP), then your **Build** step, then Production, then Wages (if you can't pay everyone, you pick who stays).
- **Build:** click your locations to upgrade them or build walls, click your guild panel to construct guild buildings, and click a mercenary to equip or unequip items. Press **Done building** when you're finished.
- The game ends after the Night in which the last revealed legendary quest is completed, and final scoring is shown. **End game now & score** (top right) stops a playtest early and applies final scoring.

## Play online (web version)

The web build adds **Play online with a friend** to the start screen. One player types a name and presses
**Host a game**, gets a 5-letter room code and sends it to the friend; the friend opens the same link, types
a name and the code and presses **Join**. Each player only sees and answers their own decisions, Morning
orders and bids stay secret until both have confirmed, and the game runs in the host's browser, so the host
must keep the page open (a guest who drops can press **Rejoin**). Browsers connect directly to each other;
the free PeerJS server only introduces them.

To rebuild it: `godot --headless --export-release Web build/web/index.html`, then `cp web/*.js build/web/`,
and upload `build/web` to any static host.

## Files

- `src/game/cards.gd`: every card transcribed (18 mercenaries, 18 locations, 18 items, 28 quests, 4 legendaries, buildings, walls, fame tiles). Edit numbers here to test balance changes.
- `src/game/game.gd`: the rules engine (no UI code).
- `src/scenes/main/`: the hot-seat interface (main scene).
- `assets/icons/`: SVG icons for resources, stats and orders.
- `tools/sim_check.gd`: rule checks plus 40 bot-vs-bot games. `godot --headless --path . --script res://tools/sim_check.gd`
- `tools/ui_smoke.gd`: clicks through 8 rounds of the real interface. Run it the same way.
- `docs/rules-gaps.md`: design changes made since the rulebook, how this build reads the ambiguous rules, and balance flags.

## Rulebook

Click **Rules** on the start screen or in the top bar during a game. It covers the goal, setup, a round, orders, each kind of card (with example cards and numbered callouts), attacks, bids and retreat offers, the Night, the fame track, scoring and controls. Numbers and example cards are read from the card tables, so editor changes show up there too. Esc or Back closes it.

## Card editor

Click **Editor** next to Start game. There is one tab per kind of card (mercenaries, guilds, items, locations, quests, legendary quests, buildings, walls, fame track tiles, kept bonuses) plus **Rules numbers** (location defense, restock walls, fame spaces). You can search, filter by guild, and see how many quests and locations are available each round. Each card can be edited, duplicated, deleted or restored to its default.

- Every change is saved at once to `data/card_edits.txt` when you run the game from the Godot editor (`user://card_edits.txt` in an exported build). That file is only what differs from the defaults in `src/game/cards.gd`, so you can commit it.
- **Export edits** copies all edits to the clipboard, and **Import edits** loads them back in. **Reset all edits** goes back to the defaults.
- **Mercenary and equipment abilities are built from blocks:** Trigger → Effect → Amount, each picked from a menu. The amount is a fixed number or "N per X" (Might, Skill, Intellect, relics you own, equipment carried, other mercenaries in the group, every D). The card text is written from the blocks. Four abilities stay in code and are picked as **Special**: work again (Fenwick), cheaper builds (Mira, two versions), and two equipment slots (Ulfgar).
- For relics, location work effects, kept bonuses and fame tiles, card text is only what players read: the rules run on the numbers and the "rules data" fields, so changing an effect's text alone does not change what it does. Use **Edit as text** in the edit window to add or remove fields.
