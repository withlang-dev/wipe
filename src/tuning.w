// Gameplay knobs live together. Presentation colors and geometry stay in
// presentation.w; changing these values never changes storage or ownership.
// Data tables (timeline, events) are functions of the minute so tuning is a
// number here and never a branch in system code.
pub type Rules {
    // Arena: a bounded, camera-followed rectangle measured in travel time at
    // base speed. 1100 px center-to-wall at 265 px/s is about four seconds.
    arena_width: f64 = 2200.0,
    arena_height: f64 = 1400.0,
    player_speed: f64 = 265.0,
    max_health: i32 = 10,
    run_cap: f64 = 1200.0,           // twenty minutes
    cannon_interval: f64 = 1.0 / 7.0,
    bullet_speed: f64 = 940.0,
    bullet_lifetime: f64 = 1.6,
    enemy_speed: f64 = 110.0,
    enemy_speed_variation: f64 = 32.0,
    spawn_grace: f64 = 0.15,
    bullet_hit_radius: f64 = 17.0,
    contact_radius: f64 = 29.0,
    invulnerability: f64 = 0.7,
    damage_stop: f64 = 0.045,
    death_stop: f64 = 0.14,
    level_stop: f64 = 0.10,
    merge_stop: f64 = 0.22,
    boss_stop: f64 = 0.13,
    magnet_radius: f64 = 110.0,
    core_speed: f64 = 520.0,
    core_merge_age: f64 = 3.0,
    combo_window: f64 = 1.0,
    // Camera lookahead toward the aim direction, in pixels.
    lookahead: f64 = 120.0,
    camera_ease: f64 = 6.0,
    // Timeline first-appearance minutes.
    dart_minute: f64 = 1.0,
    spinner_minute: f64 = 5.0,
    weaver_minute: f64 = 5.0,
    skimmer_minute: f64 = 8.0,
    well_minute: f64 = 12.0,
    first_elite: f64 = 240.0,
    elite_interval: f64 = 120.0,
    beacon_count: i32 = 3,
    beacon_respawn: f64 = 60.0,
    breather: f64 = 5.0,
    // Stage modifiers.
    spawn_scale: f64 = 1.0,
    speed_scale: f64 = 1.0,
    // A dead center: a circle at the arena's middle that nothing enters.
    void_radius: f64 = 0.0,
    // Which stage's walls this arena has (Stage.index).
    layout: i32 = 0,
    // Offer weights: an upgrade to an owned weapon or passive against a new card at 1.
    upgrade_weight: f64 = 5.0,
    new_weapon_weight: f64 = 2.5,
    // Lightning (Arc, Storm) damage multiplier, for tuning it up or down live.
    lightning_damage: f64 = 1.0,
    // Chance a kill drops a Repair pickup.
    repair_drop_chance: f64 = 0.0025,
    new_passive_weight: f64 = 0.6,
    // The floor of enemies alive at the start of a run (see minimum_alive).
    minimum_start: f64 = 22.0,
    passive_upgrade_weight: f64 = 0.8,
}

impl Copy for Rules

extend Rules:
    // Spawns per second at a minute of the run. The curve is gentle for two
    // minutes, then climbs so the view fills at fifteen minutes.
    pub fn spawn_rate(self: &Self, minute: f64) -> f64:
        // Clusters average two enemies, so these are cluster rates. The
        // minimum_alive floor carries the opening; this is the trickle.
        if minute < 2.0: 0.6 + minute * 0.3
        else: 1.2 + (minute - 2.0) * 0.5

    // Enemies kept alive: sixteen at the start, rising each minute.
    pub fn minimum_alive(self: &Self, minute: f64) -> f64:
        self.minimum_start + minute * 10.0 + minute * minute * 0.6

    // XP a level needs: early levels every thirty seconds, late ones every
    // minute or two against a rising kill rate.
    pub fn xp_for_level(self: &Self, level: i32) -> i32:
        let l = (level - 1) as f64
        // About a third more XP per level than before: fewer, heavier level-ups.
        (29.0 + l * 21.0 + l * l * 4.0) as i32

    // Bosses at five, ten, and fifteen minutes.
    pub fn boss_minutes(self: &Self) -> [f64; 3]: [5.0, 10.0, 15.0]

// A scripted set piece: a formation of one kind arriving from one side of
// the camera after a two second telegraph.
pub enum Formation { | Sweep | Ring | Spiral | Lattice }
impl Copy for Formation

pub type Event { minute: f64 = 0.0, formation: Formation = .Sweep, kind_index: i32 = 0, count: i32 = 24 }
impl Copy for Event

// Twelve events; each has its first minute here and nowhere else.
// kind_index follows game.kind_at: 0 Block, 1 Spinner, 2 Dart, 3 Weaver.
pub fn events() -> [Event; 12]:
    [
        Event { minute: 0.75, formation: .Ring, kind_index: 0, count: 16 },
        Event { minute: 4.0, formation: .Ring, kind_index: 2, count: 20 },
        Event { minute: 6.0, formation: .Sweep, kind_index: 0, count: 28 },
        Event { minute: 7.5, formation: .Spiral, kind_index: 1, count: 22 },
        Event { minute: 9.0, formation: .Ring, kind_index: 2, count: 30 },
        Event { minute: 11.0, formation: .Lattice, kind_index: 3, count: 16 },
        Event { minute: 12.5, formation: .Sweep, kind_index: 0, count: 40 },
        Event { minute: 13.5, formation: .Spiral, kind_index: 1, count: 30 },
        Event { minute: 14.5, formation: .Ring, kind_index: 2, count: 40 },
        Event { minute: 16.0, formation: .Lattice, kind_index: 3, count: 24 },
        Event { minute: 17.5, formation: .Sweep, kind_index: 0, count: 56 },
        Event { minute: 19.0, formation: .Ring, kind_index: 2, count: 56 },
    ]

// A solid block inside the arena: ships, enemies, cores, and shots stop at
// it. Stages are built from them.
pub type Wall { x: f64 = 0.0, y: f64 = 0.0, w: f64 = 0.0, h: f64 = 0.0 }
impl Copy for Wall

// Stages are arena shapes with walls and a rule modifier. Geometry is level
// design, and in an abstract game it costs no art. Indices are stable:
// recordings name stages by them.
pub enum Stage { | Field | Corridor | Shaft | Ring | Pillars | Maze | Expanse | Cross | Gridlock }
impl Copy for Stage
impl Eq for Stage

pub const STAGE_COUNT: i32 = 9

pub fn stage_at(index: i32) -> Stage:
    match index:
        0 => .Field
        1 => .Corridor
        2 => .Shaft
        3 => .Ring
        4 => .Pillars
        5 => .Maze
        6 => .Expanse
        7 => .Cross
        _ => .Gridlock

// Select-screen order: arenas, mazes, open, lanes.
pub fn stage_order() -> [Stage; 9]:
    [Stage.Field, Stage.Pillars, Stage.Ring, Stage.Cross, Stage.Maze, Stage.Gridlock, Stage.Expanse, Stage.Corridor, Stage.Shaft]

fn wall(x: f64, y: f64, w: f64, h: f64) -> Wall: Wall { x, y, w, h }

extend Stage:
    pub fn index(self: &Self) -> i32:
        match self:
            .Field => 0
            .Corridor => 1
            .Shaft => 2
            .Ring => 3
            .Pillars => 4
            .Maze => 5
            .Expanse => 6
            .Cross => 7
            .Gridlock => 8
    pub fn name(self: &Self) -> str:
        match self:
            .Field => "Field"
            .Corridor => "Corridor"
            .Shaft => "Shaft"
            .Ring => "Ring"
            .Pillars => "Pillars"
            .Maze => "Maze"
            .Expanse => "Expanse"
            .Cross => "Cross"
            .Gridlock => "Gridlock"
    pub fn kind(self: &Self) -> str:
        match self:
            .Field => "ARENA"
            .Pillars => "ARENA"
            .Ring => "ARENA"
            .Cross => "ARENA"
            .Maze => "MAZE"
            .Gridlock => "MAZE"
            .Expanse => "OPEN"
            .Corridor => "LANE"
            .Shaft => "LANE"
    pub fn describe(self: &Self) -> str:
        match self:
            .Field => "The open rectangle. Four seconds to any wall."
            .Corridor => "A horizontal corridor. Every fight is a sweep. +30% spawns."
            .Shaft => "A vertical shaft. Nowhere to circle. +20% enemy speed."
            .Ring => "A ring around a dead center. Every chase curves. +15% spawns."
            .Pillars => "An arena broken by six pillars: cover, and corners to be caught in."
            .Maze => "Walled corridors. The swarm comes around corners; dead ends are deadly."
            .Expanse => "Vast and open, a few rocks. Room to run, and nothing to stop the swarm."
            .Cross => "A plus-shaped hall. Four arms, one crossing where everything meets."
            .Gridlock => "City blocks and streets. Enemies flood the avenues."
    // True where enemies need a path around walls rather than a straight
    // chase: every stage with walls, or a ship could hide behind one.
    pub fn needs_paths(self: &Self) -> bool: self.walls().len() > 0
    pub fn rules(self: &Self) -> Rules:
        match self:
            .Field => Rules {}
            .Corridor => Rules { arena_width: 3600.0, arena_height: 720.0, spawn_scale: 1.3, layout: 1 }
            .Shaft => Rules { arena_width: 900.0, arena_height: 2600.0, speed_scale: 1.2, layout: 2 }
            .Ring => Rules { arena_width: 2000.0, arena_height: 2000.0, void_radius: 420.0, spawn_scale: 1.15, layout: 3 }
            .Pillars => Rules { arena_width: 2400.0, arena_height: 1600.0, layout: 4 }
            .Maze => Rules { arena_width: 3000.0, arena_height: 2000.0, layout: 5 }
            .Expanse => Rules { arena_width: 3800.0, arena_height: 2800.0, spawn_scale: 1.2, layout: 6 }
            .Cross => Rules { arena_width: 2600.0, arena_height: 2600.0, layout: 7 }
            .Gridlock => Rules { arena_width: 3200.0, arena_height: 2200.0, layout: 8 }
    pub fn walls(self: &Self) -> Vec[Wall]:
        var out: Vec[Wall] = Vec.new()
        match self:
            .Pillars => {
                for cx in [600.0, 1200.0, 1800.0]:
                    for cy in [480.0, 1120.0]: out.push(wall(cx - 75.0, cy - 75.0, 150.0, 150.0))
            }
            .Maze => {
                // Vertical baffles with staggered gaps, tied by short runs.
                out.push(wall(400.0, 0.0, 40.0, 700.0))
                out.push(wall(400.0, 1000.0, 40.0, 1000.0))
                out.push(wall(800.0, 300.0, 40.0, 1400.0))
                out.push(wall(800.0, 300.0, 400.0, 40.0))
                out.push(wall(1200.0, 700.0, 40.0, 1300.0))
                out.push(wall(1200.0, 700.0, 300.0, 40.0))
                out.push(wall(1650.0, 0.0, 40.0, 500.0))
                out.push(wall(1650.0, 1300.0, 40.0, 400.0))
                out.push(wall(1650.0, 1300.0, 550.0, 40.0))
                out.push(wall(2050.0, 300.0, 40.0, 700.0))
                out.push(wall(2050.0, 300.0, 400.0, 40.0))
                out.push(wall(2050.0, 1650.0, 40.0, 350.0))
                out.push(wall(2450.0, 0.0, 40.0, 1000.0))
                out.push(wall(2450.0, 1300.0, 40.0, 450.0))
            }
            .Expanse => {
                for p in [(500.0, 400.0), (1500.0, 700.0), (2700.0, 450.0), (3200.0, 1500.0), (900.0, 1900.0), (2100.0, 2200.0), (3300.0, 2400.0), (600.0, 1200.0)]:
                    let (x, y) = p
                    out.push(wall(x, y, 110.0, 110.0))
            }
            .Cross => {
                let arm = 850.0
                out.push(wall(0.0, 0.0, arm, arm))
                out.push(wall(2600.0 - arm, 0.0, arm, arm))
                out.push(wall(0.0, 2600.0 - arm, arm, arm))
                out.push(wall(2600.0 - arm, 2600.0 - arm, arm, arm))
            }
            .Gridlock => {
                for i in 0..5:
                    for j in 0..4:
                        out.push(wall(220.0 + i as f64 * 580.0, 220.0 + j as f64 * 520.0, 360.0, 300.0))
            }
            _ => ()
        out

// ----- live tuning ------------------------------------------------------------

// Every knob by name, as `name value` lines: the tuning file's format, and
// what tuning.defaults.txt lists.
pub fn rules_dump(r: Rules) -> str:
    var out = ""
    out = out ++ "arena_width " ++ num(r.arena_width) ++ "\n"
    out = out ++ "arena_height " ++ num(r.arena_height) ++ "\n"
    out = out ++ "player_speed " ++ num(r.player_speed) ++ "\n"
    out = out ++ f"max_health {r.max_health}\n"
    out = out ++ f"layout {r.layout}\n"
    out = out ++ "run_cap " ++ num(r.run_cap) ++ "\n"
    out = out ++ "cannon_interval " ++ num(r.cannon_interval) ++ "\n"
    out = out ++ "bullet_speed " ++ num(r.bullet_speed) ++ "\n"
    out = out ++ "bullet_lifetime " ++ num(r.bullet_lifetime) ++ "\n"
    out = out ++ "enemy_speed " ++ num(r.enemy_speed) ++ "\n"
    out = out ++ "enemy_speed_variation " ++ num(r.enemy_speed_variation) ++ "\n"
    out = out ++ "spawn_grace " ++ num(r.spawn_grace) ++ "\n"
    out = out ++ "bullet_hit_radius " ++ num(r.bullet_hit_radius) ++ "\n"
    out = out ++ "contact_radius " ++ num(r.contact_radius) ++ "\n"
    out = out ++ "invulnerability " ++ num(r.invulnerability) ++ "\n"
    out = out ++ "damage_stop " ++ num(r.damage_stop) ++ "\n"
    out = out ++ "death_stop " ++ num(r.death_stop) ++ "\n"
    out = out ++ "level_stop " ++ num(r.level_stop) ++ "\n"
    out = out ++ "merge_stop " ++ num(r.merge_stop) ++ "\n"
    out = out ++ "boss_stop " ++ num(r.boss_stop) ++ "\n"
    out = out ++ "magnet_radius " ++ num(r.magnet_radius) ++ "\n"
    out = out ++ "core_speed " ++ num(r.core_speed) ++ "\n"
    out = out ++ "core_merge_age " ++ num(r.core_merge_age) ++ "\n"
    out = out ++ "combo_window " ++ num(r.combo_window) ++ "\n"
    out = out ++ "lookahead " ++ num(r.lookahead) ++ "\n"
    out = out ++ "camera_ease " ++ num(r.camera_ease) ++ "\n"
    out = out ++ "dart_minute " ++ num(r.dart_minute) ++ "\n"
    out = out ++ "spinner_minute " ++ num(r.spinner_minute) ++ "\n"
    out = out ++ "weaver_minute " ++ num(r.weaver_minute) ++ "\n"
    out = out ++ "skimmer_minute " ++ num(r.skimmer_minute) ++ "\n"
    out = out ++ "well_minute " ++ num(r.well_minute) ++ "\n"
    out = out ++ "first_elite " ++ num(r.first_elite) ++ "\n"
    out = out ++ "elite_interval " ++ num(r.elite_interval) ++ "\n"
    out = out ++ f"beacon_count {r.beacon_count}\n"
    out = out ++ "beacon_respawn " ++ num(r.beacon_respawn) ++ "\n"
    out = out ++ "breather " ++ num(r.breather) ++ "\n"
    out = out ++ "spawn_scale " ++ num(r.spawn_scale) ++ "\n"
    out = out ++ "speed_scale " ++ num(r.speed_scale) ++ "\n"
    out = out ++ "void_radius " ++ num(r.void_radius) ++ "\n"
    out = out ++ "upgrade_weight " ++ num(r.upgrade_weight) ++ "\n"
    out = out ++ "new_weapon_weight " ++ num(r.new_weapon_weight) ++ "\n"
    out = out ++ "repair_drop_chance " ++ num(r.repair_drop_chance) ++ "\n"
    out = out ++ "lightning_damage " ++ num(r.lightning_damage) ++ "\n"
    out = out ++ "new_passive_weight " ++ num(r.new_passive_weight) ++ "\n"
    out = out ++ "minimum_start " ++ num(r.minimum_start) ++ "\n"
    out = out ++ "passive_upgrade_weight " ++ num(r.passive_upgrade_weight) ++ "\n"
    out

// Set one knob by name. False when the name is not a knob.
pub fn rules_set(r: Rules, key: &str, value: f64) -> (Rules, bool):
    var out = r
    if key == "arena_width": out.arena_width = value
    else if key == "arena_height": out.arena_height = value
    else if key == "player_speed": out.player_speed = value
    else if key == "max_health": out.max_health = (value as i32)
    else if key == "run_cap": out.run_cap = value
    else if key == "cannon_interval": out.cannon_interval = value
    else if key == "bullet_speed": out.bullet_speed = value
    else if key == "bullet_lifetime": out.bullet_lifetime = value
    else if key == "enemy_speed": out.enemy_speed = value
    else if key == "enemy_speed_variation": out.enemy_speed_variation = value
    else if key == "spawn_grace": out.spawn_grace = value
    else if key == "bullet_hit_radius": out.bullet_hit_radius = value
    else if key == "contact_radius": out.contact_radius = value
    else if key == "invulnerability": out.invulnerability = value
    else if key == "damage_stop": out.damage_stop = value
    else if key == "death_stop": out.death_stop = value
    else if key == "level_stop": out.level_stop = value
    else if key == "merge_stop": out.merge_stop = value
    else if key == "boss_stop": out.boss_stop = value
    else if key == "magnet_radius": out.magnet_radius = value
    else if key == "core_speed": out.core_speed = value
    else if key == "core_merge_age": out.core_merge_age = value
    else if key == "combo_window": out.combo_window = value
    else if key == "lookahead": out.lookahead = value
    else if key == "camera_ease": out.camera_ease = value
    else if key == "dart_minute": out.dart_minute = value
    else if key == "spinner_minute": out.spinner_minute = value
    else if key == "weaver_minute": out.weaver_minute = value
    else if key == "skimmer_minute": out.skimmer_minute = value
    else if key == "well_minute": out.well_minute = value
    else if key == "first_elite": out.first_elite = value
    else if key == "elite_interval": out.elite_interval = value
    else if key == "beacon_count": out.beacon_count = (value as i32)
    else if key == "beacon_respawn": out.beacon_respawn = value
    else if key == "breather": out.breather = value
    else if key == "spawn_scale": out.spawn_scale = value
    else if key == "speed_scale": out.speed_scale = value
    else if key == "void_radius": out.void_radius = value
    else if key == "upgrade_weight": out.upgrade_weight = value
    else if key == "new_weapon_weight": out.new_weapon_weight = value
    else if key == "repair_drop_chance": out.repair_drop_chance = value
    else if key == "layout": out.layout = value as i32
    else if key == "lightning_damage": out.lightning_damage = value
    else if key == "new_passive_weight": out.new_passive_weight = value
    else if key == "minimum_start": out.minimum_start = value
    else if key == "passive_upgrade_weight": out.passive_upgrade_weight = value
    else: return (r, false)
    (out, true)

// Apply a tuning file's text over a base. Blank lines and lines starting
// with # are ignored; unknown names are reported in the second value.
pub fn apply_tuning(base: Rules, text: &str) -> (Rules, i32, str):
    var r = base
    var applied = 0
    var unknown = ""
    for raw in text.split("\n"):
        let line = raw.trim()
        if line.len() == 0 or line.starts_with("#"): continue
        let parts = line.split(" ")
        if parts.len() < 2: continue
        let key = parts[0].clone()
        let value = read_number(parts[parts.len() - 1].clone())
        let (next, known) = rules_set(r, key, value)
        if known:
            r = next
            applied += 1
        else: unknown = if unknown.len() == 0: key else: unknown ++ " " ++ key
    (r, applied, unknown)

// Exact enough for tuning: digits, one point, one minus.
pub fn read_number(s: &str) -> f64:
    var i: i64 = 0
    let n = s.len() as i64
    var negative = false
    if i < n and s.byte_at(i) as i32 == 45:
        negative = true
        i += 1
    var value = 0.0
    while i < n:
        let c = s.byte_at(i) as i32
        if c < 48 or c > 57: break
        value = value * 10.0 + (c - 48) as f64
        i += 1
    if i < n and s.byte_at(i) as i32 == 46:
        i += 1
        var place = 0.1
        while i < n:
            let c = s.byte_at(i) as i32
            if c < 48 or c > 57: break
            value += (c - 48) as f64 * place
            place *= 0.1
            i += 1
    if negative: -value else: value

// Six significant decimals, no exponent.
pub fn num(x: f64) -> str:
    let negative = x < 0.0
    let m = if negative: -x else: x
    let whole = m as i64
    let frac = ((m - whole as f64) * 1000000.0 + 0.5) as i64
    var digits = f"{frac}"
    while digits.len() < 6: digits = "0" ++ digits
    // Trim trailing zeros, keep at least one.
    var end = digits.len()
    while end > 1 and digits.byte_at(end - 1) as i32 == 48: end -= 1
    let sign = if negative: "-" else: ""
    f"{sign}{whole}." ++ digits.slice(0, end)
