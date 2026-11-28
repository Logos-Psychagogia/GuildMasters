# GuildMasters: rules gaps and balance flags

## Design changes (Nov 25, from playtest feedback)

These replace the rulebook and the printed cards in this build:

- **No starting locations.** Players start with gold only.
- **Unowned locations can be worked.** Locations in the row (in stock) belong to nobody, but any player may send **1 mercenary per location per day** there. Nobody gets the owner bonus. A player owns one by winning its auction or by conquering it, and only then collects the owner bonus.
- **Restocked locations come with a wall.** In an X-player game, the first X locations (the round 1 fill) have no wall, the next X get a Wooden Wall (+3), the next X a Stone Wall (+5), and every later one an Iron Wall (+7).
- **Walls:** one wall per location. Building a stronger wall replaces the current one. Conquest removes the wall, and the new owner may build one again.
- **Pass:** in Morning a player may pass, giving no orders and placing no bids. Passing mercenaries do nothing that day and are not in the garrison.
- **Night order:** XP and moving equipment, then Build, then Production as the last thing in the day, then Wages, then Reset.
- **Unpaid wages:** if you can't pay every wage after production, you choose which mercenaries to pay and keep. The others leave the game, and you lose 1 fame per level of each one.
- **No XP at Night.** Mercenaries (hired or in the row) no longer gain 1 XP each Night.
- **Quests give XP and more fame.** Every regular quest gives 1 more fame than printed. Legendary quests stay at 10 fame.
- **Shared quest XP (Nov 28).** A quest's XP is a total for the team, not per mercenary: the last round the quest can appear on (12 if open-ended, so 3 to 12), and 20 for legendary quests. It is split evenly (rounded down); the leftover goes 1 at a time to the team's lowest-XP mercenaries, and when fewer points are left than mercenaries tied for lowest, the player picks who gets them.
- **Kraken and Lich keeps (Nov 28).** Sunken treasure is +8 base gold production (was +3). Phylactery reads "Night: all your mercenaries gain 1 XP".
- **Locations cost much more.** Minimum bid = printed bid x2 + 4 (10 for Arena, Lumber Camp, Quarry, Tavern; 12 for Market Square, Trading Post, Barracks, Mess Hall, Training Grounds, Caravanserai, Iron Mine; 14 for Counting House, Old Shrine, Forge; 16 for Bank), plus 2 for a Wooden Wall, 4 for a Stone Wall, 6 for an Iron Wall on the location. Late locations therefore cost 16 to 22.
- **Golden Ledger:** its power is now "your minimum bid for locations is 3 gold lower" (it no longer gains 1 gold per owner bonus).
- **Counting Office (Golden Ledger building):** each owner bonus at a location you own gives +1 gold, per Counting Office you have. It replaces "+1 gold, or +2 if a rival worked at your location".
- **Every quest has its own requirement.** Besides Power, stat needs and payment, quests can need a minimum number of mercenaries (Escort the Pilgrims 2+, Bridge Repairs 2+, Haunted Crypt 2+, Siege of Blackstone 3+, The Kraken 3+) or allow only one (Mercenary Tournament, Shrine of the Saint). Stat needs were spread over Might, Skill and Intellect, so no two quests ask for the same thing.
- **Every location has a base production when worked**, paid on top of its stat-based effect, so working one is never worse than its wage: Arena 2 / 2 / 3 gold, Market Square 2 / 3 / 3 gold, Caravanserai 2 / 2 / 3 gold, Lumber Camp and Quarry 1 / 1 / 2 wood or stone, Iron Mine 1 / 1 / 2 metal, Tavern and Training Grounds 1 / 1 / 2 gold + 1 XP, Royal Mint 2 / 2 / 3 gold, Siege Workshop 1 / 1 / 2 metal, and 1 / 1 / 2 gold for every other location (Bank, Counting House, Trading Post, Old Shrine, Forge, Barracks, Mess Hall, Hall of Legends). The stat-based part is unchanged.
- **Legendary quests:** The Red Dragon 20 Power + Might 10; The Lich 20 Power + Intellect 10; The Kraken 30 Power + 8 or more mercenaries; The King's Citadel pays 30 gold, 20 wood, 10 stone and 5 metal.
- **Masterwork Commission** now gives one mercenary a level (like Veteran Training) instead of a permanent +1 stat.
- **Audit the Guild Hall** needs Intellect 4 and is only available until round 4.
- **Contested quests:** when several players send mercenaries to the same quest, compare each requirement in order. Monsters: Power, then each stat the quest needs. Contracts: each player's reserve of the resources the quest asks for, in the order listed (a contract with no payment compares its stat needs instead). Then the lowest fame, then the priority token. The loser may then be offered the retreat, as before.
- **Base defense is 5 / 9 / 13** at levels I / II / III for every location. This replaces the printed defense values.

How the build reads these changes (please confirm or correct):

- The 1-mercenary limit only applies to **unowned** locations. Owned locations still take any number of workers, from any player, as the rulebook says.
- A location **bought** at auction keeps its row wall. A **conquered** location loses its walls, whether it was conquered from the row or from a player, as the rulebook says for conquest.
- Attacking an unowned location: the attack power must be higher than its defense **including its wall**. Rook's wall reduction applies to row walls too.
- The new base defense also applies to the quest-reward locations (Royal Mint, Siege Workshop, Hall of Legends), which were printed with higher values.
- The location row still holds 1 location per player.
- With no XP at Night, a newly revealed mercenary starts at 0 XP instead of XP equal to the round (that rule only existed to catch up on missed Nights).
- Card effects that give XP at Night (War Camp, Brenna's garrison XP, the Lich keep bonus) still work; only the automatic +1 per Night is gone.
- XP now comes only from quests, those cards, Training Grounds and Tavern workers, and Veteran Training.
- Fenwick's "works again" and a contested-quest loser's new Work order also respect the 1-mercenary limit.


How the digital build reads the places where the Rulebook (Nov 23, 2026) is ambiguous or silent.

## Rules gaps

**Timing and phases**
1. **Round 1:** players only make their one secret mercenary bid. No location bids, and no orders, since nobody has mercenaries yet.
2. **Barracks and Siege Workshop** say "your garrison / attacks *today*", but Work resolves at Night, after Noon's attacks. This build applies those two Work bonuses at the start of Noon so they can matter. Their owner bonus is still paid at Night.
3. **Inside Production:** all Work orders first (priority order), then Activates, then base income, guild buildings, fame tiles, kept quest bonuses, relics and Night abilities. This lets the Counting Office see whether a rival worked at your locations. The **Bank's** "gold you have" is your gold at the moment the worker resolves.
    - Because Build now comes before Production, **Mira's** Activate discount is applied when Night starts, so it can discount that night's Build.
    - Because XP now comes before Wages, a mercenary that levels up tonight is paid at its new level tonight.
    - Resources produced tonight can only be spent from the next Night's Build (or on the next day's bids and contracts).
4. **War Horn** ("Noon:") is chosen at the start of Noon, before attacks.
5. **Ancient Map:** discarded quests go to the quest discard pile, so they can come back later.

**Mercenaries**
6. **Corvina** levels II and III ("Garrison: … Gain 1/2 fame") award the fame each time her guild is attacked while she is on Defend. A per-Night reading would be much stronger.
7. **Brenna's** garrison XP is given at the Night XP step, if she was on Defend that day.
8. **Training Grounds and Tavern** XP goes to the worker.
9. **Fenwick** ("works again"): you choose any of your other mercenaries, even one that didn't Work that day, and any location. Owner bonuses trigger again.
10. **Grim's** Conquest gold uses his Might without attack-only bonuses.
11. **Mira:** "1 resource less" takes 1 off the largest part of the cost. Her level I "+1 gold when you upgrade or build" also counts walls and guild buildings. Her discount doesn't apply to guild buildings, since the card says upgrades and walls.
12. **Unpaid wages:** discounts (Mess Hall, Shrine of the Saint) come off the total. A departing mercenary's equipment goes back to the item deck. Fame can go below 0.

**Conflicts**
13. **Retreat offers** run as: the loser offers, then the winner accepts, declines or counters, then the loser accepts, re-offers or gives up. In an auction, if the winner backs off, the runner-up wins at its own bid. If a payment leaves someone unable to cover a later winning bid, that bid is void.
14. When an attack qualifies, the attacker must conquer one location; it can't decline.
15. **Contested contract quests** are also decided by total Power.
16. **Royal Armory** (kept quest, "Your garrison: +2 Power") applies even with no mercenary on Defend.
17. **Work targets:** "any location" includes unowned locations in the row, which pay no owner bonus.

**Cards and decks**
18. **Timing rule loop:** if the deck runs out and every discarded card is still too early, the row stays short that round. The literal rule would reshuffle forever.
19. **Fame tiles:**
    - Hero's Welcome is a free hire from the current row.
    - Veteran Training jumps a mercenary to the next level's XP threshold.
    - Master Builders and Royal Engineers become tokens you can use at any later Build step.
20. **Equipment** won from quests waits unequipped until your next Build step.
21. **Game end** only counts the revealed legendary quests (one per player). If nobody can beat them, the game never ends, which is why the End game now button exists.

## Balance flags from building and test runs


- **Counting Office scales with locations and workers.** With 1 owned location and 1 worker a night it is +1 gold a night for 3 gold, which is fair. Several Offices stack, and late in the game (3 locations, several workers, 2 to 3 Offices) it can give 6 to 9 gold a night. If that feels too strong, allow only one Office per guild.

- **Early conquest is now hard.** A level I location in the row has defense 5 plus a wooden wall (8), so it takes more than 8 attack Power: about three level-1 mercenaries, or two Iron Wolves when one has an attack bonus (Varn alone attacks with 7 at level I). Expect the first locations to be bought rather than conquered.
- **Slower levels, longer games.** With XP only from quests and a few cards, bot games now rarely complete a legendary quest and all 40 test games ran to the 25-round test cap. Legendary quests may need lower Power, or more XP sources, for the game to end in a sensible time.
- **Legendary quests need big teams.** They require 24–28 Power. Random bots almost never finish one in 25 rounds, so watch how long real games take to end.
