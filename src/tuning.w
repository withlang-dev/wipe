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
    enemy_speed: f64 = 83.0,
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
    magnet_radius: f64 = 70.0,
    core_speed: f64 = 520.0,
    core_merge_age: f64 = 3.0,
    combo_window: f64 = 2.0,
    // Camera lookahead toward the aim direction, in pixels.
    lookahead: f64 = 120.0,
    camera_ease: f64 = 6.0,
    // Timeline first-appearance minutes.
    dart_minute: f64 = 2.0,
    spinner_minute: f64 = 5.0,
    weaver_minute: f64 = 5.0,
    skimmer_minute: f64 = 8.0,
    well_minute: f64 = 12.0,
    first_elite: f64 = 180.0,
    elite_interval: f64 = 60.0,
    beacon_count: i32 = 3,
    beacon_respawn: f64 = 60.0,
    breather: f64 = 5.0,
    // Stage modifiers.
    spawn_scale: f64 = 1.0,
    speed_scale: f64 = 1.0,
}

extend Rules:
    // Spawns per second at a minute of the run. The curve is gentle for two
    // minutes, then climbs so the view fills at fifteen minutes.
    pub fn spawn_rate(self: &Self, minute: f64) -> f64:
        if minute < 2.0: 0.8 + minute * 0.35
        else: 1.5 + (minute - 2.0) * 0.9

    // XP a level needs: early levels every thirty seconds, late ones every
    // minute or two against a rising kill rate.
    pub fn xp_for_level(self: &Self, level: i32) -> i32:
        let l = (level - 1) as f64
        (10.0 + l * 6.0 + l * l * 1.0) as i32

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
        Event { minute: 2.5, formation: .Sweep, kind_index: 0, count: 18 },
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

// Stages are arena shapes with a rule modifier. Geometry is level design,
// and in an abstract game it costs no art.
pub enum Stage { | Field | Corridor | Shaft }
impl Copy for Stage
impl Eq for Stage

pub const STAGE_COUNT: i32 = 3

pub fn stage_at(index: i32) -> Stage:
    match index:
        0 => .Field
        1 => .Corridor
        _ => .Shaft

extend Stage:
    pub fn index(self: &Self) -> i32:
        match self:
            .Field => 0
            .Corridor => 1
            .Shaft => 2
    pub fn name(self: &Self) -> str:
        match self:
            .Field => "Field"
            .Corridor => "Corridor"
            .Shaft => "Shaft"
    pub fn describe(self: &Self) -> str:
        match self:
            .Field => "The open rectangle. Four seconds to any wall."
            .Corridor => "A horizontal corridor. Every fight is a sweep. +30% spawns."
            .Shaft => "A vertical shaft. Nowhere to circle. +20% enemy speed."
    pub fn rules(self: &Self) -> Rules:
        match self:
            .Field => Rules {}
            .Corridor => Rules { arena_width: 3600.0, arena_height: 720.0, spawn_scale: 1.3 }
            .Shaft => Rules { arena_width: 900.0, arena_height: 2600.0, speed_scale: 1.2 }
