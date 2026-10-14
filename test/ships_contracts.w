//! expect-stdout: UAT passed: the roster, its conditions, the Ghost's lock, the Glass's hull
use ships
use loadout
use save
use account
use game
use tuning
use pilots

fn main:
    // Twenty-five ships, indices round-trip, the originals keep their places.
    assert(SHIP_COUNT == 26)
    for i in 0..SHIP_COUNT: assert(ship_at(i).index() == i)
    assert(Ship.Null.index() == 8 and Ship.Lasher.index() == 9 and Ship.Glass.index() == 24 and Ship.Mirror.index() == 25)
    // Every ship names a base weapon, three texts, and a condition met by an
    // account that has done everything.
    var done = Save {}
    done.clears = 3
    done.hurry_clears = 1
    done.null_killed = true
    done.no_reboot_clear = true
    done.best_combo = 3000
    done.best_hits_survived = 40
    done.bounced_kills = 500
    done.cores = 10000
    done.best_merges_in_run = 2
    done.elites = 60
    done.bosses = 12
    done.runs = 100
    for i in 0..SHIP_COUNT: done.best_time[i] = 1200.0
    for i in 0..BASE_WEAPON_COUNT: done.held[i] = 1200.0
    for i in 0..16: done.derelicts[i] = true
    for i in 0..16: done.stage_cleared[i] = true
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        assert(ship.name().len() > 0 and ship.strength().len() > 0 and ship.growth().len() > 0 and ship.weakness().len() > 0)
        assert(ship.base_weapon().is_base())
        assert(ship_unlocked(ship, &done))
    // A fresh account flies the Claw alone; four secrets stay hidden.
    assert(unlocked_ship_count(&Save {}) == 1)
    var secrets = 0
    for i in 0..SHIP_COUNT:
        if ship_at(i).secret(): secrets += 1
    assert(secrets == 4)
    // A derelict condition reads its stage; recovering it meets it.
    var found = Save {}
    assert(not ship_unlocked(.Lasher, &found))
    found.derelicts[Stage.Corridor.index()] = true
    assert(ship_unlocked(.Lasher, &found) and not ship_unlocked(.Anchor, &found))
    // The Ghost takes no new weapon before level 8; the Glass has one hull.
    let ghost = test_game(.Ghost, 1)
    var offered = false
    for p in ghost.build.candidates(ghost.level):
        match p:
            .NewWeapon(_) => offered = true
            _ => ()
    assert(not offered)
    for p in ghost.build.candidates(8):
        match p:
            .NewWeapon(_) => offered = true
            _ => ()
    assert(offered)
    let glass = test_game(.Glass, 1)
    assert(glass.max_health == 1 and glass.mods.damage > 2.9)
    // The Anchor is held as each well is laid: the first tick lays the
    // well (the ship still moves on it), then nothing moves the ship.
    var anchor = test_game(.Anchor, 2)
    anchor.clear_events()
    anchor.tick(Controls { motion: V2 { x: 1.0 }, aim: V2 { x: 1.0 } }, 1.0 / 120.0)
    let before: V2 = anchor.player
    for _ in 0..30:
        anchor.clear_events()
        anchor.tick(Controls { motion: V2 { x: 1.0 }, aim: V2 { x: 1.0 } }, 1.0 / 120.0)
    assert(anchor.well_count > 0)
    assert(anchor.player.x == before.x and anchor.player.y == before.y)
    print("UAT passed: the roster, its conditions, the Ghost's lock, the Glass's hull")
