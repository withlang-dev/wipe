//! expect-stdout: UAT passed: every weapon and merge level improves a stat
use loadout
// Every level-up card must change something: a merge's level II once read
// the same stats as its level I.
fn main:
    var dead = 0
    for i in 0..WEAPON_COUNT:
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
    print("UAT passed: every weapon and merge level improves a stat")
