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
    // A Tether is a flail: the bot spins the stick, two turns a second.
    if g.build.weapons[0].weapon.family() == .Tether:
        let turn = g.elapsed * 12.57
        return V2 { x: cos(turn), y: sin(turn) }
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
        let e = g.enemies[i]
        let d = sub(g.player, e.pos)
        let d2 = length2(d)
        if d2 < nearest: nearest = d2
        let fear = if e.kind == .Boss or e.kind == .Null: 380.0 else: 230.0
        if d2 < fear * fear and d2 > 1.0: push = add(push, scale(d, 1.0 / d2 * (if e.kind == .Boss: 400.0 else: 90.0)))
    // Circle toward the Warden's back, its weak point.
    for i in 0..g.enemy_count:
        let e = g.enemies[i]
        if e.kind == .Boss and e.boss == 0:
            let behind = sub(e.pos, scale(e.facing, 300.0))
            push = add(push, scale(direction(sub(behind, g.player)), 1.6))
    // Step out of a telegraphed charge line.
    for i in 0..g.enemy_count:
        let e = g.enemies[i]
        if e.kind == .Boss and e.boss == 1 and (e.state == 1 or e.state == 2):
            let d = sub(g.player, e.pos)
            let along = d.x * e.facing.x + d.y * e.facing.y
            let side = perpendicular(e.facing)
            let off = d.x * side.x + d.y * side.y
            if along > -40.0 and off < 140.0 and off > -140.0:
                push = add(push, scale(side, if off >= 0.0: 6.0 else: -6.0))
    for i in 0..g.bullet_count:
        let b = g.bullets[i]
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
    // The Keeper: stay in the light. Outside its sector the pull to the
    // sector's middle line overrides most else; inside, a gentle hold.
    if let Some((middle, angle, _)) = g.keeper_sector():
        let goal = add(middle, V2 { x: cos(angle) * 220.0, y: sin(angle) * 220.0 })
        let weight = if g.in_keeper_sector(g.player): 0.8 else: 5.0
        push = add(push, scale(direction(sub(goal, g.player)), weight))
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
        let o = g.offers[i]
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

// One boss met in a run: whether the run reached it, how the fight went,
// and how much of it the pilot spent unable to hurt the boss, outside an
// explicit mechanic (the Hive's drones).
pub type Encounter {
    boss: i32 = -1, reached: bool = false, killed: bool = false, died: bool = false,
    ttk: f64 = 0.0, hull_lost: i32 = 0, max_hp: i32 = 0,
    // The longest stretch with no damage dealt, and the share of the
    // fight's whole seconds in which none was.
    streak: f64 = 0.0, share: f64 = 0.0,
}
impl Copy for Encounter

// Fly the careful bot through a run, measuring every boss it meets.
pub fn boss_run(start: Game, seconds: f64) -> List[Encounter]:
    var g = start
    var out = List.new()
    var current = Encounter {}
    var fighting = false
    var hp_before = 0
    var health_at_spawn = 0
    var idle = 0.0
    var idle_seconds = 0
    var counted_seconds = 0
    var second_dealt = false
    var second_mechanic = false
    var second_clock = 0.0
    var fight_start = 0.0
    while g.phase != .Over and g.elapsed < seconds:
        g.clear_events()
        g.tick(careful(&g), 1.0 / 120.0)
        var guard = 0
        while g.phase == .Boost and guard < 20:
            guard += 1
            g.cache_reveal = 0.0
            g.choose(pick_card(&g))
        if g.boss_alive and not fighting:
            fighting = true
            current = Encounter { boss: g.boss_index - 1, reached: true }
            // The boss itself, not the slot: pools draw.
            for i in 0..g.enemy_count:
                if g.enemies[i].kind == .Boss and g.enemies[i].boss >= 0: current.boss = g.enemies[i].boss
            if let Some((hp, max_hp)) = g.boss_health():
                hp_before = hp
                current.max_hp = max_hp
            health_at_spawn = g.health
            fight_start = g.elapsed
            idle = 0.0
            idle_seconds = 0
            counted_seconds = 0
            second_dealt = false
            second_mechanic = false
            second_clock = 0.0
        else if fighting:
            let dt = 1.0 / 120.0
            // Nothing dealt this tick: idle, unless a mechanic explains it.
            let mechanic = current.boss == 2 and g.drones_alive() > 0
            var hp_now = 0
            if let Some((hp, _)) = g.boss_health(): hp_now = hp
            let dealt = hp_now < hp_before
            if mechanic:
                second_mechanic = true
                idle = 0.0
            else if dealt: idle = 0.0
            else if g.boss_alive:
                idle += dt
                if idle > current.streak: current.streak = idle
            if dealt: second_dealt = true
            // Whole seconds: one with no damage and no mechanic counts idle.
            second_clock += dt
            if second_clock >= 1.0:
                second_clock -= 1.0
                if not second_mechanic:
                    counted_seconds += 1
                    if not second_dealt: idle_seconds += 1
                second_dealt = false
                second_mechanic = false
            hp_before = hp_now
            let lost: i32 = health_at_spawn - g.health
            if lost > current.hull_lost: current.hull_lost = lost
            if not g.boss_alive or g.phase == .Over:
                fighting = false
                current.killed = not g.boss_alive and g.phase != .Over
                current.died = g.phase == .Over
                current.ttk = g.elapsed - fight_start
                current.share = if counted_seconds > 0: idle_seconds as f64 / counted_seconds as f64 else: 0.0
                out.push(current)
    if fighting:
        current.ttk = g.elapsed - fight_start
        out.push(current)
    out

// Kills per minute for one weapon alone against a steady swarm: the
// balance bench. The ship circles the center with an unkillable hull.
pub fn weapon_kills(weapon: Weapon, level: i32, minute: f64, seconds: f64, density: i32, seeds: i32 = 3) -> i32:
    pair_kills(weapon, None, level, minute, seconds, density, seeds)

// The same bench with a second weapon in the next slot, or none.
pub fn pair_kills(weapon: Weapon, second: Option[Weapon], level: i32, minute: f64, seconds: f64, density: i32, seeds: i32 = 3) -> i32:
    var total = 0
    for seed in 0..seeds:
        var g = Game.new(Rules { minimum_start: 0.0 })
        g.rng = 1234567 +% (seed as u32) *% 2654435761
        var launch = Launch {}
        for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
        for i in 0..8: launch.unlocked_passives[i] = true
        g.start(launch)
        g.build.weapons[0] = WeaponSlot { weapon, level }
        if let Some(other) = second: g.build.weapons[1] = WeaponSlot { weapon: other, level }
        g.rules.contact_radius = 0.0
        g.spawn_timer = 1.0e9
        g.next_elite = 1.0e9
        g.next_tank = 1.0e9
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
    total / seeds
