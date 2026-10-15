//! expect-stdout: UAT passed: a boss kill is a merge when one is ready, a cache of what is missing, or a bounty
use game
use tuning
use loadout
use ships
use pilots

// A Claw at the Warden's minute with nothing else spawning, the boss up.
fn with_boss(seed: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.rng = 3131 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..PASSIVE_COUNT: launch.unlocked_passives[i] = true
    g.start(launch)
    g.rules.spawn_scale = 0.0
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.event_index = 12
    g.xp_next = 1000000000
    g.jump_to(300.0)
    g.boss_index = 1
    g.spawn_boss()
    g

fn boss_at(g: &Game) -> i32:
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Boss: return i
    -1

// Kill the boss, then fly onto its jackpot and collect it.
fn kill_and_collect(g_in: Game) -> Game:
    var g = g_in
    let b = boss_at(&g)
    assert(b >= 0)
    g.enemies[b].hp = 1
    let _ = g.damage_enemy(b, 50, V2 { x: 1.0 })
    assert(not g.boss_alive)
    var jackpot = -1
    for i in 0..g.pickup_count:
        match g.pickups[i].kind:
            .Jackpot(_) => jackpot = i
            _ => ()
    assert(jackpot >= 0)
    // The kill's hit-stop passes first; then the pickup is taken.
    g.player = g.pickups[jackpot].pos
    for _ in 0..90:
        var left = false
        for i in 0..g.pickup_count:
            match g.pickups[i].kind:
                .Jackpot(_) => left = true
                _ => ()
        if not left: break
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    // Taken: no jackpot remains (other drops may have landed meanwhile).
    for i in 0..g.pickup_count:
        match g.pickups[i].kind:
            .Jackpot(_) => assert(false)
            _ => ()
    g

fn main:
    // A ready merge: the kill names it, and the jackpot offers only merges.
    var ready = with_boss(1)
    ready.build.weapons[0] = WeaponSlot { weapon: .Cannon, level: MAX_WEAPON_LEVEL }
    ready.build.passives[0] = PassiveSlot { passive: .FireRate, level: 1 }
    assert(ready.boss_rung() == .MergeReady)
    ready = kill_and_collect(ready)
    assert(ready.phase == .Boost and ready.boost_source == .Jackpot(rung: .MergeReady))
    assert(ready.offer_count >= 1)
    for i in 0..ready.offer_count: assert(ready.offers[i].pick.is_merge())
    // No merge ready: a cache of three, each an upgrade to something carried
    // or a piece a recipe is missing.
    var missing = with_boss(2)
    missing.build.weapons[0] = WeaponSlot { weapon: .Cannon, level: 2 }
    assert(missing.boss_rung() == .Cache)
    assert(missing.build.is_piece(.NewPassive(passive: .FireRate)))
    assert(not missing.build.is_piece(.NewPassive(passive: .Armor)))
    missing = kill_and_collect(missing)
    assert(missing.phase == .Boost and missing.boost_source == .Jackpot(rung: .Cache))
    assert(missing.offer_count == 3)
    for i in 0..missing.offer_count:
        let p = missing.offers[i].pick
        let fits = match p:
            .UpgradeWeapon(_) => true
            .UpgradePassive(_) => true
            _ => missing.build.is_piece(p)
        assert(fits)
    // Nothing left to find: a bounty, paid at the kill and on collection.
    var full = with_boss(3)
    for i in 0..WEAPON_SLOTS: full.build.weapons[i] = WeaponSlot { weapon: weapon_at(BASE_WEAPON_COUNT + i), level: MAX_WEAPON_LEVEL }
    for i in 0..PASSIVE_SLOTS: full.build.passives[i] = PassiveSlot { passive: passive_at(i), level: MAX_PASSIVE_LEVEL }
    assert(full.boss_rung() == .Bounty)
    let before: i32 = full.credits
    full = kill_and_collect(full)
    // Twice the kill's sixty, plus the first kill's four hundred, and
    // whatever small change the kill's drops leave within reach.
    let paid: i32 = full.credits - before
    assert(paid >= 120 + 400 and paid < 120 + 400 + 20)
    assert(full.phase == .Running and full.invulnerable > 4.0 and full.wide_boost)
    // The bounty's promise: the next level deals five cards.
    // Room is made first: the deal needs a pool of more than five.
    full.build.weapons[1] = WeaponSlot { weapon: .Cannon, level: 1 }
    full.build.weapons[2] = WeaponSlot { level: 0 }
    full.build.passives[1] = PassiveSlot { passive: .Damage, level: 1 }
    full.build.passives[2] = PassiveSlot { level: 0 }
    full.xp_next = 1
    full.gain_xp(1)
    for _ in 0..60:
        if full.phase == .Boost: break
        full.clear_events()
        full.tick(Controls {}, 1.0 / 120.0)
    assert(full.phase == .Boost and full.offer_count == 5 and not full.wide_boost)
    // The kill and its jackpot replay exactly.
    var a = with_boss(4)
    var b = with_boss(4)
    a = kill_and_collect(a)
    b = kill_and_collect(b)
    assert(a.credits == b.credits and a.offer_count == b.offer_count)
    print("UAT passed: a boss kill is a merge when one is ready, a cache of what is missing, or a bounty")
