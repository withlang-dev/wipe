//! expect-stdout: UAT passed: the Keeper sits at the middle, bites outside its sector, is soft only from inside, jumps after a tell, and narrows at desperation
use game
use tuning
use loadout
use ships
use pilots

// A Claw at the late slot with nothing else spawning, the Keeper up.
fn with_keeper(seed: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.rng = 5151 +% (seed as u32) *% 2654435761
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    launch.unlocked_passives[0] = true
    g.start(launch)
    g.rules.spawn_scale = 0.0
    g.rules.contact_radius = 0.0
    g.spawn_timer = 1.0e9
    g.next_elite = 1.0e9
    g.next_tank = 1.0e9
    g.event_index = 12
    g.xp_next = 1000000000
    g.build.weapons[0].level = 0
    g.max_health = 1000
    g.health = 1000
    g.jump_to(900.0)
    g.boss_index = 3
    g.spawn_boss_of(4)
    g

fn boss_at(g: &Game) -> i32:
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Boss: return i
    -1

// Hold the ship at a bearing from the boss, inside or outside its sector.
fn held(g_in: Game, seconds: f64, inside: bool) -> Game:
    var g = g_in
    for _ in 0..(seconds * 120.0) as i32:
        let b = boss_at(&g)
        let e = g.enemies[b]
        let a = e.angle + (if inside: 0.0 else: 3.14159265)
        g.player = add(e.pos, V2 { x: cos(a) * 180.0, y: sin(a) * 180.0 })
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    g

fn main:
    // It walks to the middle and sits.
    var sit = with_keeper(1)
    sit = held(sit, 20.0, true)
    let b = boss_at(&sit)
    assert(length2(sub(sit.enemies[b].pos, sit.center())) < 30.0 * 30.0)
    // Inside the sector: no bite, full damage. Outside: the bite, a quarter.
    var inside = with_keeper(2)
    inside = held(inside, 25.0, true)
    assert(inside.health == 1000)
    let bi = boss_at(&inside)
    let hp: i32 = inside.enemies[bi].hp
    let _ = inside.damage_enemy(bi, 40, V2 { x: 1.0 })
    assert(inside.enemies[bi].hp == hp - 40)
    var outside = with_keeper(2)
    outside = held(outside, 25.0, false)
    assert(outside.health < 1000)
    let bo = boss_at(&outside)
    let hp2: i32 = outside.enemies[bo].hp
    let _ = outside.damage_enemy(bo, 40, V2 { x: 1.0 })
    assert(outside.enemies[bo].hp == hp2 - 10)
    // The jump: a tell two seconds before, then a quarter turn beyond the
    // slow turn.
    // (The spawn's hit-stop shifts the clock, so the tell is awaited.)
    var jump = with_keeper(3)
    var waited = 0.0
    while jump.enemies[boss_at(&jump)].state != 1 and waited < KEEPER_JUMP + 5.0:
        jump = held(jump, 0.1, true)
        waited += 0.1
    assert(jump.enemies[boss_at(&jump)].state == 1)
    let before: f64 = jump.enemies[boss_at(&jump)].angle
    jump = held(jump, KEEPER_TELL + 0.1, true)
    let turned = jump.enemies[boss_at(&jump)].angle - before
    assert(turned > 1.5 and turned < 1.8)
    assert(jump.enemies[boss_at(&jump)].state == 0)
    // Desperation narrows the sector and reverses the turn at the jump.
    var late = with_keeper(4)
    late.enemies[boss_at(&late)].age = DESPERATION + 1.0
    var half = KEEPER_SECTOR
    if let Some((_, _, h)) = late.keeper_sector(): half = h
    assert(half < KEEPER_SECTOR)
    late = held(late, KEEPER_JUMP + 3.0, true)
    assert(late.enemies[boss_at(&late)].flank)
    // Exact replay.
    let a = held(with_keeper(5), 30.0, false)
    let c = held(with_keeper(5), 30.0, false)
    assert(a.health == c.health and a.enemies[boss_at(&a)].angle == c.enemies[boss_at(&c)].angle)
    print("UAT passed: the Keeper sits at the middle, bites outside its sector, is soft only from inside, jumps after a tell, and narrows at desperation")
