class_name Cards
## All card data for GuildMasters, transcribed from the Card Library sheets.
## Stats are [Might, Skill, Intellect] per level. Abilities per level are already
## accumulated (a level keeps lower-level abilities unless replaced by the same trigger).
## Mercenary and equipment abilities are lists of blocks (see ABILITY BLOCKS below); their card
## text is written from the blocks by refresh_texts().
## The tables are static vars, not consts, so the in-game Editor can change them. Edits are stored
## as a diff against these defaults in data/card_edits.txt (see load_edits / save_edits below).

const RES := ["gold", "wood", "stone", "metal"]
static var GUILDS := {
	"GL": {"name": "Golden Ledger", "start": 8, "income": 4, "loc_discount": 3,
		"text": "Your minimum bid for locations is 3 gold lower."},
	"IW": {"name": "Iron Wolves", "start": 6, "income": 3,
		"text": "Your attacking mercenaries have +1 Might each. When you conquer a location: gain 2 gold."},
}

static var MERCS := {
	"bertram": {"name": "Bertram", "role": "Quartermaster", "guild": "GL", "bid": 3,
		"stats": [[0, 1, 2], [0, 1, 4], [0, 1, 6]],
		"abil": [[{"when": "work", "do": "gain", "res": "gold", "n": 1, "per": "intellect"}], [{"when": "work", "do": "gain", "res": "gold", "n": 1, "per": "intellect"}], [{"when": "work", "do": "gain", "res": "gold", "n": 1, "per": "intellect"}]],
		"text": ["When working: gain gold equal to Intellect.", "When working: gain gold equal to Intellect.", "When working: gain gold equal to Intellect."]},
	"corvina": {"name": "Corvina", "role": "Bodyguard", "guild": "GL", "bid": 3,
		"stats": [[1, 1, 1], [2, 1, 2], [3, 2, 2]],
		"abil": [[{"when": "garrison", "do": "power", "n": 1, "per": "others"}], [{"when": "garrison", "do": "power", "n": 1, "per": "others"}, {"when": "defended", "do": "gain", "res": "fame", "n": 1}], [{"when": "garrison", "do": "power", "n": 2, "per": "others"}, {"when": "defended", "do": "gain", "res": "fame", "n": 2}]],
		"text": ["Garrison: +1 Power for every other mercenary in the Garrison.", "Garrison: +1 Power for every other mercenary in the Garrison. Gain 1 fame.", "Garrison: +2 Power for every other mercenary in the Garrison. Gain 2 fame."]},
	"fenwick": {"name": "Fenwick", "role": "Foreman", "guild": "GL", "bid": 3,
		"stats": [[0, 2, 1], [0, 3, 2], [0, 4, 3]],
		"abil": [[{"when": "activate", "do": "special", "code": "rework", "n": 1}], [{"when": "activate", "do": "special", "code": "rework", "n": 1}, {"when": "ally_work", "do": "gain", "res": "gold", "n": 1}], [{"when": "activate", "do": "special", "code": "rework", "n": 2}, {"when": "ally_work", "do": "gain", "res": "gold", "n": 1}]],
		"text": ["Activate: one mercenary you control works again at any location.", "Activate: one mercenary you control works again at any location. When one of your other mercenaries works: gain 1 gold.", "Activate: two different mercenaries you control work again at any location. When one of your other mercenaries works: gain 1 gold."]},
	"isolde": {"name": "Isolde", "role": "Relic Keeper", "guild": "GL", "bid": 3,
		"stats": [[0, 1, 2], [0, 1, 4], [0, 1, 6]],
		"abil": [[{"when": "night", "do": "gain", "res": "gold", "n": 2}], [{"when": "night", "do": "gain", "res": "gold", "n": 2}, {"when": "night", "do": "gain", "res": "gold", "n": 1, "per": "relics"}], [{"when": "night", "do": "gain", "res": "gold", "n": 2}, {"when": "night", "do": "gain", "res": "gold", "n": 2, "per": "relics"}]],
		"text": ["Night: gain 2 gold.", "Night: gain 2 gold +1 gold for every relic you own.", "Night: gain 2 gold +2 gold for every relic you own."]},
	"mira": {"name": "Mira", "role": "Architect", "guild": "GL", "bid": 2,
		"stats": [[0, 2, 1], [1, 3, 1], [1, 4, 2]],
		"abil": [[{"when": "build", "do": "gain", "res": "gold", "n": 1}], [{"when": "build", "do": "gain", "res": "gold", "n": 1}, {"when": "activate", "do": "special", "code": "discount"}], [{"when": "build", "do": "gain", "res": "gold", "n": 1}, {"when": "activate", "do": "special", "code": "discount_all"}]],
		"text": ["When you upgrade or build: gain 1 gold.", "When you upgrade or build: gain 1 gold. Activate: your next upgrade or wall this Night costs 1 resource less (min 1).", "When you upgrade or build: gain 1 gold. Activate: all your upgrades and walls this Night cost 1 resource less (min 1)."]},
	"odile": {"name": "Odile", "role": "Moneylender", "guild": "GL", "bid": 4,
		"stats": [[0, 1, 2], [0, 1, 4], [0, 1, 6]],
		"abil": [[{"when": "night", "do": "gain", "res": "gold", "n": 1, "per": "intellect"}], [{"when": "night", "do": "gain", "res": "gold", "n": 1, "per": "intellect"}], [{"when": "night", "do": "gain", "res": "gold", "n": 1, "per": "intellect"}]],
		"text": ["Night: gain gold equal to Intellect.", "Night: gain gold equal to Intellect.", "Night: gain gold equal to Intellect."]},
	"brenna": {"name": "Brenna", "role": "Shieldmaiden", "guild": "IW", "bid": 3,
		"stats": [[2, 1, 0], [3, 1, 1], [5, 1, 1]],
		"abil": [[{"when": "garrison", "do": "power", "n": 1, "per": "might"}, {"when": "garrison", "do": "xp_others", "n": 1}], [{"when": "garrison", "do": "power", "n": 1, "per": "might"}, {"when": "garrison", "do": "xp_others", "n": 2}], [{"when": "garrison", "do": "power", "n": 1, "per": "might"}, {"when": "garrison", "do": "xp_others", "n": 3}]],
		"text": ["Garrison: gain Power equal to Might, +1 XP to all other mercenaries in Garrison.", "Garrison: gain Power equal to Might, +2 XP to all other mercenaries in Garrison.", "Garrison: gain Power equal to Might, +3 XP to all other mercenaries in Garrison."]},
	"grim": {"name": "Grim", "role": "Raider", "guild": "IW", "bid": 2,
		"stats": [[2, 1, 0], [3, 2, 0], [5, 2, 0]],
		"abil": [[{"when": "conquest", "do": "gain", "res": "gold", "n": 1, "per": "might"}], [{"when": "conquest", "do": "gain", "res": "gold", "n": 1, "per": "might"}, {"when": "attack", "do": "power", "n": 1, "per": "skill"}], [{"when": "conquest", "do": "gain", "res": "gold", "n": 1, "per": "might"}, {"when": "conquest", "do": "gain", "res": "fame", "n": 1}, {"when": "attack", "do": "power", "n": 1, "per": "skill"}]],
		"text": ["Conquest: gain gold equal to Might.", "Conquest: gain gold equal to Might. When attacking: gain Power equal to Skill.", "Conquest: gain gold equal to Might, +1 fame. When attacking: gain Power equal to Skill."]},
	"hilda": {"name": "Hilda", "role": "Drill Sergeant", "guild": "IW", "bid": 3,
		"stats": [[2, 0, 1], [3, 0, 2], [4, 0, 3]],
		"abil": [[{"when": "activate", "do": "xp_choose", "n": 1}], [{"when": "activate", "do": "xp_choose", "n": 2}], [{"when": "activate", "do": "xp_others", "n": 1}]],
		"text": ["Activate: another mercenary gains 1 XP.", "Activate: 2 other mercenaries gain 1 XP.", "Activate: all your other mercenaries gain 1 XP."]},
	"rook": {"name": "Rook", "role": "Siege Engineer", "guild": "IW", "bid": 3,
		"stats": [[1, 2, 0], [1, 3, 1], [1, 3, 3]],
		"abil": [[{"when": "attack", "do": "wall", "n": 2}], [{"when": "attack", "do": "wall", "n": 4}], [{"when": "attack", "do": "wall", "n": 99}]],
		"text": ["When attacking: target wall -2 defense.", "When attacking: target wall -4 defense.", "When attacking: ignore walls."]},
	"ulfgar": {"name": "Ulfgar", "role": "Armsmaster", "guild": "IW", "bid": 3,
		"stats": [[2, 1, 0], [4, 1, 0], [6, 1, 0]],
		"abil": [[{"when": "attack", "do": "power", "n": 2, "per": "equipment"}], [{"when": "attack", "do": "power", "n": 3, "per": "equipment"}], [{"when": "attack", "do": "power", "n": 3, "per": "equipment"}, {"when": "always", "do": "special", "code": "slots2"}]],
		"text": ["When attacking: +2 Power per equipment.", "When attacking: +3 Power per equipment.", "When attacking: +3 Power per equipment. Can equip 2 equipments."]},
	"varn": {"name": "Varn", "role": "Sellsword", "guild": "IW", "bid": 3,
		"stats": [[2, 1, 0], [4, 1, 0], [6, 1, 0]],
		"abil": [[{"when": "attack", "do": "power", "n": 1, "per": "might"}], [{"when": "attack", "do": "power", "n": 1, "per": "might"}], [{"when": "attack", "do": "power", "n": 1, "per": "might"}]],
		"text": ["When attacking: gain Power equal to Might.", "When attacking: gain Power equal to Might.", "When attacking: gain Power equal to Might."]},
	"garrick": {"name": "Garrick", "role": "Smith", "guild": "", "bid": 3,
		"stats": [[0, 0, 3], [0, 1, 4], [0, 3, 4]],
		"abil": [[{"when": "activate", "do": "gain", "res": "metal", "n": 1, "per": "intellect", "div": 3}], [{"when": "activate", "do": "gain", "res": "metal", "n": 1, "per": "intellect", "div": 2}], [{"when": "activate", "do": "gain", "res": "metal", "n": 1, "per": "intellect"}]],
		"text": ["Activate: 1 metal per 3 Intellect.", "Activate: 1 metal per 2 Intellect.", "Activate: 1 metal per Intellect."]},
	"kael": {"name": "Kael", "role": "Duelist", "guild": "", "bid": 3,
		"stats": [[1, 1, 1], [1, 3, 1], [2, 3, 2]],
		"abil": [[{"when": "solo", "do": "power", "n": 1}], [{"when": "solo", "do": "power", "n": 2}], [{"when": "solo", "do": "power", "n": 3}]],
		"text": ["When alone on a quest: +1 Power.", "When alone on a quest: +2 Power.", "When alone on a quest: +3 Power."]},
	"nyra": {"name": "Nyra", "role": "Ranger", "guild": "", "bid": 3,
		"stats": [[2, 1, 0], [3, 1, 1], [3, 2, 2]],
		"abil": [[{"when": "monster", "do": "power", "n": 1}], [{"when": "monster", "do": "power", "n": 2}], [{"when": "monster", "do": "power", "n": 3}]],
		"text": ["Monster quests: +1 Power.", "Monster quests: +2 Power.", "Monster quests: +3 Power."]},
	"selka": {"name": "Selka", "role": "Scout", "guild": "", "bid": 2,
		"stats": [[1, 1, 1], [1, 2, 2], [2, 3, 2]],
		"abil": [[{"when": "qdone", "do": "gain", "res": "gold", "n": 3}, {"when": "qdone", "do": "gain", "res": "xp", "n": 1}], [{"when": "qdone", "do": "gain", "res": "gold", "n": 5}, {"when": "qdone", "do": "gain", "res": "xp", "n": 1}], [{"when": "qdone", "do": "gain", "res": "gold", "n": 7}, {"when": "qdone", "do": "gain", "res": "fame", "n": 1}]],
		"text": ["Quest completed: +3 gold, +1 XP.", "Quest completed: +5 gold, +1 XP.", "Quest completed: +7 gold, +1 fame."]},
	"tomas": {"name": "Tomas", "role": "Woodcutter", "guild": "", "bid": 2,
		"stats": [[3, 0, 0], [4, 1, 0], [4, 3, 0]],
		"abil": [[{"when": "activate", "do": "gain", "res": "wood", "n": 1, "per": "might", "div": 3}], [{"when": "activate", "do": "gain", "res": "wood", "n": 1, "per": "might", "div": 2}], [{"when": "activate", "do": "gain", "res": "wood", "n": 1, "per": "might"}]],
		"text": ["Activate: 1 wood per 3 Might.", "Activate: 1 wood per 2 Might.", "Activate: 1 wood per Might."]},
	"ultor": {"name": "Ultor", "role": "Mason", "guild": "", "bid": 3,
		"stats": [[0, 3, 0], [1, 4, 0], [3, 4, 0]],
		"abil": [[{"when": "activate", "do": "gain", "res": "stone", "n": 1, "per": "skill", "div": 3}], [{"when": "activate", "do": "gain", "res": "stone", "n": 1, "per": "skill", "div": 2}], [{"when": "activate", "do": "gain", "res": "stone", "n": 1, "per": "skill"}]],
		"text": ["Activate: 1 stone per 3 Skill.", "Activate: 1 stone per 2 Skill.", "Activate: 1 stone per Skill."]},
}

## Location work effects ("w"):
##  per:   floor(stat / div) * mult + plus of res   (stat 0=M 1=S 2=I 3=highest)
##  bank:  1 gold per `div` gold you have, max Intellect
##  chouse: worker with min+ Intellect: mult gold per location (scope own/all)
##  shrine: pay `pay` gold, take a relic of value <= Intellect + off
##  forge:  pay `pay` metal, take equipment of value <= Might + off
##  sell:   sell 1 resource per `div` Intellect for 2 gold each
##  garrison / attack: your garrison / attacks today +mult Power per div stat
##  wages: your wages tonight -1 gold per div Might
## Location minimum bids (design change Nov 25): printed bid x2 + 4, so 10-16 here,
## plus 2 per wall tier the location arrives with (see Game.bid_min), up to 22 late.
static var LOCS := {
	"bank": {"name": "Bank", "guild": "GL", "bid": 16, "timing": [6, 99], "levels": [
		{"w": {"k": "bank", "div": 5, "base": {"gold": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold + 1 gold per 5 gold you have (max: Intellect). Owner: +1 gold"},
		{"up": {"gold": 5, "stone": 3}, "w": {"k": "bank", "div": 4, "base": {"gold": 1}}, "owner": {"gold": 2}, "text": "Work: 1 gold + 1 gold per 4 gold you have (max: Intellect). Owner: +2 gold"},
		{"up": {"gold": 10, "stone": 3, "metal": 2}, "w": {"k": "bank", "div": 3, "base": {"gold": 2}}, "owner": {"gold": 3}, "text": "Work: 2 gold + 1 gold per 3 gold you have (max: Intellect). Owner: +3 gold"}]},
	"counting_house": {"name": "Counting House", "guild": "GL", "bid": 14, "timing": [3, 99], "levels": [
		{"w": {"k": "chouse", "min": 3, "scope": "own", "mult": 1, "base": {"gold": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold + worker with 3+ Intellect: 1 gold per location you own. Owner: +1 gold"},
		{"up": {"gold": 5, "wood": 1, "stone": 1}, "w": {"k": "chouse", "min": 4, "scope": "all", "mult": 1, "base": {"gold": 1}}, "owner": {"gold": 2}, "text": "Work: 1 gold + worker with 4+ Intellect: 1 gold per location owned by all players. Owner: +2 gold"},
		{"up": {"gold": 10, "wood": 2, "stone": 2}, "w": {"k": "chouse", "min": 5, "scope": "all", "mult": 2, "base": {"gold": 2}}, "owner": {"gold": 3}, "text": "Work: 2 gold + worker with 5+ Intellect: 2 gold per location owned by all players. Owner: +3 gold"}]},
	"market_square": {"name": "Market Square", "guild": "GL", "bid": 12, "timing": [1, 99], "levels": [
		{"w": {"k": "per", "res": "gold", "stat": 2, "div": 2, "base": {"gold": 2}}, "owner": {"gold": 1}, "text": "Work: 2 gold + 1 gold per 2 Intellect. Owner: +1 gold"},
		{"up": {"gold": 5, "wood": 3}, "w": {"k": "per", "res": "gold", "stat": 2, "div": 2, "base": {"gold": 3}}, "owner": {"gold": 2}, "text": "Work: 3 gold + 1 gold per 2 Intellect. Owner: +2 gold"},
		{"up": {"gold": 10, "stone": 3}, "w": {"k": "per", "res": "gold", "stat": 2, "div": 1, "base": {"gold": 3}}, "owner": {"gold": 2}, "text": "Work: 3 gold + 1 gold per Intellect. Owner: +2 gold"}]},
	"old_shrine": {"name": "Old Shrine", "guild": "GL", "bid": 14, "timing": [3, 99], "levels": [
		{"w": {"k": "shrine", "pay": 5, "off": -2, "base": {"gold": 1}}, "owner": {"stone": 1}, "text": "Work: 1 gold + pay 5 gold: take a relic of value <= Intellect -2. Owner: +1 stone"},
		{"up": {"stone": 5}, "w": {"k": "shrine", "pay": 5, "off": -1, "base": {"gold": 1}}, "owner": {"stone": 1}, "text": "Work: 1 gold + pay 5 gold: take a relic of value <= Intellect -1. Owner: +1 stone"},
		{"up": {"stone": 10}, "w": {"k": "shrine", "pay": 5, "off": 0, "base": {"gold": 2}}, "owner": {"stone": 2}, "text": "Work: 2 gold + pay 5 gold: take a relic of value <= Intellect. Owner: +2 stone"}]},
	"trading_post": {"name": "Trading Post", "guild": "GL", "bid": 12, "timing": [1, 99], "levels": [
		{"w": {"k": "sell", "div": 3, "base": {"gold": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold + sell 1 resource per 3 Intellect for 2 gold each. Owner: +1 gold"},
		{"up": {"gold": 5, "wood": 2}, "w": {"k": "sell", "div": 2, "base": {"gold": 1}}, "owner": {"gold": 2}, "text": "Work: 1 gold + sell 1 resource per 2 Intellect for 2 gold each. Owner: +2 gold"},
		{"up": {"gold": 10, "stone": 2}, "w": {"k": "sell", "div": 1, "base": {"gold": 2}}, "owner": {"gold": 2}, "text": "Work: 2 gold + sell 1 resource per Intellect for 2 gold each. Owner: +2 gold"}]},
	"arena": {"name": "Arena", "guild": "IW", "bid": 10, "timing": [1, 99], "levels": [
		{"w": {"k": "per", "res": "gold", "stat": 0, "div": 3, "base": {"gold": 2}}, "owner": {"gold": 1}, "text": "Work: 2 gold + 1 gold per 3 Might. Owner: +1 gold"},
		{"up": {"wood": 2, "stone": 1}, "w": {"k": "per", "res": "gold", "stat": 0, "div": 2, "base": {"gold": 2}}, "owner": {"gold": 2}, "text": "Work: 2 gold + 1 gold per 2 Might. Owner: +2 gold"},
		{"up": {"wood": 2, "stone": 2, "metal": 2}, "w": {"k": "per", "res": "gold", "stat": 0, "div": 1, "base": {"gold": 3}}, "owner": {"gold": 2}, "text": "Work: 3 gold + 1 gold per Might. Owner: +2 gold"}]},
	"barracks": {"name": "Barracks", "guild": "IW", "bid": 12, "timing": [3, 99], "levels": [
		{"w": {"k": "garrison", "div": 2, "mult": 1, "base": {"gold": 1}}, "owner": {"metal": 1}, "text": "Work: 1 gold + your garrison today +1 Power per 2 Might. Owner: +1 metal"},
		{"up": {"wood": 2, "metal": 2}, "w": {"k": "garrison", "div": 1, "mult": 1, "base": {"gold": 1}}, "owner": {"metal": 1}, "text": "Work: 1 gold + your garrison today +1 Power per Might. Owner: +1 metal"},
		{"up": {"stone": 2, "metal": 4}, "w": {"k": "garrison", "div": 1, "mult": 2, "base": {"gold": 2}}, "owner": {"metal": 1}, "text": "Work: 2 gold + your garrison today +2 Power per Might. Owner: +1 metal"}]},
	"forge": {"name": "Forge", "guild": "IW", "bid": 14, "timing": [3, 99], "levels": [
		{"w": {"k": "forge", "pay": 3, "off": 0, "base": {"gold": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold + pay 3 metal: take equipment of value <= Might. Owner: +1 gold"},
		{"up": {"wood": 1, "stone": 1, "metal": 2}, "w": {"k": "forge", "pay": 2, "off": 0, "base": {"gold": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold + pay 2 metal: take equipment of value <= Might. Owner: +1 gold"},
		{"up": {"stone": 3, "metal": 4}, "w": {"k": "forge", "pay": 1, "off": 2, "base": {"gold": 2}}, "owner": {"metal": 1}, "text": "Work: 2 gold + pay 1 metal: take equipment of value <= Might +2. Owner: +1 metal"}]},
	"mess_hall": {"name": "Mess Hall", "guild": "IW", "bid": 12, "timing": [2, 99], "levels": [
		{"w": {"k": "wages", "div": 3, "base": {"gold": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold + your wages tonight -1 gold per 3 Might. Owner: +1 gold"},
		{"up": {"wood": 2, "stone": 1, "metal": 1}, "w": {"k": "wages", "div": 2, "base": {"gold": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold + your wages tonight -1 gold per 2 Might. Owner: +1 gold"},
		{"up": {"stone": 3, "metal": 2}, "w": {"k": "wages", "div": 1, "base": {"gold": 2}}, "owner": {"gold": 2}, "text": "Work: 2 gold + your wages tonight -1 gold per Might. Owner: +2 gold"}]},
	"training_grounds": {"name": "Training Grounds", "guild": "IW", "bid": 12, "timing": [2, 99], "levels": [
		{"w": {"k": "per", "res": "xp", "stat": 0, "div": 3, "base": {"gold": 1, "xp": 1}}, "owner": {"metal": 1}, "text": "Work: 1 gold, 1 XP + 1 XP per 3 Might. Owner: +1 metal"},
		{"up": {"wood": 2, "metal": 2}, "w": {"k": "per", "res": "xp", "stat": 0, "div": 2, "base": {"gold": 1, "xp": 1}}, "owner": {"metal": 1}, "text": "Work: 1 gold, 1 XP + 1 XP per 2 Might. Owner: +1 metal"},
		{"up": {"stone": 2, "metal": 4}, "w": {"k": "per", "res": "xp", "stat": 0, "div": 1, "base": {"gold": 2, "xp": 1}}, "owner": {"metal": 1}, "text": "Work: 2 gold, 1 XP + 1 XP per Might. Owner: +1 metal"}]},
	"caravanserai": {"name": "Caravanserai", "guild": "", "bid": 12, "timing": [3, 99], "levels": [
		{"w": {"k": "per", "res": "gold", "stat": 1, "div": 3, "base": {"gold": 2}}, "owner": {"gold": 1}, "text": "Work: 2 gold + 1 gold per 3 Skill. Owner: +1 gold"},
		{"up": {"wood": 3, "stone": 1}, "w": {"k": "per", "res": "gold", "stat": 1, "div": 2, "base": {"gold": 2}}, "owner": {"gold": 1}, "text": "Work: 2 gold + 1 gold per 2 Skill. Owner: +1 gold"},
		{"up": {"stone": 3, "metal": 1}, "w": {"k": "per", "res": "gold", "stat": 1, "div": 1, "base": {"gold": 3}}, "owner": {"gold": 2}, "text": "Work: 3 gold + 1 gold per Skill. Owner: +2 gold"}]},
	"iron_mine": {"name": "Iron Mine", "guild": "", "bid": 12, "timing": [2, 99], "levels": [
		{"w": {"k": "per", "res": "metal", "stat": 0, "div": 4, "base": {"metal": 1}}, "owner": {"gold": 1}, "text": "Work: 1 metal + 1 metal per 4 Might. Owner: +1 gold"},
		{"up": {"wood": 2, "stone": 2}, "w": {"k": "per", "res": "metal", "stat": 0, "div": 3, "base": {"metal": 1}}, "owner": {"metal": 1}, "text": "Work: 1 metal + 1 metal per 3 Might. Owner: +1 metal"},
		{"up": {"gold": 2, "stone": 3}, "w": {"k": "per", "res": "metal", "stat": 0, "div": 2, "base": {"metal": 2}}, "owner": {"metal": 1}, "text": "Work: 2 metal + 1 metal per 2 Might. Owner: +1 metal"}]},
	"lumber_camp": {"name": "Lumber Camp", "guild": "", "bid": 10, "timing": [1, 99], "levels": [
		{"w": {"k": "per", "res": "wood", "stat": 0, "div": 3, "base": {"wood": 1}}, "owner": {"wood": 1}, "text": "Work: 1 wood + 1 wood per 3 Might. Owner: +1 wood"},
		{"up": {"gold": 2, "stone": 1}, "w": {"k": "per", "res": "wood", "stat": 0, "div": 2, "base": {"wood": 1}}, "owner": {"wood": 1}, "text": "Work: 1 wood + 1 wood per 2 Might. Owner: +1 wood"},
		{"up": {"stone": 2, "metal": 1}, "w": {"k": "per", "res": "wood", "stat": 0, "div": 1, "base": {"wood": 2}}, "owner": {"wood": 2}, "text": "Work: 2 wood + 1 wood per Might. Owner: +2 wood"}]},
	"quarry": {"name": "Quarry", "guild": "", "bid": 10, "timing": [1, 99], "levels": [
		{"w": {"k": "per", "res": "stone", "stat": 1, "div": 3, "base": {"stone": 1}}, "owner": {"stone": 1}, "text": "Work: 1 stone + 1 stone per 3 Skill. Owner: +1 stone"},
		{"up": {"gold": 2, "wood": 2}, "w": {"k": "per", "res": "stone", "stat": 1, "div": 2, "base": {"stone": 1}}, "owner": {"stone": 1}, "text": "Work: 1 stone + 1 stone per 2 Skill. Owner: +1 stone"},
		{"up": {"wood": 2, "metal": 1}, "w": {"k": "per", "res": "stone", "stat": 1, "div": 1, "base": {"stone": 2}}, "owner": {"stone": 2}, "text": "Work: 2 stone + 1 stone per Skill. Owner: +2 stone"}]},
	"tavern": {"name": "Tavern", "guild": "", "bid": 10, "timing": [1, 99], "levels": [
		{"w": {"k": "per", "res": "xp", "stat": 2, "div": 3, "base": {"gold": 1, "xp": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold, 1 XP + 1 XP per 3 Intellect. Owner: +1 gold"},
		{"up": {"gold": 2, "wood": 2}, "w": {"k": "per", "res": "xp", "stat": 2, "div": 2, "base": {"gold": 1, "xp": 1}}, "owner": {"gold": 1}, "text": "Work: 1 gold, 1 XP + 1 XP per 2 Intellect. Owner: +1 gold"},
		{"up": {"wood": 2, "stone": 2}, "w": {"k": "per", "res": "xp", "stat": 2, "div": 1, "base": {"gold": 2, "xp": 1}}, "owner": {"gold": 2}, "text": "Work: 2 gold, 1 XP + 1 XP per Intellect. Owner: +2 gold"}]},
	"royal_mint": {"name": "Royal Mint", "guild": "GL", "bid": 0, "timing": [], "levels": [
		{"w": {"k": "per", "res": "gold", "stat": 2, "div": 1, "base": {"gold": 2}}, "owner": {"gold": 2}, "text": "Work: 2 gold + 1 gold per Intellect. Owner: +2 gold"},
		{"up": {"gold": 5, "stone": 3}, "w": {"k": "per", "res": "gold", "stat": 2, "div": 1, "plus": 2, "base": {"gold": 2}}, "owner": {"gold": 2}, "text": "Work: 2 gold + 1 gold per Intellect, +2. Owner: +2 gold"},
		{"up": {"gold": 10, "stone": 3, "metal": 2}, "w": {"k": "per", "res": "gold", "stat": 2, "div": 1, "mult": 2, "base": {"gold": 3}}, "owner": {"gold": 3}, "text": "Work: 3 gold + 2 gold per Intellect. Owner: +3 gold"}]},
	"siege_workshop": {"name": "Siege Workshop", "guild": "IW", "bid": 0, "timing": [], "levels": [
		{"w": {"k": "attack", "div": 2, "mult": 1, "base": {"metal": 1}}, "owner": {"metal": 1}, "text": "Work: 1 metal + your attacks today +1 Power per 2 Skill. Owner: +1 metal"},
		{"up": {"wood": 3, "stone": 2}, "w": {"k": "attack", "div": 1, "mult": 1, "base": {"metal": 1}}, "owner": {"metal": 1}, "text": "Work: 1 metal + your attacks today +1 Power per Skill. Owner: +1 metal"},
		{"up": {"stone": 3, "metal": 3}, "w": {"k": "attack", "div": 1, "mult": 2, "base": {"metal": 2}}, "owner": {"metal": 2}, "text": "Work: 2 metal + your attacks today +2 Power per Skill. Owner: +2 metal"}]},
	"hall_of_legends": {"name": "Hall of Legends", "guild": "", "bid": 0, "timing": [], "levels": [
		{"w": {"k": "per", "res": "fame", "stat": 3, "div": 4, "base": {"gold": 1}}, "owner": {"gold": 2}, "text": "Work: 1 gold + 1 fame per 4 of the worker's highest stat. Owner: +2 gold"},
		{"up": {"gold": 5, "stone": 5}, "w": {"k": "per", "res": "fame", "stat": 3, "div": 3, "base": {"gold": 1}}, "owner": {"gold": 2}, "text": "Work: 1 gold + 1 fame per 3 of the worker's highest stat. Owner: +2 gold"},
		{"up": {"gold": 10, "stone": 5, "metal": 5}, "w": {"k": "per", "res": "fame", "stat": 3, "div": 2, "base": {"gold": 2}}, "owner": {"gold": 3}, "text": "Work: 2 gold + 1 fame per 2 of the worker's highest stat. Owner: +3 gold"}]},
}

static var ITEMS := {
	"golden_scales": {"name": "Golden Scales", "kind": "equip", "value": 2, "stats": [0, 0, 1], "abil": [{"when": "work", "do": "gain", "res": "gold", "n": 1}], "text": "Intellect +1. When working: +1 gold."},
	"iron_sword": {"name": "Iron Sword", "kind": "equip", "value": 2, "stats": [0, 0, 0], "abil": [{"when": "attack", "do": "might", "n": 3}], "text": "When attacking: +3 Might."},
	"war_banner": {"name": "War Banner", "kind": "equip", "value": 4, "stats": [0, 0, 0], "abil": [{"when": "attack", "do": "might_others", "n": 1}], "text": "When attacking: your other attackers get +1 Might."},
	"war_shield": {"name": "War Shield", "kind": "equip", "value": 2, "stats": [0, 0, 0], "abil": [{"when": "attack", "do": "power", "n": 1, "per": "others"}], "text": "When attacking: +1 Power per other attacking mercenary."},
	"backpack": {"name": "Adventurer's Backpack", "kind": "equip", "value": 3, "stats": [1, 1, 1], "abil": [{"when": "questing", "do": "power", "n": 1}], "text": "M+1 S+1 I+1. Questing: +1 Power."},
	"masons_tools": {"name": "Mason's Tools", "kind": "equip", "value": 2, "stats": [0, 2, 0], "abil": [], "text": "Skill +2."},
	"scholars_tome": {"name": "Scholar's Tome", "kind": "equip", "value": 2, "stats": [0, 0, 2], "abil": [], "text": "Intellect +2."},
	"travelers_boots": {"name": "Traveler's Boots", "kind": "equip", "value": 2, "stats": [0, 0, 0], "abil": [{"when": "qdone", "do": "gain", "res": "xp", "n": 2}], "text": "Quest completed: +2 XP."},
	"wooden_mace": {"name": "Wooden Mace", "kind": "equip", "value": 2, "stats": [2, 0, 0], "abil": [], "text": "Might +2."},
	"golden_idol": {"name": "Golden Idol", "kind": "relic", "value": 3, "text": "Night: +2 gold."},
	"merchants_seal": {"name": "Merchant's Seal", "kind": "relic", "value": 4, "text": "Noon: your winning bids cost 1 gold less."},
	"signet_ring": {"name": "Signet Ring", "kind": "relic", "value": 3, "text": "When a mercenary works in a location you own: +1 gold."},
	"trade_charter": {"name": "Trade Charter", "kind": "relic", "value": 4, "text": "Night: you may sell a resource to gain 4 gold."},
	"ward_stone": {"name": "Ward Stone", "kind": "relic", "value": 4, "text": "Locations you own have +2 defense."},
	"trophy_rack": {"name": "Trophy Rack", "kind": "relic", "value": 4, "text": "Conquest: +1 fame."},
	"veterans_pact": {"name": "Veteran's Pact", "kind": "relic", "value": 4, "text": "Night: your level 3 mercenaries' wages -1 gold each."},
	"war_horn": {"name": "War Horn", "kind": "relic", "value": 3, "text": "Noon: +3 Might to one mercenary you own until the end of Night."},
	"ancient_map": {"name": "Ancient Map", "kind": "relic", "value": 3, "text": "Dawn: look at the top 3 quests, discard any of them and put the rest back in any order."},
}

## Quests. kind monster|contract. timing [min,max] ([] = legendary, always available).
## need: {stat_index: amount}. pay: resources. reward: fame/gold/resources/xp (each)/item/loc/keep.
## Design change (Nov 25): regular quests +1 fame. Design change (Nov 28): reward xp is the total XP shared by the
## team (Game.share_xp): the quest's last round (12 if open-ended), 20 for legendary quests.
static var QUESTS := {
	"audit": {"name": "Audit the Guild Hall", "guild": "GL", "kind": "contract", "timing": [1, 4], "pay": {}, "need": {2: 4}, "reward": {"xp": 4, "fame": 2, "gold": 2, "item": "golden_scales"}},
	"firewood": {"name": "Firewood Order", "guild": "GL", "kind": "contract", "timing": [1, 4], "pay": {"wood": 3}, "need": {0: 2}, "reward": {"xp": 4, "fame": 2, "gold": 4, "keep": "night_wood"}},
	"stone_wall": {"name": "Stone for the Wall", "guild": "GL", "kind": "contract", "timing": [3, 6], "pay": {"stone": 3}, "need": {1: 2}, "reward": {"xp": 6, "fame": 2, "gold": 3, "keep": "night_stone"}},
	"bridge": {"name": "Bridge Repairs", "guild": "GL", "kind": "contract", "timing": [4, 8], "pay": {"wood": 2, "stone": 2}, "min_mercs": 2, "reward": {"xp": 8, "fame": 3, "gold": 3, "item": "signet_ring"}},
	"tax": {"name": "Tax Exemption", "guild": "GL", "kind": "contract", "timing": [4, 8], "pay": {"gold": 4}, "need": {2: 4}, "reward": {"xp": 8, "fame": 3, "item": "merchants_seal"}},
	"loan": {"name": "Royal Loan", "guild": "GL", "kind": "contract", "timing": [5, 7], "pay": {"gold": 6}, "need": {2: 2}, "reward": {"xp": 7, "fame": 4, "item": "golden_idol"}},
	"cathedral": {"name": "Cathedral Works", "guild": "GL", "kind": "contract", "timing": [6, 99], "pay": {"gold": 2, "stone": 4, "metal": 2}, "need": {0: 3, 1: 3}, "reward": {"xp": 12, "fame": 5, "item": "ward_stone"}},
	"festival": {"name": "Festival Supplies", "guild": "GL", "kind": "contract", "timing": [6, 9], "pay": {"gold": 3, "wood": 3}, "need": {1: 2, 2: 2}, "reward": {"xp": 9, "fame": 4, "item": "trade_charter"}},
	"charter": {"name": "Royal Charter", "guild": "GL", "kind": "contract", "timing": [6, 9], "pay": {"gold": 4, "stone": 3}, "need": {1: 3, 2: 3}, "reward": {"xp": 9, "fame": 3, "loc": "royal_mint"}},
	"wolf_pack": {"name": "Wolf Pack", "guild": "IW", "kind": "monster", "timing": [1, 3], "power": 4, "need": {0: 2}, "reward": {"fame": 2, "gold": 2, "xp": 3, "keep": "night_gold"}},
	"bandit": {"name": "Bandit Camp", "guild": "IW", "kind": "monster", "timing": [2, 5], "power": 6, "need": {1: 3}, "reward": {"xp": 5, "fame": 2, "gold": 2, "metal": 1, "item": "iron_sword"}},
	"goblin": {"name": "Goblin Warren", "guild": "IW", "kind": "monster", "timing": [3, 6], "power": 7, "need": {0: 4}, "reward": {"fame": 2, "gold": 3, "xp": 6, "item": "veterans_pact"}},
	"tournament": {"name": "Mercenary Tournament", "guild": "IW", "kind": "monster", "timing": [3, 6], "power": 7, "need": {0: 5}, "max_mercs": 1, "reward": {"xp": 6, "fame": 3, "gold": 3, "keep": "attack_plus2"}},
	"troll": {"name": "Troll Bridge", "guild": "IW", "kind": "monster", "timing": [4, 8], "power": 10, "need": {0: 4, 1: 3}, "reward": {"xp": 8, "fame": 3, "gold": 4, "item": "war_shield"}},
	"ogre": {"name": "Ogre Warband", "guild": "IW", "kind": "monster", "timing": [6, 9], "power": 14, "need": {0: 8}, "reward": {"xp": 9, "fame": 4, "gold": 5, "item": "trophy_rack"}},
	"blackstone": {"name": "Siege of Blackstone", "guild": "IW", "kind": "monster", "timing": [6, 9], "power": 12, "need": {0: 6}, "min_mercs": 3, "reward": {"xp": 9, "fame": 3, "loc": "siege_workshop"}},
	"wyvern": {"name": "Wyvern Nest", "guild": "IW", "kind": "monster", "timing": [7, 10], "power": 16, "need": {1: 5}, "reward": {"fame": 4, "gold": 3, "xp": 10, "item": "war_horn"}},
	"warlord": {"name": "Warlord's Fortress", "guild": "IW", "kind": "monster", "timing": [9, 99], "power": 20, "need": {0: 10}, "reward": {"xp": 12, "fame": 6, "gold": 5, "item": "war_banner"}},
	"caravan": {"name": "Lost Caravan", "guild": "", "kind": "monster", "timing": [1, 3], "power": 4, "need": {1: 2}, "reward": {"xp": 3, "fame": 2, "gold": 2, "wood": 1, "stone": 1, "item": "backpack"}},
	"pilgrims": {"name": "Escort the Pilgrims", "guild": "", "kind": "monster", "timing": [2, 5], "power": 5, "min_mercs": 2, "reward": {"xp": 5, "fame": 2, "gold": 3, "item": "travelers_boots"}},
	"saint": {"name": "Shrine of the Saint", "guild": "", "kind": "contract", "timing": [3, 6], "pay": {"gold": 3}, "max_mercs": 1, "reward": {"xp": 6, "fame": 2, "keep": "wages_minus1"}},
	"smith": {"name": "Smith's Commission", "guild": "", "kind": "contract", "timing": [3, 6], "pay": {"metal": 2}, "need": {1: 3}, "reward": {"xp": 6, "fame": 2, "item": "masons_tools", "keep": "night_metal"}},
	"spider": {"name": "Giant Spider", "guild": "", "kind": "monster", "timing": [4, 8], "power": 8, "need": {0: 2, 1: 2}, "reward": {"fame": 2, "xp": 8, "item": "wooden_mace"}},
	"masterwork": {"name": "Masterwork Commission", "guild": "", "kind": "contract", "timing": [5, 7], "pay": {"wood": 2, "metal": 3}, "need": {1: 4}, "reward": {"xp": 7, "fame": 3, "keep": "level_up"}},
	"crypt": {"name": "Haunted Crypt", "guild": "", "kind": "monster", "timing": [6, 9], "power": 12, "need": {2: 3}, "min_mercs": 2, "reward": {"xp": 9, "fame": 4, "item": "ancient_map"}},
	"armory": {"name": "Royal Armory", "guild": "", "kind": "contract", "timing": [7, 10], "pay": {"metal": 4}, "need": {0: 3}, "reward": {"xp": 10, "fame": 5, "gold": 2, "keep": "garrison_plus2"}},
	"library": {"name": "The Lost Library", "guild": "", "kind": "contract", "timing": [8, 99], "pay": {}, "need": {2: 6}, "reward": {"fame": 4, "xp": 12, "item": "scholars_tome"}},
	"legend": {"name": "The Lost Legend", "guild": "", "kind": "monster", "timing": [9, 99], "power": 20, "need": {2: 5}, "reward": {"xp": 12, "fame": 5, "loc": "hall_of_legends"}},
}

static var LEGENDS := {
	"citadel": {"name": "The King's Citadel", "guild": "GL", "kind": "contract", "pay": {"gold": 30, "wood": 20, "stone": 10, "metal": 5}, "reward": {"xp": 20, "fame": 10, "keep": "citadel"}},
	"dragon": {"name": "The Red Dragon", "guild": "IW", "kind": "monster", "power": 20, "need": {0: 10}, "reward": {"xp": 20, "fame": 10, "keep": "dragon"}},
	"kraken": {"name": "The Kraken of the Bay", "guild": "", "kind": "monster", "power": 30, "min_mercs": 8, "reward": {"xp": 20, "fame": 10, "keep": "kraken"}},
	"lich": {"name": "The Lich of Greyhollow", "guild": "", "kind": "monster", "power": 20, "need": {2: 10}, "reward": {"xp": 20, "fame": 10, "keep": "lich"}},
}

static var KEEP_TEXT := {
	"night_wood": "Night: +1 wood", "night_stone": "Night: +1 stone", "night_gold": "Night: +1 gold", "night_metal": "Night: +1 metal",
	"wages_minus1": "Your total wages -1 gold each Night", "attack_plus2": "Your attacks: +2 Power",
	"garrison_plus2": "Your garrison: +2 Power", "level_up": "One mercenary gains a level (once)",
	"citadel": "The Citadel: your locations get +3 defense", "dragon": "Dragonslayers: your mercenaries get +1 Might",
	"kraken": "Sunken treasure: +8 base gold production", "lich": "Phylactery: Night: all your mercenaries gain 1 XP",
}

static var BUILDINGS := {
	"stall": {"name": "Trading Stall", "cost": {"gold": 3}, "prod": "gold", "guild": ""},
	"sawmill": {"name": "Sawmill", "cost": {"gold": 3}, "prod": "wood", "guild": ""},
	"stoneworks": {"name": "Stoneworks", "cost": {"wood": 3}, "prod": "stone", "guild": ""},
	"smelter": {"name": "Smelter", "cost": {"stone": 3}, "prod": "metal", "guild": ""},
	"office": {"name": "Counting Office", "cost": {"gold": 3}, "prod": "", "guild": "GL", "text": "Locations you own: each owner bonus gives +1 gold"},
	"warcamp": {"name": "War Camp", "cost": {"wood": 3}, "prod": "", "guild": "IW", "text": "Night: 1 XP to one mercenary, +2 gold if you conquered today"},
}

## Base defense of every location by level (design change, Nov 25: replaces the printed values).
static var LOC_DEF := [5, 9, 13]
## Walls put on restocked locations: the first N (N = players) get none, the next N wooden, the next N stone, then iron.
static var RESTOCK_WALLS := ["wooden", "stone", "iron"]

static var WALLS := {
	"wooden": {"name": "Wooden Wall", "cost": {"wood": 3}, "def": 3},
	"stone": {"name": "Stone Wall", "cost": {"stone": 3}, "def": 5},
	"iron": {"name": "Iron Wall", "cost": {"metal": 3}, "def": 7},
}

static var TILES := {
	"treasure": {"name": "Treasure", "text": "+10 gold (once)"},
	"stipend": {"name": "Royal Stipend", "text": "Night: +2 gold (keep)"},
	"lumber": {"name": "Lumber Rights", "text": "Night: +1 wood (keep)"},
	"quarry": {"name": "Quarry Rights", "text": "Night: +1 stone (keep)"},
	"mining": {"name": "Mining Rights", "text": "Night: +1 metal (keep)"},
	"builders": {"name": "Master Builders", "text": "Free location upgrade (once)"},
	"veteran": {"name": "Veteran Training", "text": "Free +1 level to a mercenary (once)"},
	"armory": {"name": "Royal Armory", "text": "Take any equipment from the deck (once)"},
	"hero": {"name": "Hero's Welcome", "text": "Free hire from the mercenary row (once)"},
	"engineers": {"name": "Royal Engineers", "text": "Free stone wall (once)"},
}
static var FAME_SPACES := [5, 10, 20, 30, 50]
const STAT_NAMES := ["Might", "Skill", "Intellect"]


# ------------------------------------------------------------------ editor support

## Editable tables, by name. Every entry is a Dictionary except KEEP_TEXT (plain text) and RULES.
const TABLES := ["GUILDS", "MERCS", "ITEMS", "LOCS", "QUESTS", "LEGENDS", "BUILDINGS", "WALLS", "TILES", "KEEP_TEXT", "RULES"]
## Game-wide numbers, edited as one entry; sync_rules() copies them into the arrays the game reads.
static var RULES := {"rules": {"name": "Rules numbers", "loc_def": [5, 9, 13], "restock_walls": ["wooden", "stone", "iron"], "fame_spaces": [5, 10, 20, 30, 50]}}
static var _defaults := {}

static func table(t: String) -> Dictionary:
	match t:
		"GUILDS": return GUILDS
		"MERCS": return MERCS
		"ITEMS": return ITEMS
		"LOCS": return LOCS
		"QUESTS": return QUESTS
		"LEGENDS": return LEGENDS
		"BUILDINGS": return BUILDINGS
		"WALLS": return WALLS
		"TILES": return TILES
		"KEEP_TEXT": return KEEP_TEXT
	return RULES

static func sync_rules() -> void:
	var r: Dictionary = RULES.rules
	LOC_DEF.assign(r.loc_def)
	RESTOCK_WALLS.assign(r.restock_walls)
	FAME_SPACES.assign(r.fame_spaces)

static func edits_path() -> String:
	# Running from the Godot editor: keep edits in the project, so they can be committed.
	return "res://data/card_edits.txt" if OS.has_feature("editor") else "user://card_edits.txt"

static func _snapshot() -> void:
	if _defaults.is_empty():
		for t in TABLES:
			_defaults[t] = table(t).duplicate(true)

static func default_of(t: String, id: String):
	_snapshot()
	return _defaults[t].get(id)

## Edits = {table: {id: entry, or null for a deleted card}}, only where it differs from the defaults.
static func current_edits() -> Dictionary:
	_snapshot()
	var out := {}
	for t in TABLES:
		var cur := table(t)
		var d: Dictionary = _defaults[t]
		var e := {}
		for id in cur:
			if not d.has(id) or var_to_str(d[id]) != var_to_str(cur[id]):
				e[id] = cur[id]
		for id in d:
			if not cur.has(id):
				e[id] = null
		if not e.is_empty():
			out[t] = e
	return out

static func apply_edits(edits: Dictionary) -> void:
	_snapshot()
	for t in TABLES:
		var cur := table(t)
		cur.clear()
		cur.merge(_defaults[t].duplicate(true))
		for id in edits.get(t, {}):
			if edits[t][id] == null:
				cur.erase(id)
			else:
				cur[id] = edits[t][id]
	sync_rules()
	refresh_texts()

static func load_edits() -> void:
	refresh_texts()
	_snapshot()
	var path := edits_path()
	if not FileAccess.file_exists(path):
		return
	var v = str_to_var(FileAccess.get_file_as_string(path))
	if v is Dictionary:
		apply_edits(v)

static func save_edits() -> Error:
	var path := edits_path()
	if path.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(var_to_str(current_edits()))
	return OK


# ------------------------------------------------------------------ ability blocks

## An ability block: {"when": trigger, "do": effect, "n": amount, "per": "" or counter, "div": every D,
## "res": resource for "gain", "code": for "special"}. Amount = n, or n x floor(counter / div).
## Triggers: [id, card text prefix, icon, editor label]
const TRIGGERS := [
	["dawn", "Dawn:", "night", "Dawn"],
	["night", "Night:", "night", "Night (production)"],
	["work", "When working:", "work", "When working"],
	["ally_work", "When another of your mercenaries works:", "work", "When another of your mercenaries works"],
	["activate", "Activate:", "activate", "Activate (order)"],
	["attack", "When attacking:", "attack", "When attacking"],
	["garrison", "Garrison:", "defend", "In the garrison"],
	["defended", "When your garrison is attacked:", "defend", "When your garrison is attacked"],
	["conquest", "Conquest:", "attack", "Conquest"],
	["questing", "On a quest:", "quest", "On a quest"],
	["solo", "On a quest alone:", "quest", "On a quest alone"],
	["monster", "Against a monster:", "quest", "Against a monster"],
	["qdone", "Quest completed:", "quest", "Quest completed"],
	["build", "When you upgrade or build:", "build", "When you upgrade or build"],
	["always", "", "relic", "Always"],
]
## Effects: [id, editor label, icon]
const EFFECTS := [
	["gain", "Gain", "gold"],
	["power", "+Power in this fight", "attack"],
	["might", "+Might (this mercenary)", "attack"],
	["might_others", "+Might to your other attackers", "attack"],
	["xp_others", "XP to your other mercenaries in the group", "xp"],
	["xp_choose", "Choose N other mercenaries: +1 XP each", "xp"],
	["wall", "Target wall -N (99 = ignore walls)", "wall"],
	["special", "Special (coded)", "relic"],
]
const GAIN_RES := ["gold", "wood", "stone", "metal", "fame", "xp"]
## Counters for "N per X": [id, text]
const PERS := [["", "fixed"], ["might", "Might"], ["skill", "Skill"], ["intellect", "Intellect"],
	["relics", "relic you own"], ["equipment", "equipment carried"], ["others", "other mercenary in the group"]]
## Abilities that stay in code: [code, text]
const SPECIALS := [
	["rework", "%d of your other mercenaries work again at any location"],
	["discount", "your next upgrade or wall this Night costs 1 resource less (min 1)"],
	["discount_all", "all your upgrades and walls this Night cost 1 resource less (min 1)"],
	["slots2", "can carry 2 pieces of equipment"],
]

static func _row(list: Array, id: String) -> Array:
	for r in list:
		if r[0] == id:
			return r
	return []

static func block_text(b: Dictionary) -> String:
	var n: int = b.get("n", 1)
	var per: String = b.get("per", "")
	var div: int = max(1, b.get("div", 1))
	var x: String = _row(PERS, per)[1] if per != "" and not _row(PERS, per).is_empty() else ""
	var amt := str(n)
	var tail := ""   # " per 3 Intellect", put after the unit
	var equal := false
	if per != "":
		if n == 1 and div == 1 and per in ["might", "skill", "intellect"]:
			equal = true
		else:
			tail = " per %s%s" % [("%d " % div) if div > 1 else "", x]
	match b.get("do", ""):
		"gain":
			var r: String = b.get("res", "gold")
			var rn: String = "XP" if r == "xp" else r
			return ("gain %s equal to %s" % [rn, x]) if equal else "+%s %s%s" % [amt, rn, tail]
		"power":
			return ("gain Power equal to %s" % x) if equal else "+%s Power%s" % [amt, tail]
		"might":
			return ("+Might equal to %s" % x) if equal else "+%s Might%s" % [amt, tail]
		"might_others":
			return "your other attackers get +%s Might%s" % [amt, tail]
		"xp_others":
			return "+%s XP%s to your other mercenaries%s" % [amt, tail, "" if b.get("when", "") == "activate" else " in the group"]
		"xp_choose":
			return "%s other mercenar%s of yours gain%s 1 XP" % [n, "y" if n == 1 else "ies", "s" if n == 1 else ""]
		"wall":
			return "ignore walls" if n >= 99 else "target wall -%d defense" % n
		"special":
			var sp := _row(SPECIALS, b.get("code", ""))
			if sp.is_empty():
				return "(unknown special)"
			return sp[1] % n if "%d" in sp[1] else sp[1]
	return ""

static func abil_text(blocks: Array) -> String:
	var parts := []
	var last := ""
	for b in blocks:
		var w: String = b.get("when", "")
		var t := block_text(b)
		if w == last and not parts.is_empty():
			parts[-1] = parts[-1].trim_suffix(".") + ", " + t + "."
		else:
			var pre: String = _row(TRIGGERS, w)[1] if not _row(TRIGGERS, w).is_empty() else ""
			if pre == "":
				parts.append(t.substr(0, 1).to_upper() + t.substr(1) + ".")
			else:
				parts.append(pre + " " + t + ".")
		last = w
	return " ".join(parts)

## Card text for mercenaries and equipment, written from their stats and ability blocks.
static func refresh_texts() -> void:
	for id in MERCS:
		var m: Dictionary = MERCS[id]
		m.text = []
		for lv in 3:
			m.text.append(abil_text(m.abil[lv]))
	for id in ITEMS:
		var it: Dictionary = ITEMS[id]
		if it.kind != "equip":
			continue
		var parts := []
		for i in 3:
			if it.stats[i] != 0:
				parts.append("%s %+d" % [STAT_NAMES[i], it.stats[i]])
		var t := ". ".join(parts) + ("." if not parts.is_empty() else "")
		var a := abil_text(it.get("abil", []))
		it.text = (t + " " + a).strip_edges()
