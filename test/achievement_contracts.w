//! expect-stdout: UAT passed: achievements from the save
use save
use achievements

fn main:
    // A new player has earned nothing.
    assert(earned(&Save {}).len() == 0)
    // The IDs are the Steamworks API names: one per entry, never repeated.
    assert(ACHIEVEMENT_IDS.len() as i32 == ACHIEVEMENT_COUNT)
    for i in 0..ACHIEVEMENT_COUNT:
        assert(achievement_name(i).len() > 0 and achievement_description(i).len() > 0)
        for j in i + 1..ACHIEVEMENT_COUNT:
            assert(ACHIEVEMENT_IDS[i] != ACHIEVEMENT_IDS[j])
    // A first clear earns exactly the clear; the maps open on levels reached
    // within a run, so level 12 earns the Corridor on its own.
    let first = earned(&Save { clears: 1 })
    assert(first.len() == 1 and first[0] == "FIRST_CLEAR")
    let opened = earned(&Save { best_level: 12 })
    assert(opened.len() == 1 and opened[0] == "MAP_CORRIDOR")
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
