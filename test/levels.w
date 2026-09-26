//! expect-stdout: UAT passed: every weapon level improves a stat
use loadout
// Every level-up card must change something: a level that changes nothing
// is a wasted pick.
fn main:
    var dead = 0
    // Merges are final and have no levels; every base weapon level counts.
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        var prev = weapon_stats(w, 1, Mods {})
        for level in 2..(MAX_WEAPON_LEVEL + 1):
            let s = weapon_stats(w, level, Mods {})
            let better = s.damage > prev.damage or s.cooldown < prev.cooldown or s.count > prev.count or s.radius > prev.radius or s.pierce > prev.pierce or s.chain > prev.chain or s.bounces > prev.bounces or s.max_active > prev.max_active
            if not better:
                print(f"{w.name()} {level - 1} to {level} improves nothing")
                dead += 1
            prev = s
    assert(dead == 0)
    print("UAT passed: every weapon level improves a stat")
