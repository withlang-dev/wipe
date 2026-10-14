//! expect-stdout: UAT passed: five derelicts, five verbs, each recovered under control and recorded
use game
use tuning
use loadout
use save
use ships
use pilots

// A Claw on a stage, nothing spawning but the derelict's own.
fn on(stage: Stage, seed: i32) -> Game:
    var g = Game.new(stage.rules())
    g.rng = 2024 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    g.rules.spawn_scale = 0.0
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.boss_index = 3
    g.event_index = 12
    g.xp_next = 1000000000
    g

fn step(g_in: Game, motion: V2) -> Game:
    var g = g_in
    g.clear_events()
    g.tick(Controls { motion, aim: V2 { x: 1.0 } }, 1.0 / 120.0)
    g

fn main:
    // The Field has none; every stage with one places the wreck inside the arena.
    assert(Stage.Field.derelict().is_none())
    for s in [Stage.Corridor, Stage.Shaft, Stage.Cross, Stage.Expanse, Stage.Ring]:
        let g = on(s, 1)
        assert(g.wreck_live and not g.wreck_done)
        assert(g.in_arena(g.wreck, 0.0))
    // Black box: reaching the wreck wakes an escort; with it dead and the
    // ship at the wreck, the box is recovered and a cache drops.
    var box = on(.Corridor, 2)
    box.player = add(box.wreck, V2 { x: -300.0 })
    box = step(box, V2 {})
    assert(box.wreck_escort and box.enemy_count >= 10)
    assert(not box.wreck_done)
    for i in 0..box.enemy_count:
        if box.enemies[i].escort: box.enemies[i].hp = 1
    var i = 0
    while i < box.enemy_count:
        if box.enemies[i].escort:
            if box.damage_enemy(i, 5, V2 { x: 1.0 }): continue
        i += 1
    var standing = 0
    for k in 0..box.enemy_count:
        if box.enemies[k].escort: standing += 1
    assert(standing == 0)
    box.player = box.wreck
    box = step(box, V2 {})
    assert(box.wreck_done and box.derelict_event and box.pickup_count > 0)
    // Defend: a minute within reach, in all; standing off does not count.
    var hold = on(.Shaft, 3)
    hold.player = add(hold.wreck, V2 { y: 400.0 })
    for _ in 0..120: hold = step(hold, V2 {})
    assert(hold.wreck_progress == 0.0)
    hold.player = add(hold.wreck, V2 { y: 100.0 })
    for _ in 0..(60 * 120 + 5): hold = step(hold, V2 {})
    assert(hold.wreck_done)
    // Relays: three to light; two lit is not done.
    var cross = on(.Cross, 4)
    cross.player = cross.relays[0]
    cross = step(cross, V2 {})
    cross.player = cross.relays[1]
    cross = step(cross, V2 {})
    assert(cross.relays_lit[0] and cross.relays_lit[1] and not cross.wreck_done)
    cross.player = cross.relays[2]
    cross = step(cross, V2 {})
    assert(cross.wreck_done)
    // Chase: the wreck moves; three touches, five seconds apart, catch it.
    var chase = on(.Expanse, 5)
    let start: V2 = chase.wreck
    for _ in 0..60: chase = step(chase, V2 {})
    assert(chase.wreck.x != start.x or chase.wreck.y != start.y)
    for touch in 0..3:
        chase.player = chase.wreck
        chase = step(chase, V2 {})
        assert(chase.wreck_touches == touch + 1)
        chase.player = add(chase.wreck, V2 { x: 500.0 })
        for _ in 0..(5 * 120 + 2): chase = step(chase, V2 {})
    assert(chase.wreck_done)
    // Carrier: at two minutes an elite takes the core; killing it recovers it.
    var ring = on(.Ring, 6)
    ring.jump_to(119.5)
    for _ in 0..70: ring = step(ring, V2 {})
    var carrier = -1
    for k in 0..ring.enemy_count:
        if ring.enemies[k].carries: carrier = k
    assert(carrier >= 0 and ring.enemies[carrier].elite)
    ring.enemies[carrier].hp = 1
    let _ = ring.damage_enemy(carrier, 5, V2 { x: 1.0 })
    assert(ring.wreck_done)
    // The save records the stage's derelict, once.
    let (s, _) = record_run(Save {}, &ring)
    assert(s.derelicts[Stage.Ring.index()] and not s.derelicts[Stage.Corridor.index()])
    print("UAT passed: five derelicts, five verbs, each recovered under control and recorded")
