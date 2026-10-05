// Scripted players shared by the tests, the benches, and calibration, so
// every measurement uses the same bots.
use game
use tuning
use loadout
use ships

pub enum Style { | Stationary | Careful }
impl Copy for Style
impl Eq for Style

pub fn nearest_aim(g: &Game) -> V2:
    var aim = g.aim
    var best = 1.0e12
    for e in 0..g.enemy_count:
        let d = sub(g.enemies[e].pos, g.player)
        if length2(d) < best:
            best = length2(d)
            aim = d
    aim

// Keep distance from threats, sweep up cores when it is safe, stay off the
// walls, aim at the nearest enemy.
pub fn careful(g: &Game) -> Controls:
    var push = V2 {}
    var nearest = 1.0e12
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        let d = sub(g.player, e.pos)
        let d2 = length2(d)
        if d2 < nearest: nearest = d2
        let fear = if e.kind == .Boss or e.kind == .Null: 380.0 else: 230.0
        if d2 < fear * fear and d2 > 1.0: push = add(push, scale(d, 1.0 / d2 * (if e.kind == .Boss: 400.0 else: 90.0)))
    // Circle toward the Warden's back, its weak point.
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        if e.kind == .Boss and e.boss == 0:
            let behind = sub(e.pos, scale(e.facing, 300.0))
            push = add(push, scale(direction(sub(behind, g.player)), 1.6))
    // Step out of a telegraphed charge line.
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        if e.kind == .Boss and e.boss == 1 and (e.state == 1 or e.state == 2):
            let d = sub(g.player, e.pos)
            let along = d.x * e.facing.x + d.y * e.facing.y
            let side = perpendicular(e.facing)
            let off = d.x * side.x + d.y * side.y
            if along > -40.0 and off < 140.0 and off > -140.0:
                push = add(push, scale(side, if off >= 0.0: 6.0 else: -6.0))
    for i in 0..g.bullet_count:
        let b: Bullet = g.bullets[i]
        if not b.hostile: continue
        let d = sub(g.player, b.pos)
        let d2 = length2(d)
        if d2 < 160.0 * 160.0 and d2 > 1.0: push = add(push, scale(d, 1.0 / d2 * 160.0))
    var core_target = -1
    var core_best = 700.0 * 700.0
    for i in 0..g.core_count:
        let d2 = length2(sub(g.cores[i].pos, g.player))
        if d2 < core_best:
            core_best = d2
            core_target = i
    if core_target >= 0: push = add(push, scale(direction(sub(g.cores[core_target].pos, g.player)), if nearest < 40000.0: 0.3 else: 1.2))
    push = add(push, scale(sub(g.center(), g.player), 0.0007))
    let margin = 320.0
    let w = g.rules.arena_width
    let h = g.rules.arena_height
    if g.player.x < margin: push.x += (margin - g.player.x) / margin * 1.5
    if g.player.x > w - margin: push.x -= (g.player.x - (w - margin)) / margin * 1.5
    if g.player.y < margin: push.y += (margin - g.player.y) / margin * 1.5
    if g.player.y > h - margin: push.y -= (g.player.y - (h - margin)) / margin * 1.5
    Controls { motion: movement(scale(push, 3.0)), aim: nearest_aim(g) }

pub fn controls(g: &Game, style: Style) -> Controls:
    match style:
        .Stationary => Controls { aim: nearest_aim(g) }
        .Careful => careful(g)

// Card preference: a merge, then weapons already carried, then new weapons,
// then passives.
pub fn pick_card(g: &Game) -> i32:
    var best = 0
    var best_score = -1000.0
    for i in 0..g.offer_count:
        let o: Offer = g.offers[i]
        let score = match o.pick:
            .Merge(_) => 100.0
            .UpgradeWeapon(w) => 40.0 + (g.build.weapon_level(w) as f64)
            .NewWeapon(_) => 30.0
            .UpgradePassive(p) => 20.0 + (if p == .Damage or p == .FireRate or p == .Area: 5.0 else: 0.0)
            .NewPassive(p) => 15.0 + (if p == .Health or p == .Magnet: 4.0 else: 0.0)
        if score > best_score:
            best_score = score
            best = i
    best

// What a run looked like, for comparing people and bots.
pub type Stats {
    seconds: f64 = 0.0, died: bool = false, kills: i32 = 0, level: i32 = 1,
    hits: i32 = 0, first_hit: f64 = -1.0,
    hits_2min: i32 = 0, kills_1min: i32 = 0, kills_2min: i32 = 0,
}
impl Copy for Stats

extend Stats:
    // Call after every simulation tick.
    pub fn observe(mut self: Self, g: &Game):
        if g.hurt_event:
            self.hits += 1
            if self.first_hit < 0.0: self.first_hit = g.elapsed
            if g.elapsed < 120.0: self.hits_2min += 1
        if g.elapsed < 60.0: self.kills_1min = g.kills
        if g.elapsed < 120.0: self.kills_2min = g.kills
        self.seconds = g.elapsed
        self.kills = g.kills
        self.level = g.level
        self.died = g.phase == .Over and not g.cleared

// A fresh ship with every launch weapon and passive, the way the tests fly.
pub fn test_game(ship: Ship, seed: i32, rules: Rules = Rules {}) -> Game:
    var g = Game.new(rules)
    var launch = Launch { ship }
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.rng = 55555 +% (seed as u32) *% 2654435761
    g.start(launch)
    g

// Fly a game with a pilot until death or a time limit.
pub fn fly(start: Game, style: Style, seconds: f64) -> (Game, Stats):
    var g = start
    var stats = Stats {}
    while g.phase != .Over and g.elapsed < seconds:
        g.clear_events()
        g.tick(controls(&g, style), 1.0 / 120.0)
        stats.observe(&g)
        var guard = 0
        while g.phase == .Boost and guard < 20:
            guard += 1
            g.cache_reveal = 0.0
            g.choose(pick_card(&g))
    (g, stats)

// Kills per minute for one weapon alone against a steady swarm: the
// balance bench. The ship circles the center with an unkillable hull.
pub fn weapon_kills(weapon: Weapon, level: i32, minute: f64, seconds: f64, density: i32) -> i32:
    var total = 0
    for seed in 0..3:
        var g = Game.new(Rules { minimum_start: 0.0 })
        g.rng = 1234567 +% (seed as u32) *% 2654435761
        var launch = Launch {}
        for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
        for i in 0..8: launch.unlocked_passives[i] = true
        g.start(launch)
        g.build.weapons[0] = WeaponSlot { weapon, level }
        g.rules.contact_radius = 0.0
        g.spawn_timer = 1.0e9
        g.next_elite = 1.0e9
        g.boss_index = 3
        g.event_index = 12
        g.jump_to(minute * 60.0)
        g.xp_next = 1000000000
        g.max_health = 100000000
        g.health = 100000000
        let steps = (seconds * 120.0) as i32
        for i in 0..steps:
            while g.enemy_count < density: g.spawn_enemy()
            let t = i as f64 / 120.0
            let c = g.center()
            let goal = V2 { x: c.x + cos(t * 0.5) * 300.0, y: c.y + sin(t * 0.5) * 220.0 }
            g.clear_events()
            g.tick(Controls { motion: movement(scale(sub(goal, g.player), 1.0 / 60.0)), aim: nearest_aim(&g) }, 1.0 / 120.0)
            if g.phase == .Boost:
                g.pending_levels = 0
                g.pending_cache_items = 0
                g.phase = .Running
        total += g.kills * 60 / (seconds as i32)
    total / 3
