//! expect-stdout: UAT passed: the Warden at five, a mid draw at ten, a late draw at fifteen, never twice; Boss Rush in order; Endless draws, then pairs
use game
use tuning
use loadout
use ships
use pilots

// A Claw with nothing else spawning, on a stage, endless or not.
fn quiet(rules: Rules, seed: i32, endless: bool) -> Game:
    var g = Game.new(rules)
    g.rng = 7171 +% (seed as u32) *% 2654435761
    var launch = Launch { endless }
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
    g.max_health = 100000
    g.health = 100000
    g.build.weapons[0].level = 0
    g

fn bosses_up(g: &Game) -> List[i32]:
    var out: List[i32] = List.new()
    for i in 0..g.enemy_count:
        if g.enemies[i].kind == .Boss and g.enemies[i].boss >= 0: out.push(g.enemies[i].boss)
    out

// Jump just short of a minute, tick into it, and name the boss that arrives.
fn arrive(g_in: Game, minute: f64) -> (Game, i32):
    var g = g_in
    g.jump_to(minute * 60.0 - 0.5)
    for _ in 0..120:
        g.clear_events()
        g.tick(Controls {}, 1.0 / 120.0)
    let up = bosses_up(&g)
    assert(up.len() >= 1)
    (g, up[0])

// Kill every boss up.
fn slay(g_in: Game) -> Game:
    var g = g_in
    var i = 0
    while i < g.enemy_count:
        if g.enemies[i].kind == .Boss:
            g.enemies[i].hp = 1
            if g.damage_enemy(i, 100, V2 { x: 1.0 }): continue
        i += 1
    g.freeze = 0.0
    assert(not g.boss_alive)
    g

fn main:
    // The Field: the Warden, then a mid draw, then a late draw, never twice.
    var seen_mid = [false; 6]
    var seen_late = [false; 6]
    for seed in 0..12:
        var g = quiet(Stage.Field.rules(), seed, false)
        let (g1, first) = arrive(g, 5.0)
        assert(first == 0)
        g = slay(g1)
        let (g2, mid) = arrive(g, 10.0)
        assert(mid == 1 or mid == 3 or mid == 5)
        seen_mid[mid] = true
        g = slay(g2)
        let (g3, late) = arrive(g, 15.0)
        assert(late == 2 or late == 4 or late == 5)
        assert(late != mid)
        seen_late[late] = true
        g = g3
    // Twelve seeds see every pool member.
    assert(seen_mid[1] and seen_mid[3] and seen_mid[5])
    assert(seen_late[2] and seen_late[4] and seen_late[5])
    // The draw replays exactly.
    let (_, a) = arrive(quiet(Stage.Field.rules(), 3, false), 10.0)
    let (_, b) = arrive(quiet(Stage.Field.rules(), 3, false), 10.0)
    assert(a == b)
    // Boss Rush: all six in verb order, three minutes apart, desperation at fifty.
    var rush = quiet(Stage.BossRush.rules(), 1, false)
    assert(rush.rules.desperation == 50.0)
    for k in 0..6:
        let (r, which) = arrive(rush, 3.0 * (k + 1) as f64)
        assert(which == k)
        rush = slay(r)
    // Endless: a boss at 25:00 drawn from all six; at 35:00, two at once.
    var endless = quiet(Stage.Field.rules(), 2, true)
    let (e1, one) = arrive(endless, 25.0)
    assert(one >= 0 and one < BOSS_COUNT and bosses_up(&e1).len() == 1)
    endless = slay(e1)
    let (e2, _) = arrive(endless, 35.0)
    let pair = bosses_up(&e2)
    assert(pair.len() == 2 and pair[0] != pair[1])
    print("UAT passed: the Warden at five, a mid draw at ten, a late draw at fifteen, never twice; Boss Rush in order; Endless draws, then pairs")
