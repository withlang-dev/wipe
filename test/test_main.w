//! expect-stdout: UAT passed: movement, aim, fire, collision, damage, death, restart, escalation, capacity, stress
use game
use tuning

fn near(actual: f64, expected: f64):
    assert(actual > expected - 0.001 and actual < expected + 0.001)

fn movement_uat:
    var g = Game.new()
    g.tick(Controls { motion: V2 { x: 1.0, y: 1.0 }, aim: V2 { x: 0.0, y: -1.0 } }, 0.1)
    near(sqrt(length2(sub(g.player, V2 { x: 640.0, y: 400.0 }))), 26.5)
    near(g.aim.y, -1.0)
    assert(g.bullet_count == 1)
    assert(g.bullets[0].vel.y < 0.0)
    assert(g.bullets[0].vel.x == 0.0)
    near(length2(movement(V2 { x: 0.25, y: 0.0 })), 0.0625)
    for _ in 0..1000: g.tick(Controls { motion: V2 { x: -1.0, y: -1.0 } }, 1.0 / 120.0)
    assert(g.player.x >= 36.0 and g.player.y >= 90.0)

fn combat_uat:
    assert(segment_hit(V2 {}, V2 { x: 100.0 }, V2 { x: 50.0, y: 3.0 }, 5.0))
    assert(not segment_hit(V2 {}, V2 { x: 100.0 }, V2 { x: 50.0, y: 6.0 }, 5.0))
    var g = Game.new()
    g.enemies[0] = Enemy { pos: V2 { x: 680.0, y: 400.0 }, age: 1.0, speed: 0.0 }
    g.enemy_count = 1
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.kills == 1 and g.enemy_count == 0)
    assert(g.bullet_count == 0 and g.particle_count >= 14)
    assert(g.kill_event and g.pulse_count == 1)
    // Sustained contact takes one health per invulnerability interval.
    g.enemies[0] = Enemy { pos: g.player, age: 1.0, speed: 0.0 }
    g.enemy_count = 1
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.health == 2 and g.hurt_event)
    g.hurt()
    assert(g.health == 2)
    g.invulnerable = 0.0
    g.hurt()
    g.invulnerable = 0.0
    g.hurt()
    assert(g.health == 0 and g.death_event)
    let ended: f64 = g.elapsed
    let frozen: V2 = g.player
    for _ in 0..60: g.tick(Controls { motion: V2 { x: 1.0 } }, 1.0 / 120.0)
    near(g.elapsed, ended)
    near(g.player.x, frozen.x)
    g.reset()
    assert(g.health == 3 and g.kills == 0 and g.elapsed == 0.0)
    assert(g.enemy_count == 0 and g.bullet_count == 0 and g.particle_count == 0 and g.pulse_count == 0)
    assert(g.freeze == 0.0 and g.invulnerable == 0.0 and not g.death_event)
    g.tick(Controls {}, 1.0 / 120.0)
    assert(g.bullet_count == 1 and g.shot_event)

fn capacity_uat:
    var g = Game.new()
    g.stress()
    assert(g.enemy_count == 350)
    for _ in 0..1000: g.spawn_enemy()
    assert(g.enemy_count == ENEMY_CAP)
    g.burst(V2 {}, V2 {}, 3000, .Cyan, 1.0)
    assert(g.particle_count == PARTICLE_CAP)
    for _ in 0..100: g.pulse(V2 {}, 40.0, .Cyan)
    assert(g.pulse_count == PULSE_CAP)
    g.effects(1.0)
    assert(g.particle_count == 0 and g.pulse_count == 0)
    // Fire cadence and spawning run independently from rendering.
    g.reset()
    for _ in 0..120: g.tick(Controls { aim: V2 { x: 0.0, y: -1.0 } }, 1.0 / 120.0)
    near(g.elapsed, 1.0)
    assert(g.enemy_count > 0)
    g.reset()
    g.elapsed = 60.0
    g.spawn_timer = 0.0
    for _ in 0..120: g.tick(Controls {}, 1.0 / 120.0)
    assert(g.enemy_count >= 13)

fn cadence_uat:
    var g = Game.new()
    var shots = 0
    for _ in 0..120:
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
        if g.shot_event: shots += 1
    assert(shots >= 7 and shots <= 8)
    let rules = with Rules {} as mut r:
        r.player_speed = 100.0
        r.max_health = 5
    var tuned = Game.new(rules)
    tuned.tick(Controls { motion: V2 { x: 1.0 } }, 0.1)
    near(tuned.player.x, 650.0)
    assert(tuned.health == 5)
    tuned.hurt()
    tuned.reset()
    assert(tuned.health == 5)

fn deterministic_uat:
    var first = Game.new()
    var second = Game.new()
    for frame in 0..600:
        let t = frame as f64 / 120.0
        let input = Controls { motion: V2 { x: cos(t), y: sin(t) }, aim: V2 { x: sin(t), y: cos(t) } }
        first.tick(input, 1.0 / 120.0)
        second.tick(input, 1.0 / 120.0)
    assert(first.rng == second.rng and first.kills == second.kills)
    assert(first.enemy_count == second.enemy_count and first.particle_count == second.particle_count)
    near(first.player.x, second.player.x)
    for i in 0..first.enemy_count:
        near(first.enemies[i].pos.x, second.enemies[i].pos.x)
        near(first.enemies[i].pos.y, second.enemies[i].pos.y)

fn main:
    movement_uat()
    combat_uat()
    capacity_uat()
    cadence_uat()
    deterministic_uat()
    print("UAT passed: movement, aim, fire, collision, damage, death, restart, escalation, capacity, stress")
