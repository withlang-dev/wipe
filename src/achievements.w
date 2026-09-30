use save
use ships
use loadout
use tuning
use account

// Achievements mirror the unlock list one-to-one, plus the bosses and the
// milestones (spec §15). Each is a fact of the save, so earning one is
// retroactive and offline-safe, and a platform (Steam) only mirrors what the
// save already says. The IDs are the Steamworks API names: permanent, never
// renamed after release.
pub const ACHIEVEMENT_COUNT: i32 = 29
pub const ACHIEVEMENT_IDS: [str; 29] = [
    "SHIP_DART", "SHIP_HULL", "SHIP_PRISM", "SHIP_HALO", "SHIP_NEEDLE", "SHIP_SAPPER", "SHIP_PHASE", "SHIP_NULL",
    "WEAPON_LANCE", "WEAPON_MINES", "WEAPON_SHARD",
    "PASSIVE_COOLDOWN", "PASSIVE_ARMOR", "PASSIVE_LUCK", "PASSIVE_CREDIT", "PASSIVE_REBOUND", "PASSIVE_OVERCLOCK",
    "MAP_CORRIDOR", "MAP_SHAFT", "MAP_RING", "MAP_CROSS",
    "BOSS_WARDEN", "BOSS_LANCER", "BOSS_HIVE",
    "FIRST_CLEAR", "FIRST_MERGE", "RUNS_10", "RUNS_50", "RUNS_100",
]

pub fn achievement_met(id: &str, s: &Save) -> bool:
    if id == "SHIP_DART": return ship_unlocked(.Dart, s)
    if id == "SHIP_HULL": return ship_unlocked(.Hull, s)
    if id == "SHIP_PRISM": return ship_unlocked(.Prism, s)
    if id == "SHIP_HALO": return ship_unlocked(.Halo, s)
    if id == "SHIP_NEEDLE": return ship_unlocked(.Needle, s)
    if id == "SHIP_SAPPER": return ship_unlocked(.Sapper, s)
    if id == "SHIP_PHASE": return ship_unlocked(.Phase, s)
    if id == "SHIP_NULL": return ship_unlocked(.Null, s)
    if id == "WEAPON_LANCE": return met(weapon_condition(.Lance), s)
    if id == "WEAPON_MINES": return met(weapon_condition(.Mines), s)
    if id == "WEAPON_SHARD": return met(weapon_condition(.Shard), s)
    if id == "PASSIVE_COOLDOWN": return met(passive_condition(.Cooldown), s)
    if id == "PASSIVE_ARMOR": return met(passive_condition(.Armor), s)
    if id == "PASSIVE_LUCK": return met(passive_condition(.Luck), s)
    if id == "PASSIVE_CREDIT": return met(passive_condition(.Credit), s)
    if id == "PASSIVE_REBOUND": return met(passive_condition(.Rebound), s)
    if id == "PASSIVE_OVERCLOCK": return met(passive_condition(.Overclock), s)
    if id == "MAP_CORRIDOR": return stage_unlocked(.Corridor, s)
    if id == "MAP_SHAFT": return stage_unlocked(.Shaft, s)
    if id == "MAP_RING": return stage_unlocked(.Ring, s)
    if id == "MAP_CROSS": return stage_unlocked(.Cross, s)
    if id == "BOSS_WARDEN": return s.boss_slain[0]
    if id == "BOSS_LANCER": return s.boss_slain[1]
    if id == "BOSS_HIVE": return s.boss_slain[2]
    if id == "FIRST_CLEAR": return s.clears >= 1
    if id == "FIRST_MERGE": return s.merges >= 1
    if id == "RUNS_10": return s.runs >= 10
    if id == "RUNS_50": return s.runs >= 50
    if id == "RUNS_100": return s.runs >= 100
    false

// Every achievement the save has earned, in table order.
pub fn earned(s: &Save) -> Vec[str]:
    var out: Vec[str] = Vec.new()
    for id in ACHIEVEMENT_IDS:
        if achievement_met(id, s): out.push(id.clone())
    out
