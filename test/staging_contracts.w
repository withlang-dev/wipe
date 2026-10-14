//! expect-stdout: UAT passed: the pool widens by accomplishment, a fresh card is met
use game
use tuning
use loadout
use save
use account
use pilots

fn unlocked_counts(s: &Save) -> (i32, i32):
    let l = launch_for(.Claw, s, false)
    var w = 0
    var p = 0
    for i in 0..BASE_WEAPON_COUNT:
        if l.unlocked_weapons[i]: w += 1
    for i in 0..PASSIVE_COUNT:
        if l.unlocked_passives[i]: p += 1
    (w, p)

fn offers_of(fresh: bool, seed: i32) -> i32:
    // Level up thirty times from a fresh ship and count the Lance cards.
    var g = Game.new(Rules {})
    var launch = Launch { ship: .Claw }
    for i in 0..5: launch.unlocked_weapons[i] = true
    launch.unlocked_weapons[Weapon.Lance.index()] = true
    launch.fresh_weapons[Weapon.Lance.index()] = fresh
    for i in 0..8: launch.unlocked_passives[i] = true
    g.rng = 9000 +% (seed as u32) *% 2654435761
    g.start(launch)
    var seen = 0
    for _ in 0..30:
        // The level-up opens on the next tick.
        g.gain_xp(g.xp_next)
        g.tick(Controls {}, 1.0 / 120.0)
        for i in 0..g.offer_count:
            match g.offers[i].pick:
                .NewWeapon(w) => { if w == Weapon.Lance: seen += 1 }
                _ => ()
        // Take an upgrade or a passive, never a new weapon, so the slots
        // stay open and the Lance stays new.
        var pick = -1
        for i in 0..g.offer_count:
            let is_new = match g.offers[i].pick:
                .NewWeapon(_) => true
                _ => false
            if not is_new and pick < 0: pick = i
        if pick < 0:
            for i in 0..g.offer_count:
                match g.offers[i].pick:
                    .NewWeapon(w) => { if w != Weapon.Lance and pick < 0: pick = i }
                    _ => ()
        if pick < 0: pick = 0
        g.choose(pick)
    seen

fn main:
    // A fresh account drafts from five weapons and eight passives.
    let fresh = Save {}
    assert(unlocked_counts(&fresh) == (5, 8))
    assert(pool_tier(&fresh) == 1)
    // Surviving 5:00 opens the Lance and the Mines: seven weapons, tier 2.
    var five = Save {}
    five.best_time[0] = 300.0
    assert(unlocked_counts(&five) == (7, 8))
    assert(pool_tier(&five) == 2)
    // A first boss opens Cooldown at three; the lifetime counters follow.
    var fought = five
    fought.bosses = 3
    fought.hits = 40
    fought.caches = 5
    fought.banked = 2000
    // ...and the first boss opens the Gravity Well.
    // ...the first boss opens the Gravity Well, three caches the Turret.
    assert(unlocked_counts(&fought) == (9, 12))
    // Stamping records the run a condition was met; the card is fresh for
    // two runs and until it is picked.
    var after = five
    after.runs = 4
    let stamped = stamp_unlocks(&fresh, after)
    assert(stamped.weapon_unlocked_run[Weapon.Lance.index()] == 4)
    assert(stamped.weapon_unlocked_run[Weapon.Cannon.index()] == 0)
    assert(launch_for(.Claw, &stamped, false).fresh_weapons[Weapon.Lance.index()])
    var later = stamped
    later.runs = 6
    assert(not launch_for(.Claw, &later, false).fresh_weapons[Weapon.Lance.index()])
    var picked = stamped
    picked.taken_weapons[Weapon.Lance.index()] = true
    assert(not launch_for(.Claw, &picked, false).fresh_weapons[Weapon.Lance.index()])
    let again = stamp_unlocks(&stamped, later)
    assert(again.weapon_unlocked_run[Weapon.Lance.index()] == 4)
    // A fresh card comes up more: over thirty level-ups and four seeds.
    var plain = 0
    var boosted = 0
    for seed in 0..4:
        plain += offers_of(false, seed)
        boosted += offers_of(true, seed)
    assert(boosted > plain)
    assert(boosted >= 8)
    // The draw stays seeded: the same seed offers the same cards.
    assert(offers_of(true, 7) == offers_of(true, 7))
    print("UAT passed: the pool widens by accomplishment, a fresh card is met")
