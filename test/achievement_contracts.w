//! expect-stdout: UAT passed: achievements from the save
use save
use achievements

fn main:
    // A new player has earned nothing.
    assert(earned(&Save {}).len() == 0)
    // The IDs are the Steamworks API names: one per entry, never repeated.
    assert(ACHIEVEMENT_IDS.len() as i32 == ACHIEVEMENT_COUNT)
    for i in 0..ACHIEVEMENT_COUNT:
        for j in i + 1..ACHIEVEMENT_COUNT:
            assert(ACHIEVEMENT_IDS[i] != ACHIEVEMENT_IDS[j])
    // A first clear earns exactly the clear and the map it opens.
    let first = earned(&Save { clears: 1 })
    assert(first.len() == 2)
    assert(first[0] == "MAP_CORRIDOR" and first[1] == "FIRST_CLEAR")
    // An account that has done everything has earned every achievement.
    var s = Save {
        clears: 3, no_reboot_clear: true, null_killed: true, best_combo: 3000,
        best_hits_survived: 40, bounced_kills: 500, cores: 10000, best_merges_in_run: 2,
        elites: 60, bosses: 12, best_level: 40, kills: 40000, caches: 10, banked: 5000,
        hits: 100, merges: 3, runs: 100,
    }
    for i in 0..8: s.held[i] = 1200.0
    for i in 0..9: s.best_time[i] = 1200.0
    for i in 0..3: s.boss_slain[i] = true
    let all = earned(&s)
    if all.len() as i32 != ACHIEVEMENT_COUNT:
        for id in ACHIEVEMENT_IDS:
            if not achievement_met(id, &s): eprint(f"not earned: {id}")
    assert(all.len() as i32 == ACHIEVEMENT_COUNT)
    print("UAT passed: achievements from the save")
