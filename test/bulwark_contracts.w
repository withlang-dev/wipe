//! expect-stdout: UAT passed: the Bulwark is soft everywhere, sheds a Tank a quarter, and at desperation walks twice as fast and rams after a tell
use game
use tuning
use loadout
use ships
use pilots

// A Claw at the mid slot with nothing else spawning, the Bulwark up.
fn with_bulwark(seed: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.rng = 6161 +% (seed as u32) *% 2654435761
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
    g.jump_to(600.0)
    g.boss_index = 2
    g.spawn_boss_of(5)
    // No hit-stop: the clock runs from the first tick. The boss starts
    // well inside the arena, west of the middle, where the ship is held.
    g.freeze = 0.0
    g.enemies[boss_at(&g)].pos = add(g.center(), V2 { x: -600.0 })
    g.player = g.center()
    g

fn boss_at(g: &Game) -> i32:
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Boss: return i
    -1

fn tanks(g: &Game) -> i32:
    var n = 0
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Tank: n += 1
    n

// Hold the ship at the arena's middle and tick.
fn away(g_in: Game, seconds: f64) -> Game:
    var g = g_in
    for _ in 0..(seconds * 120.0) as i32:
        g.player = g.center()
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    g

fn main:
    // Soft everywhere: a hit from the front and from behind take the same.
    var soft = with_bulwark(1)
    let b = boss_at(&soft)
    let hp: i32 = soft.enemies[b].hp
    let _ = soft.damage_enemy(b, 30, soft.enemies[b].facing)
    soft.enemies[b].hit_cd = 0.0
    let _ = soft.damage_enemy(b, 30, scale(soft.enemies[b].facing, -1.0))
    assert(soft.enemies[b].hp == hp - 60)
    // Plates: below three quarters a Tank is shed; below half, another.
    var plates = with_bulwark(2)
    let bp = boss_at(&plates)
    let full: i32 = plates.enemies[bp].max_hp
    assert(tanks(&plates) == 0)
    plates.enemies[bp].hp = full * 74 / 100
    plates = away(plates, 1.5)
    assert(tanks(&plates) == 1)
    plates.enemies[boss_at(&plates)].hp = full * 49 / 100
    plates = away(plates, 1.5)
    assert(tanks(&plates) == 2)
    // Desperation: the walk doubles, and a ram comes after a tell.
    var slow = with_bulwark(3)
    slow = away(slow, 3.0)
    let before: V2 = slow.enemies[boss_at(&slow)].pos
    slow = away(slow, 2.0)
    let walked = sqrt(length2(sub(slow.enemies[boss_at(&slow)].pos, before)))
    var fast = with_bulwark(3)
    fast.enemies[boss_at(&fast)].age = DESPERATION + 1.0
    fast = away(fast, 3.0)
    // Not mid-ram: measure a walking stretch.
    var walked_fast = 0.0
    var tried = 0
    while tried < 20:
        tried += 1
        if fast.enemies[boss_at(&fast)].state != 0:
            fast = away(fast, 0.5)
            continue
        let start: V2 = fast.enemies[boss_at(&fast)].pos
        fast = away(fast, 0.5)
        if fast.enemies[boss_at(&fast)].state == 0:
            walked_fast = sqrt(length2(sub(fast.enemies[boss_at(&fast)].pos, start))) * 4.0
            break
    assert(walked_fast > walked * 1.6)
    var rammed = false
    for _ in 0..(120 * 8):
        fast.player = fast.center()
        fast.clear_events()
        fast.tick(Controls {}, 1.0 / 120.0)
        if fast.enemies[boss_at(&fast)].state == 2: rammed = true
    assert(rammed)
    // Exact replay.
    let a = away(with_bulwark(4), 20.0)
    let c = away(with_bulwark(4), 20.0)
    assert(a.enemies[boss_at(&a)].pos.x == c.enemies[boss_at(&c)].pos.x and tanks(&a) == tanks(&c))
    print("UAT passed: the Bulwark is soft everywhere, sheds a Tank a quarter, and at desperation walks twice as fast and rams after a tell")
