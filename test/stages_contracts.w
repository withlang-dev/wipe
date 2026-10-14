//! expect-stdout: UAT passed: fifteen stages, each changing one thing, and replaying exactly
use game
use tuning
use loadout
use ships
use save
use account
use pilots

fn on(stage: Stage, seed: i32) -> Game:
    var g = Game.new(stage.rules())
    g.rng = 909 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    g

fn still(g_in: Game, seconds: f64) -> Game:
    var g = g_in
    for _ in 0..(seconds * 120.0) as i32:
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    g

fn main:
    assert(STAGE_COUNT == 15)
    for k in 0..STAGE_COUNT: assert(stage_at(k).index() == k and stage_at(k).rules().layout == k)
    // Every stage's walls stand inside it and its derelict, if any, too.
    for k in 0..STAGE_COUNT:
        let stage = stage_at(k)
        let r = stage.rules()
        for w in stage.walls(): assert(w.x >= 0.0 and w.y >= 0.0 and w.x + w.w <= r.arena_width and w.y + w.h <= r.arena_height)
    // The Bone Field: hull grows with the minute, four times at ten.
    var bone = on(.BoneField, 1)
    bone.jump_to(600.0)
    assert(bone.place_enemy(bone.center(), .Block))
    let field = Game.new(Stage.Field.rules())
    var plain = field
    plain.jump_to(600.0)
    plain.rules.flat_minute = 6.0
    assert(plain.place_enemy(plain.center(), .Block))
    assert(bone.enemies[0].max_hp >= plain.enemies[0].max_hp * 4 - 1 and bone.enemies[0].max_hp <= plain.enemies[0].max_hp * 4 + 1)
    // Collapse: the arena is half as wide at ten minutes; the ship is held inside.
    var fall = on(.Collapse, 2)
    assert(fall.edge_inset() == 0.0)
    fall.jump_to(600.0)
    let inset = fall.edge_inset()
    assert(inset > 500.0 and inset < 600.0)
    let held = fall.clamp_to_arena(V2 { x: 10.0, y: 10.0 }, 0.0)
    assert(held.x >= inset and held.y >= inset)
    assert(not fall.in_arena(V2 { x: 100.0, y: 100.0 }, 0.0))
    // Rotor: the sector turns once a minute; outside it the field bites.
    var rotor = on(.Rotor, 3)
    assert(rotor.rotor_angle() == 0.0)
    rotor.jump_to(30.0)
    assert(rotor.rotor_angle() > 3.14 and rotor.rotor_angle() < 3.15)
    let c = rotor.center()
    assert(rotor.in_safe_sector(add(c, V2 { x: -300.0 })))
    assert(not rotor.in_safe_sector(add(c, V2 { x: 300.0 })))
    rotor.rules.spawn_scale = 0.0
    rotor.spawn_timer = 1.0e9
    rotor.player = add(c, V2 { x: 300.0 })
    let hull: i32 = rotor.health
    var bitten = rotor
    for _ in 0..150:
        bitten.clear_events()
        bitten.tick(Controls {}, 1.0 / 120.0)
    assert(bitten.health < hull)
    // Boss Rush: a boss at 3:00 and nothing ordinary before it.
    var rush = on(.BossRush, 4)
    rush = still(rush, 30.0)
    assert(rush.enemy_count == 0)
    rush.jump_to(179.5)
    rush = still(rush, 1.0)
    assert(rush.boss_alive)
    // The Mirror: every spawn has its twin across the middle.
    var mirror = on(.Mirror, 5)
    mirror.rules.contact_radius = 0.0
    // No weapon, so nothing dies, and no enemy speed, so the twins stay
    // where they spawned.
    mirror.build.weapons[0].level = 0
    mirror.rules.enemy_speed = 0.0
    mirror.rules.enemy_speed_variation = 0.0
    mirror = still(mirror, 2.0)
    assert(mirror.enemy_count >= 2)
    var twinned = 0
    for i in 0..mirror.enemy_count:
        for j in 0..mirror.enemy_count:
            if i != j and (mirror.enemies[i].pos.x + mirror.enemies[j].pos.x - mirror.rules.arena_width).abs() < 1.0 and (mirror.enemies[i].pos.y - mirror.enemies[j].pos.y).abs() < 1.0: twinned += 1
    assert(twinned >= 2)
    // Blackout is a drawing rule only: the simulation is the Field's at 10:00.
    let dark = Stage.Blackout.rules()
    assert(dark.blackout and dark.run_cap == 600.0)
    // Gates: challenge clears count, a stage cleared is recorded, Endless waits for the Null.
    var cleared = on(.BoneField, 6)
    cleared.cleared = true
    let (s, _) = record_run(Save {}, &cleared)
    assert(s.challenge_clears == 1 and s.stage_cleared[Stage.BoneField.index()])
    assert(not stage_unlocked(.Collapse, &s))
    var two = s
    two.challenge_clears = 2
    assert(stage_unlocked(.Collapse, &two) and stage_unlocked(.Rotor, &two))
    assert(met(.ClearStage(stage: .BoneField), &s) and not met(.ClearStage(stage: .Mirror), &s))
    // Exact replay on the stages with new mechanics.
    for st in [Stage.Collapse, Stage.Rotor, Stage.Mirror, Stage.BoneField]:
        let (a, sa) = fly(on(st, 7), .Careful, 45.0)
        let (b, sb) = fly(on(st, 7), .Careful, 45.0)
        assert(a.elapsed == b.elapsed and a.kills == b.kills and a.level == b.level and a.health == b.health and sa.seconds == sb.seconds)
    print("UAT passed: fifteen stages, each changing one thing, and replaying exactly")
