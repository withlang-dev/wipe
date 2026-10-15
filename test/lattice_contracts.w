//! expect-stdout: UAT passed: the Lattice keeps its ring, is always soft, leaves a gap in every spiral, and narrows it at desperation
use game
use tuning
use loadout
use ships
use pilots

// A Claw at the mid slot with nothing else spawning, the Lattice up.
fn with_lattice(seed: i32) -> Game:
    var g = Game.new(Rules { minimum_start: 0.0 })
    g.rng = 4747 +% (seed as u32) *% 2654435761
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
    g.jump_to(600.0)
    g.boss_index = 2
    g.spawn_boss_of(3)
    g

fn boss_at(g: &Game) -> i32:
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Boss: return i
    -1

fn still(g_in: Game, seconds: f64) -> Game:
    var g = g_in
    for _ in 0..(seconds * 120.0) as i32:
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    g

// The widest empty arc, in radians, among the headings of the hostile
// shots the boss has in the air.
fn widest_gap(g: &Game) -> f64:
    var angles: List[f64] = List.new()
    for i in 0..g.bullet_count:
        let b = g.bullets[i]
        if b.hostile: angles.push(atan2(b.vel.y, b.vel.x))
    if angles.len() < 4: return 6.2832
    // Sort, then walk the circle.
    for i in 0..angles.len() as i32:
        for j in 0..angles.len() as i32 - 1 - i:
            if angles[j] > angles[j + 1]:
                let t: f64 = angles[j]
                angles[j] = angles[j + 1]
                angles[j + 1] = t
    var widest = 0.0
    for i in 0..angles.len() as i32 - 1:
        let d = angles[i + 1] - angles[i]
        if d > widest: widest = d
    let wrap = angles[0] + 6.2831853 - angles[angles.len() as i32 - 1]
    if wrap > widest: widest = wrap
    widest

// Through one spiral, the ship is held in the gap (walking with it) or
// held still on a spoke the gap never reaches; whether it is ever hurt.
fn hit_in_spiral(walk: bool) -> bool:
    var g = with_lattice(2)
    g.enemies[boss_at(&g)].eaten = 0
    // The boss holds still, so the spokes are the geometry alone.
    g.enemies[boss_at(&g)].speed = 0.0
    g.max_health = 1000
    g.health = 1000
    var hurt = false
    var started = -1.0
    for _ in 0..(120 * 5):
        let b = boss_at(&g)
        let e = g.enemies[b]
        if e.state == 1 and started < 0.0: started = g.elapsed
        if started >= 0.0:
            let into = g.elapsed - started
            let a = if walk: g.lattice_gap_at(e, into) else: e.angle + 12.0 * 0.35
            g.player = add(e.pos, V2 { x: cos(a) * 200.0, y: sin(a) * 200.0 })
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
        if g.hurt_event: hurt = true
        var near = 0
        for i in 0..g.bullet_count:
            if g.bullets[i].hostile and length2(sub(g.bullets[i].pos, g.player)) < 40.0 * 40.0: near += 1
        if walk and g.hurt_event and started >= 0.0:
            let b2 = boss_at(&g)
            let e2 = g.enemies[b2]
            let ship_a = atan2(g.player.y - e2.pos.y, g.player.x - e2.pos.x)
            eprint(f"HIT t {g.elapsed - started} ship heading {ship_a} gap now {g.lattice_gap_at(e2, g.elapsed - started)} boss angle {e2.angle} state {e2.state} eaten {e2.eaten} bullets {g.bullet_count}")
    hurt

fn main:
    // The ring: once it has arrived, a still ship is neither hugged nor fled.
    var ring = with_lattice(1)
    assert(boss_at(&ring) >= 0 and ring.boss_alive)
    ring = still(ring, 15.0)
    let b = boss_at(&ring)
    let distance = sqrt(length2(sub(ring.enemies[b].pos, ring.player)))
    assert(distance > 200.0 and distance < 520.0)
    // Always soft: ten points of damage take ten.
    let hp: i32 = ring.enemies[b].hp
    let _ = ring.damage_enemy(b, 10, V2 { x: 1.0 })
    assert(ring.enemies[b].hp == hp - 10)
    // The spiral leaves a gap that walks: a ship walking with it, two
    // hundred pixels out, is never hit through the whole pattern; a ship
    // standing on a spoke outside it is.
    assert(not hit_in_spiral(true))
    assert(hit_in_spiral(false))
    // At desperation the spiral is denser: more shots in the air at its end.
    var early = with_lattice(2)
    early.enemies[boss_at(&early)].eaten = 0
    early = still(early, 1.0 + 3.0)
    var late = with_lattice(2)
    late.enemies[boss_at(&late)].age = DESPERATION + 1.0
    late.enemies[boss_at(&late)].eaten = 0
    late = still(late, 1.0 + 3.0)
    assert(late.bullet_count > early.bullet_count)
    // Desperate, it closes its ring.
    var close = with_lattice(1)
    close.enemies[boss_at(&close)].age = DESPERATION + 1.0
    close = still(close, 15.0)
    let near = sqrt(length2(sub(close.enemies[boss_at(&close)].pos, close.player)))
    assert(near < LATTICE_FAR * LATTICE_DESPERATE_RING + 40.0)
    assert(widest_gap(&early) < 6.0 and widest_gap(&late) < 6.0)
    // Exact replay.
    let a = still(with_lattice(3), 12.0)
    let c = still(with_lattice(3), 12.0)
    assert(a.bullet_count == c.bullet_count and a.enemies[boss_at(&a)].pos.x == c.enemies[boss_at(&c)].pos.x)
    print("UAT passed: the Lattice keeps its ring, is always soft, leaves a gap in every spiral, and narrows it at desperation")
