use tuning
use loadout
use ships

// Pure simulation: no window, audio, or foreign calls; pools allocate at
// creation. Dense bounded pools use swap removal. A uniform grid over the
// arena bounds every enemy query so bullets, blades, and separation scale
// with local density rather than the enemy count.
// The simulation's fixed step: 120 per second, whatever the frame rate.
pub const STEPS_PER_SECOND: i64 = 120
pub const STEP: f64 = 1.0 / 120.0
pub const ENEMY_CAP: i32 = 2000
pub const BULLET_CAP: i32 = 512
pub const CORE_CAP: i32 = 1024
pub const PARTICLE_CAP: i32 = 3000
pub const PULSE_CAP: i32 = 64
pub const POPUP_CAP: i32 = 48
pub const PICKUP_CAP: i32 = 32
pub const BEACON_CAP: i32 = 4
pub const MINE_CAP: i32 = 32
pub const BEAM_CAP: i32 = 16
pub const ARC_CAP: i32 = 96
pub const SHOCKWAVE_CAP: i32 = 16
// The Steam Deck's panel: the menu frame, and the smallest view. A screen of
// another shape widens or heightens the view to its aspect ratio
// (view_size); the game's screen_w and screen_h carry the view in use.
pub const WIDTH: i32 = 1280
pub const HEIGHT: i32 = 800

// The view for a screen: 1280x800 grown in one dimension to the screen's
// aspect ratio, never cropped (16:9 is 1422x800, 4:3 is 1280x960).
pub fn view_size(screen_w: i32, screen_h: i32) -> (i32, i32):
    if screen_w <= 0 or screen_h <= 0: return (WIDTH, HEIGHT)
    let aspect = screen_w as f64 / screen_h as f64
    let base = WIDTH as f64 / HEIGHT as f64
    if aspect >= base: ((HEIGHT as f64 * aspect + 0.5) as i32, HEIGHT)
    else: (WIDTH, (WIDTH as f64 / aspect + 0.5) as i32)
// The enemy grid covers the largest arena the rules allow.
const CELL_SIZE = 64
const CELL_COLS = 60
const CELL_ROWS = 44
const CELL_COUNT = CELL_COLS * CELL_ROWS
pub const KIND_COUNT: i32 = 8
// The Phase is invulnerable for PHASE_LENGTH seconds every PHASE_PERIOD.
pub const PHASE_PERIOD: f64 = 5.0
pub const PHASE_LENGTH: f64 = 1.5

pub type V2 { x: f64 = 0.0, y: f64 = 0.0 }
pub fn add(a: V2, b: V2) -> V2: V2 { x: a.x + b.x, y: a.y + b.y }
pub fn sub(a: V2, b: V2) -> V2: V2 { x: a.x - b.x, y: a.y - b.y }
pub fn scale(a: V2, n: f64) -> V2: V2 { x: a.x * n, y: a.y * n }
pub fn length2(a: V2) -> f64: a.x * a.x + a.y * a.y
pub fn limit(n: f64, lo: f64, hi: f64) -> f64:
    if n < lo: lo else if n > hi: hi else: n
pub fn direction(a: V2) -> V2:
    let n = sqrt(length2(a))
    if n > 0.0001: scale(a, 1.0 / n) else: V2 {}
pub fn movement(a: V2) -> V2:
    if length2(a) > 1.0: direction(a) else: a
pub fn perpendicular(a: V2) -> V2: V2 { x: -a.y, y: a.x }
fn cell_index(pos: V2) -> i32:
    let x = limit(pos.x / CELL_SIZE as f64, 0.0, (CELL_COLS - 1) as f64) as i32
    let y = limit(pos.y / CELL_SIZE as f64, 0.0, (CELL_ROWS - 1) as f64) as i32
    y * CELL_COLS + x

pub fn segment_hit(a: V2, b: V2, p: V2, radius: f64) -> bool:
    let ab = sub(b, a)
    let ap = sub(p, a)
    let size = length2(ab)
    let t = if size > 0.0001: limit((ap.x * ab.x + ap.y * ab.y) / size, 0.0, 1.0) else: 0.0
    length2(sub(p, add(a, scale(ab, t)))) <= radius * radius

// Presentation palette shared by sparks, pulses, and enemy outlines.
pub enum Tint { | Cyan | Magenta | Gold | White | Lime | Blue | Red | Violet }
impl Copy for Tint

// Every kind is defined by how it moves. Numbers scale with the minute.
pub enum Kind { | Block | Spinner | Dart | Weaver | Skimmer | Well | Boss | Null }
impl Copy for Kind
impl Eq for Kind
extend Kind:
    pub fn index(self: &Self) -> i32:
        match self:
            .Block => 0
            .Spinner => 1
            .Dart => 2
            .Weaver => 3
            .Skimmer => 4
            .Well => 5
            .Boss => 6
            .Null => 7
    pub fn name(self: &Self) -> str:
        match self:
            .Block => "Block"
            .Spinner => "Spinner"
            .Dart => "Dart"
            .Weaver => "Weaver"
            .Skimmer => "Skimmer"
            .Well => "Well"
            .Boss => "Boss"
            .Null => "the Null"
    pub fn tint(self: &Self) -> Tint:
        match self:
            .Block => .Lime
            .Spinner => .Magenta
            .Dart => .Blue
            .Weaver => .Cyan
            .Skimmer => .Gold
            .Well => .Violet
            .Boss => .Red
            .Null => .White
    // Darts rush, weavers lag.
    fn speed_bonus(self: &Self) -> f64:
        match self:
            .Block => 0.0
            .Spinner => 12.0
            .Dart => 40.0
            .Weaver => -16.0
            .Skimmer => 20.0
            .Well => -60.0
            .Boss => -20.0
            .Null => 240.0
    pub fn radius(self: &Self) -> f64:
        match self:
            .Block => 15.0
            .Well => 26.0
            .Boss => 60.0
            .Null => 90.0
            _ => 14.0
    // Health grows with the square of the minute so the back half of a run
    // outpaces a build that has stopped growing: linear growth let a
    // twelve-minute build walk through the last eight.
    fn base_hp(self: &Self, minute: f64) -> i32:
        let m = minute
        let curve = m * 1.25 + m * m * 0.055
        // Opening enemies die to one hit; the pressure is their number.
        match self:
            .Block => (1.0 + curve) as i32
            .Spinner => (3.0 + curve * 1.3) as i32
            .Dart => (1.0 + curve * 0.5) as i32
            .Weaver => (2.0 + curve * 0.9) as i32
            .Skimmer => (2.0 + curve * 0.9) as i32
            .Well => (24.0 + curve * 6.0) as i32
            .Boss => (500.0 + m * 200.0 + m * m * 12.0) as i32
            .Null => 6000
    fn contact_damage(self: &Self, minute: f64) -> i32:
        let scaled = (minute / 4.0) as i32
        match self:
            .Block => 3 + scaled
            .Spinner => 4 + scaled
            .Dart => 3 + scaled
            .Weaver => 3 + scaled
            .Skimmer => 3 + scaled
            .Well => 4 + scaled
            .Boss => 6 + scaled
            .Null => 1000
    // XP a core from this kind carries.
    fn core_value(self: &Self) -> i32:
        match self:
            .Block => 1
            .Dart => 1
            .Spinner => 2
            .Weaver => 2
            .Skimmer => 2
            .Well => 6
            .Boss => 40
            .Null => 100
pub fn kind_at(index: i32) -> Kind:
    match index:
        0 => .Block
        1 => .Spinner
        2 => .Dart
        3 => .Weaver
        4 => .Skimmer
        5 => .Well
        6 => .Boss
        _ => .Null

pub type Enemy {
    pos: V2 = V2 {}, vel: V2 = V2 {},
    hp: i32 = 1, max_hp: i32 = 1,
    age: f64 = 0.0, flash: f64 = 0.0, hit_cd: f64 = 0.0,
    speed: f64 = 95.0, kind: Kind = .Block,
    elite: bool = false, size: f64 = 1.0,
    // Behavior clock and state: spinners track, telegraph, charge; darts
    // rush and rest; bosses cycle; wells count what they have eaten.
    timer: f64 = 0.0, state: i32 = 0, eaten: i32 = 0,
    // Formation enemies fly their vector before they start chasing.
    formation: f64 = 0.0,
    // Bosses: which boss (0 Warden, 1 Lancer, 2 Hive), where it faces, and
    // a turning angle for spirals. Hive drones orbit their core.
    boss: i32 = -1, facing: V2 = V2 { x: 1.0 }, angle: f64 = 0.0, drone: bool = false,
}

// The three bosses, in the order they arrive.
pub const BOSS_NAMES: [str; 3] = ["WARDEN", "LANCER", "HIVE"]
pub const BOSS_HEALTH: [f64; 3] = [1800.0, 5000.0, 7000.0]
pub type Bullet {
    pos: V2 = V2 {}, vel: V2 = V2 {}, life: f64 = 0.0, steps: i32 = 0,
    damage: i32 = 1, pierce: i32 = 0, bounces: i32 = 0, bounced: bool = false,
    weapon: Weapon = .Cannon, homing: bool = false, splits: bool = false, shatters: bool = false,
    hostile: bool = false,
}
pub type Core { pos: V2 = V2 {}, value: i32 = 1, age: f64 = 0.0 }
pub enum PickupKind { | Tractor | Clear | Freeze | Repair | Credits | Bundle | Cache }
impl Copy for PickupKind
impl Eq for PickupKind
extend PickupKind:
    pub fn name(self: &Self) -> str:
        match self:
            .Tractor => "TRACTOR"
            .Clear => "CLEAR"
            .Freeze => "FREEZE"
            .Repair => "REPAIR"
            .Credits => "CREDIT"
            .Bundle => "BUNDLE"
            .Cache => "CACHE"
pub type Pickup { pos: V2 = V2 {}, kind: PickupKind = .Credits, age: f64 = 0.0 }
pub type Beacon { pos: V2 = V2 {}, alive: bool = true, respawn: f64 = 0.0 }
pub type Mine { pos: V2 = V2 {}, radius: f64 = 90.0, damage: i32 = 3, chains: bool = false, age: f64 = 0.0 }
pub type Beam { a: V2 = V2 {}, b: V2 = V2 {}, life: f64 = 0.32, total: f64 = 0.32, width: f64 = 14.0 }
// A lightning stroke. The seed fixes its jagged shape for its lifetime.
pub type ArcBolt { a: V2 = V2 {}, b: V2 = V2 {}, life: f64 = 0.3, total: f64 = 0.3, seed: u32 = 0 }
pub type Shockwave { pos: V2 = V2 {}, radius: f64 = 0.0, max_radius: f64 = 140.0, damage: i32 = 2, life: f64 = 0.125, total: f64 = 0.125 }
pub type Particle {
    pos: V2 = V2 {}, vel: V2 = V2 {},
    life: f64 = 0.0, total: f64 = 1.0,
    size: f64 = 1.0, rotation: f64 = 0.0,
    tint: Tint = .Cyan,
}
pub type Pulse {
    pos: V2 = V2 {}, life: f64 = 0.0,
    total: f64 = 0.35, radius: f64 = 30.0, tint: Tint = .Magenta,
    // The silhouette that scales out with this pulse, for enemy deaths.
    remnant: Option[Kind] = None,
}
// Floating text spawned by pickups and level-ups.
pub enum PopupKind { | Credits(value: i32) | Level(level: i32) | Pickup(kind: PickupKind) | Xp(value: i32) | ComboTier(tenths: i32) }

// Combo tiers: the combo count where each begins, and the credit
// multiplier it pays, in tenths. Shown on the HUD and called out on reaching.
pub const COMBO_TIERS: [i32; 5] = [0, 10, 25, 50, 100]
pub const COMBO_PAY: [i32; 5] = [10, 15, 20, 25, 30]

pub fn combo_tier(combo: i32) -> i32:
    var tier = 0
    for i in 0..5:
        if combo >= COMBO_TIERS[i]: tier = i
    tier
impl Copy for PopupKind
pub type Popup { pos: V2 = V2 {}, life: f64 = 0.0, total: f64 = 0.9, kind: PopupKind = .Xp(value: 0) }
// One centered banner at a time: the loudest moments name themselves.
pub enum BannerKind { | Merge(weapon: Weapon) | Boss | BossName(boss: i32) | FirstKill(boss: i32) | BossDown | Event(formation: Formation) | NewBest | Null | Cleared | Reboot | Endless(cycle: i32) }
impl Copy for BannerKind
pub type Banner { kind: BannerKind = .Boss, life: f64 = 0.0, total: f64 = 2.0 }
pub type Controls { motion: V2 = V2 {}, aim: V2 = V2 { x: 1.0, y: 0.0 } }

pub enum Phase { | Running | Boost | Over }
impl Copy for Phase
impl Eq for Phase

pub enum BoostSource { | LevelUp | Cache }
impl Copy for BoostSource
impl Eq for BoostSource

// Everything the account hands a run at launch.
pub type Launch {
    ship: Ship = .Claw,
    shop: Mods = Mods {},
    rerolls: i32 = 0, skips: i32 = 0, banishes: i32 = 0, reboots: i32 = 0,
    unlocked_weapons: [bool; 20] = [false; 20],
    unlocked_passives: [bool; 14] = [false; 14],
    taken_weapons: [bool; 20] = [false; 20],
    taken_passives: [bool; 14] = [false; 14],
    best_time: f64 = 0.0,
    endless: bool = false,
    // Bosses this account has ever killed; a first kill is an achievement.
    bosses_known: [bool; 3] = [false; 3],
}
impl Copy for Launch

// Allocate and initialize each pool once. Restart resets active lengths only.
fn storage[T](value: T, capacity: i32) -> Vec[T]:
    var slots = Vec.with_capacity(capacity)
    for _ in 0..capacity: slots.push(value)
    slots

pub type Game {
    rules: Rules = Rules {},
    launch: Launch = Launch {},
    build: Build = Build {},
    mods: Mods = Mods {},
    phase: Phase = .Running,
    player: V2 = V2 {},
    aim: V2 = V2 { x: 1.0, y: 0.0 },
    // The camera center. Deterministic so headless tests see the same spawns.
    view: V2 = V2 {},
    health: i32 = 10, max_health: i32 = 10, regen_bank: f64 = 0.0,
    // The view in world units: 1280x800 on a 16:10 screen (view_size).
    screen_w: f64 = 1280.0, screen_h: f64 = 800.0,
    kills: i32 = 0,
    // The run's clock is a count of fixed steps; elapsed is derived from it,
    // never summed, so minute 20 is exact however long the run.
    steps: i64 = 0, elapsed: f64 = 0.0,
    level: i32 = 1, xp: i32 = 0, xp_next: i32 = 20, pending_levels: i32 = 0,
    combo: i32 = 0, best_combo: i32 = 0, combo_timer: f64 = 0.0,
    credits: i32 = 0, credit_energy: f64 = 0.0,
    rerolls: i32 = 0, skips: i32 = 0, banishes: i32 = 0, reboots: i32 = 0,
    offers: [Offer; 4] = [Offer {}; 4], offer_count: i32 = 0,
    boost_source: BoostSource = .LevelUp, pending_cache_items: i32 = 0, cache_reveal: f64 = 0.0,
    invulnerable: f64 = 0.0, muzzle: f64 = 0.0,
    trauma: f64 = 0.0, flash: f64 = 0.0, freeze: f64 = 0.0, kill_energy: f64 = 0.0,
    enemies_frozen: f64 = 0.0, breather: f64 = 0.0,
    spawn_timer: f64 = 0.7, next_elite: f64 = 180.0, refill_timer: f64 = 0.0,
    boss_index: i32 = 0, boss_alive: bool = false,
    null_alive: bool = false, cleared: bool = false, endless_loop: i32 = 0,
    event_index: i32 = 0, event_telegraph: f64 = 0.0, event_side: i32 = 0,
    // The death record.
    killer: Option[Kind] = None, killer_elite: bool = false, health_before: i32 = 0,
    // Run facts the unlock list reads.
    hits_taken: i32 = 0, bounced_kills: i32 = 0, cores_collected: i32 = 0,
    elites_killed: i32 = 0, bosses_killed: i32 = 0, caches_opened: i32 = 0,
    reboot_used: bool = false, null_killed: bool = false,
    kills_by_kind: [i32; 8] = [0; 8],
    best_crossed: bool = false, best_flare: f64 = 0.0,
    // Boss entry pulls the camera back for a moment.
    zoom_timer: f64 = 0.0,
    // Boss kills this run by boss.
    boss_kills: [i32; 3] = [0; 3],
    // The Phase slips out of the world on a rhythm.
    phase_timer: f64 = 0.0,
    banner: Banner = Banner {},
    enemy_count: i32 = 0, bullet_count: i32 = 0, core_count: i32 = 0, particle_count: i32 = 0,
    pulse_count: i32 = 0, popup_count: i32 = 0, pickup_count: i32 = 0, beacon_count: i32 = 0,
    mine_count: i32 = 0, beam_count: i32 = 0, arc_count: i32 = 0, wave_count: i32 = 0,
    enemies: Vec[Enemy],
    cell_heads: Vec[i32],
    cell_next: Vec[i32],
    bullets: Vec[Bullet],
    cores: Vec[Core],
    particles: Vec[Particle],
    pulses: Vec[Pulse],
    popups: Vec[Popup],
    pickups: Vec[Pickup],
    beacons: Vec[Beacon],
    mines: Vec[Mine],
    beams: Vec[Beam],
    arcs: Vec[ArcBolt],
    waves: Vec[Shockwave],
    rng: u32 = 1234567,
    // The stage's walls, and for maze stages a distance field on the enemy
    // grid toward the ship, rebuilt a few times a second.
    walls: Vec[Wall],
    flow: Vec[i32],
    flow_timer: f64 = 0.0,
    uses_paths: bool = false,
    shot_event: bool = false, hit_event: bool = false,
    kill_event: bool = false, hurt_event: bool = false, death_event: bool = false,
    level_event: bool = false, merge_event: bool = false, boss_event: bool = false,
    pickup_event: bool = false, core_event: bool = false, cache_event: bool = false,
    boss_kill_event: bool = false, best_event: bool = false, zap_event: bool = false,
    first_kill_event: bool = false,
}

pub fn Game.new(rules: Rules = Rules {}) -> Game:
    var g = Game {
        rules,
        enemies: storage(Enemy {}, ENEMY_CAP),
        cell_heads: storage(-1, CELL_COUNT),
        cell_next: storage(-1, ENEMY_CAP),
        bullets: storage(Bullet {}, BULLET_CAP),
        cores: storage(Core {}, CORE_CAP),
        particles: storage(Particle {}, PARTICLE_CAP),
        pulses: storage(Pulse {}, PULSE_CAP),
        popups: storage(Popup {}, POPUP_CAP),
        pickups: storage(Pickup {}, PICKUP_CAP),
        beacons: storage(Beacon {}, BEACON_CAP),
        mines: storage(Mine {}, MINE_CAP),
        beams: storage(Beam {}, BEAM_CAP),
        arcs: storage(ArcBolt {}, ARC_CAP),
        waves: storage(Shockwave {}, SHOCKWAVE_CAP),
        walls: Vec.new(),
        flow: storage(-1, CELL_COUNT),
    }
    // A default launch has every launch weapon and passive so tests and the
    // acceptance harness run a full loadout without an account.
    var launch = Launch {}
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..8: launch.unlocked_passives[i] = true
    g.start(launch)
    g

extend Game:
    pub fn random(mut self: Self) -> f64:
        self.rng = self.rng *% 1664525 +% 1013904223
        (self.rng % 65536) as f64 / 65535.0

    pub fn center(self: &Self) -> V2: V2 { x: self.rules.arena_width / 2.0, y: self.rules.arena_height / 2.0 }
    pub fn minute(self: &Self) -> f64: self.elapsed / 60.0
    // Benches, the gallery and tests start a run at a given second.
    pub fn jump_to(mut self: Self, seconds: f64):
        self.steps = (seconds * STEPS_PER_SECOND as f64 + 0.5) as i64
        self.elapsed = self.steps as f64 / STEPS_PER_SECOND as f64
    // The minute the spawn tables read: endless loops from minute ten.
    pub fn table_minute(self: &Self) -> f64:
        let m = self.minute()
        if self.launch.endless and m >= 20.0: 10.0 + ((m - 10.0) % 10.0) else: m
    // Endless compounds per ten-minute loop: a linear ramp let a finished
    // build outlive it indefinitely (a Sapper ran 99 minutes).
    fn loop_scale(self: &Self, per_loop: f64) -> f64:
        var scale_by = 1.0
        for _ in 0..self.endless_loop: scale_by *= per_loop
        scale_by

    fn difficulty(self: &Self) -> f64:
        (1.0 + self.mods.overclock) * self.loop_scale(1.9)

    // Three or four touches end a fresh ship: the swarm is dangerous
    // because there is so much of it.
    fn contact(self: &Self, kind: Kind) -> i32:
        kind.contact_damage(self.table_minute()) + self.endless_loop * 2
    pub fn boss_minute(self: &Self) -> Option[f64]:
        let minutes = self.rules.boss_minutes()
        if self.boss_index < 3: Some(minutes[self.boss_index]) else: None
    pub fn boss_name(self: &Self) -> Option[str]:
        for i in 0..self.enemy_count:
            let e = self.enemies[i]
            if e.kind == .Boss and e.boss >= 0: return Some(BOSS_NAMES[e.boss].clone())
        None

    pub fn boss_health(self: &Self) -> Option[(i32, i32)]:
        for i in 0..self.enemy_count:
            let e = self.enemies[i]
            if e.kind == .Boss or e.kind == .Null: return Some((e.hp, e.max_hp))
        None

    // Begin a run for a ship with the account's ranks and unlocks.
    pub fn start(mut self: Self, chosen: Launch):
        self.launch = chosen
        self.reset()

    pub fn reset(mut self: Self):
        let current: Launch = self.launch
        self.phase = .Running
        self.player = self.clamp_to_arena(self.center(), 60.0)
        self.view = self.player
        self.aim = V2 { x: 1.0, y: 0.0 }
        self.build = Build {
            weapon_slots: current.ship.weapon_slots(),
            unlocked_weapons: current.unlocked_weapons,
            unlocked_passives: current.unlocked_passives,
            forbidden_weapon: current.ship.forbidden_weapon(),
        }
        self.build.add_weapon(current.ship.base_weapon())
        self.build.weapons[0].seen = true
        self.level = current.ship.starting_level()
        if current.ship == .Null:
            // The strongest start: three weapons, already at level three.
            self.build.add_weapon(.Orbit)
            self.build.add_weapon(.Seeker)
            for slot in 0..3: self.build.weapons[slot].level = 3
        self.xp = 0
        self.xp_next = self.rules.xp_for_level(self.level)
        self.pending_levels = 0
        self.refresh_mods()
        self.health = self.max_health
        self.regen_bank = 0.0
        self.kills = 0
        self.steps = 0
        self.elapsed = 0.0
        self.combo = 0
        self.best_combo = 0
        self.combo_timer = 0.0
        self.credits = 0
        self.credit_energy = 0.0
        self.rerolls = current.rerolls + current.ship.extra_rerolls()
        self.skips = current.skips
        self.banishes = current.banishes
        self.reboots = if current.ship.reboots_work(): current.reboots else: 0
        self.offer_count = 0
        self.boost_source = .LevelUp
        self.pending_cache_items = 0
        self.cache_reveal = 0.0
        self.invulnerable = 0.0
        self.muzzle = 0.0
        self.trauma = 0.0
        self.flash = 0.0
        self.freeze = 0.0
        self.kill_energy = 0.0
        self.enemies_frozen = 0.0
        self.breather = 0.0
        self.spawn_timer = 0.7
        self.refill_timer = 0.0
        self.next_elite = self.rules.first_elite
        self.boss_index = 0
        self.boss_alive = false
        self.null_alive = false
        self.cleared = false
        self.endless_loop = 0
        self.event_index = 0
        self.event_telegraph = 0.0
        self.killer = None
        self.killer_elite = false
        self.health_before = 0
        self.hits_taken = 0
        self.bounced_kills = 0
        self.cores_collected = 0
        self.elites_killed = 0
        self.bosses_killed = 0
        self.caches_opened = 0
        self.reboot_used = false
        self.null_killed = false
        for i in 0..KIND_COUNT: self.kills_by_kind[i] = 0
        self.best_crossed = false
        self.best_flare = 0.0
        self.zoom_timer = 0.0
        self.phase_timer = PHASE_PERIOD
        self.boss_kills = [0, 0, 0]
        self.banner = Banner {}
        self.enemy_count = 0
        self.bullet_count = 0
        self.core_count = 0
        self.particle_count = 0
        self.pulse_count = 0
        self.popup_count = 0
        self.pickup_count = 0
        self.beacon_count = 0
        self.mine_count = 0
        self.beam_count = 0
        self.arc_count = 0
        self.wave_count = 0
        let stage = stage_at(self.rules.layout)
        self.walls = stage.walls()
        self.uses_paths = stage.needs_paths()
        self.flow_timer = 0.0
        for _ in 0..self.rules.beacon_count: self.place_beacon()
        self.clear_events()

    pub fn clear_events(mut self: Self):
        self.shot_event = false
        self.hit_event = false
        self.kill_event = false
        self.hurt_event = false
        self.death_event = false
        self.level_event = false
        self.merge_event = false
        self.boss_event = false
        self.pickup_event = false
        self.core_event = false
        self.cache_event = false
        self.boss_kill_event = false
        self.best_event = false
        self.zap_event = false
        self.first_kill_event = false

    // Recompute every multiplier: shop ranks, then passives, then the ship.
    fn refresh_mods(mut self: Self):
        let m = self.launch.ship.apply(self.build.passive_mods(self.launch.shop), self.level)
        let previous_max: i32 = self.max_health
        self.mods = m
        self.max_health = m.max_health
        if previous_max > 0 and self.max_health > previous_max: self.health += self.max_health - previous_max
        if self.health > self.max_health: self.health = self.max_health

    // ----- effects -----------------------------------------------------

    fn emit(mut self: Self, p: Particle):
        if self.particle_count >= PARTICLE_CAP: return
        self.particles[self.particle_count] = p
        self.particle_count += 1

    pub fn burst(mut self: Self, pos: V2, impact: V2, count: i32, tint: Tint, power: f64):
        for _ in 0..count:
            if self.particle_count >= PARTICLE_CAP: break
            let angle = self.random() * 6.283185307
            let speed = (60.0 + self.random() * 260.0) * power
            let life = 0.4 + self.random() * 0.58
            let size = 1.0 + self.random() * 1.6
            self.emit(Particle {
                pos, vel: add(V2 { x: cos(angle) * speed, y: sin(angle) * speed }, scale(impact, 80.0)),
                life, total: life, size, rotation: angle, tint,
            })

    pub fn pulse(mut self: Self, pos: V2, radius: f64, tint: Tint, remnant: Option[Kind] = None):
        if self.pulse_count >= PULSE_CAP: return
        self.pulses[self.pulse_count] = Pulse { pos, life: 0.35, total: 0.35, radius, tint, remnant }
        self.pulse_count += 1

    pub fn popup(mut self: Self, pos: V2, kind: PopupKind):
        if self.popup_count >= POPUP_CAP: return
        self.popups[self.popup_count] = Popup { pos, life: 1.1, total: 1.1, kind }
        self.popup_count += 1

    pub fn show(mut self: Self, kind: BannerKind, seconds: f64):
        self.banner = Banner { kind, life: seconds, total: seconds }

    // ----- arena and camera ---------------------------------------------

    // Inside the walls and outside the dead center, if the stage has one.
    pub fn clamp_to_arena(self: &Self, pos: V2, inset: f64) -> V2:
        var p = V2 {
            x: limit(pos.x, inset, self.rules.arena_width - inset),
            y: limit(pos.y, inset, self.rules.arena_height - inset),
        }
        if self.rules.void_radius > 0.0:
            let delta = sub(p, self.center())
            let reach = self.rules.void_radius + inset
            if length2(delta) < reach * reach:
                let away = if length2(delta) > 0.01: direction(delta) else: V2 { x: 1.0 }
                p = add(self.center(), scale(away, reach))
        // Out of any wall, by the shortest way: things slide along faces.
        for _ in 0..2:
            for w in self.walls:
                let x0 = w.x - inset
                let y0 = w.y - inset
                let x1 = w.x + w.w + inset
                let y1 = w.y + w.h + inset
                if p.x > x0 and p.x < x1 and p.y > y0 and p.y < y1:
                    // The shortest way out that stays inside the arena: a wall
                    // against the arena edge only opens toward the interior.
                    let big = 1.0e12
                    let left = if x0 >= inset: p.x - x0 else: big
                    let right = if x1 <= self.rules.arena_width - inset: x1 - p.x else: big
                    let up = if y0 >= inset: p.y - y0 else: big
                    let down = if y1 <= self.rules.arena_height - inset: y1 - p.y else: big
                    let lr = if left < right: left else: right
                    let ud = if up < down: up else: down
                    let least = if lr < ud: lr else: ud
                    if least >= big: continue
                    if least == left: p.x = x0
                    else if least == right: p.x = x1
                    else if least == up: p.y = y0
                    else: p.y = y1
        p

    pub fn in_wall(self: &Self, pos: V2) -> bool:
        for w in self.walls:
            if pos.x > w.x and pos.x < w.x + w.w and pos.y > w.y and pos.y < w.y + w.h: return true
        false

    // The wall a point is inside, as its index; -1 when none.
    fn wall_at(self: &Self, pos: V2) -> i32:
        for i in 0..self.walls.len() as i32:
            let w = self.walls[i]
            if pos.x > w.x and pos.x < w.x + w.w and pos.y > w.y and pos.y < w.y + w.h: return i
        -1

    // Breadth-first distances from the ship's cell over open cells: enemies
    // walk downhill to come around walls.
    fn rebuild_flow(mut self: Self):
        for c in 0..CELL_COUNT: self.flow[c] = -1
        var queue = Vec.new()
        let start = cell_index(self.player)
        self.flow[start] = 0
        queue.push(start)
        var head = 0
        let cols = limit(self.rules.arena_width / CELL_SIZE as f64 + 1.0, 1.0, CELL_COLS as f64) as i32
        let rows = limit(self.rules.arena_height / CELL_SIZE as f64 + 1.0, 1.0, CELL_ROWS as f64) as i32
        while head < queue.len() as i32:
            let c = queue[head]
            head += 1
            let cx = c % CELL_COLS
            let cy = c / CELL_COLS
            let here: i32 = self.flow[c]
            for d in 0..4:
                let nx = cx + (if d == 0: 1 else if d == 1: -1 else: 0)
                let ny = cy + (if d == 2: 1 else if d == 3: -1 else: 0)
                if nx < 0 or ny < 0 or nx >= cols or ny >= rows: continue
                let n = ny * CELL_COLS + nx
                if self.flow[n] >= 0: continue
                let center = V2 { x: (nx as f64 + 0.5) * CELL_SIZE as f64, y: (ny as f64 + 0.5) * CELL_SIZE as f64 }
                if self.in_wall(center): continue
                self.flow[n] = here + 1
                queue.push(n)

    // Which way an enemy should go: straight at the ship, or downhill on
    // the flow field when a wall is in the way.
    fn path_toward(self: &Self, from: V2) -> V2:
        let straight = direction(sub(self.player, from))
        if not self.uses_paths: return straight
        let c = cell_index(from)
        let here: i32 = self.flow[c]
        if here <= 1: return straight
        let cx = c % CELL_COLS
        let cy = c / CELL_COLS
        var best = here
        var goal = V2 {}
        var found = false
        for dy in -1..2:
            for dx in -1..2:
                let nx = cx + dx
                let ny = cy + dy
                if nx < 0 or ny < 0 or nx >= CELL_COLS or ny >= CELL_ROWS: continue
                let d = self.flow[ny * CELL_COLS + nx]
                if d >= 0 and d < best:
                    best = d
                    goal = V2 { x: (nx as f64 + 0.5) * CELL_SIZE as f64, y: (ny as f64 + 0.5) * CELL_SIZE as f64 }
                    found = true
        if found: direction(sub(goal, from)) else: straight

    pub fn in_void(self: &Self, pos: V2) -> bool:
        self.rules.void_radius > 0.0 and length2(sub(pos, self.center())) < self.rules.void_radius * self.rules.void_radius

    pub fn in_arena(self: &Self, pos: V2, margin: f64) -> bool:
        let boxed = pos.x >= -margin and pos.x <= self.rules.arena_width + margin and pos.y >= -margin and pos.y <= self.rules.arena_height + margin
        boxed and not self.in_void(pos) and not self.in_wall(pos)

    // The camera rectangle, clamped inside the arena.
    pub fn view_origin(self: &Self) -> V2:
        let half_w = self.screen_w / 2.0
        let half_h = self.screen_h / 2.0
        let x = if self.rules.arena_width <= self.screen_w: self.rules.arena_width / 2.0 - half_w
            else: limit(self.view.x - half_w, 0.0, self.rules.arena_width - self.screen_w)
        let y = if self.rules.arena_height <= self.screen_h: self.rules.arena_height / 2.0 - half_h
            else: limit(self.view.y - half_h, 0.0, self.rules.arena_height - self.screen_h)
        V2 { x, y }

    // The camera's zoom: 1 normally, pulled back to 0.82 on a boss's entry.
    pub fn zoom(self: &Self) -> f64:
        if self.zoom_timer <= 0.0: return 1.0
        let t = self.zoom_timer / 2.4
        1.0 - 0.18 * sin(t * 3.14159)

    // On screen, counting what a zoomed-out camera also shows.
    pub fn on_screen(self: &Self, pos: V2, margin: f64) -> bool:
        let o = self.view_origin()
        let z = self.zoom()
        let ex = (1.0 / z - 1.0) * self.screen_w / 2.0 + margin
        let ey = (1.0 / z - 1.0) * self.screen_h / 2.0 + margin
        pos.x >= o.x - ex and pos.x <= o.x + self.screen_w + ex and pos.y >= o.y - ey and pos.y <= o.y + self.screen_h + ey

    fn follow(mut self: Self, dt: f64):
        let target = add(self.player, scale(self.aim, self.rules.lookahead))
        let ease = limit(self.rules.camera_ease * dt, 0.0, 1.0)
        self.view = add(self.view, scale(sub(target, self.view), ease))

    // A point beyond the camera edge and inside the walls. Sides are tried
    // in order from a random start so a camera against a wall still spawns.
    fn spawn_point(mut self: Self) -> Option[V2]:
        let o = self.view_origin()
        let margin = 60.0
        let start = (self.random() * 3.999) as i32
        for attempt in 0..4:
            let side = (start + attempt) % 4
            let along = self.random()
            let pos = match side:
                0 => V2 { x: o.x - margin, y: o.y + along * self.screen_h }
                1 => V2 { x: o.x + self.screen_w + margin, y: o.y + along * self.screen_h }
                2 => V2 { x: o.x + along * self.screen_w, y: o.y - margin }
                _ => V2 { x: o.x + along * self.screen_w, y: o.y + self.screen_h + margin }
            if self.in_arena(pos, -8.0): return Some(pos)
        // The camera shows the whole arena along some axis: any far corner.
        let pos = V2 { x: 8.0 + self.random() * (self.rules.arena_width - 16.0), y: 8.0 + self.random() * (self.rules.arena_height - 16.0) }
        if length2(sub(pos, self.player)) > 420.0 * 420.0 and not self.in_wall(pos): Some(pos) else: None

    pub fn place_beacon(mut self: Self):
        if self.beacon_count >= BEACON_CAP: return
        let raw = V2 {
            x: 120.0 + self.random() * (self.rules.arena_width - 240.0),
            y: 120.0 + self.random() * (self.rules.arena_height - 240.0),
        }
        let pos = self.clamp_to_arena(raw, 60.0)
        self.beacons[self.beacon_count] = Beacon { pos, alive: true }
        self.beacon_count += 1

    // ----- spawning ------------------------------------------------------

    fn kind_available(self: &Self, kind: Kind) -> bool:
        let m = self.table_minute()
        match kind:
            .Block => true
            .Dart => m >= self.rules.dart_minute
            .Spinner => m >= self.rules.spinner_minute
            .Weaver => m >= self.rules.weaver_minute
            .Skimmer => m >= self.rules.skimmer_minute
            .Well => m >= self.rules.well_minute
            _ => false

    // Kind mix shifts from blocks and darts toward the pressure kinds.
    fn pick_kind(mut self: Self) -> Kind:
        let roll = self.random()
        let late = limit(self.table_minute() / 15.0, 0.0, 1.0)
        let kind = if roll < 0.5 - late * 0.25: .Block
            else if roll < 0.75 - late * 0.15: .Dart
            else if roll < 0.87: .Spinner
            else if roll < 0.95: .Weaver
            else if roll < 0.985: .Skimmer
            else: .Well
        if self.kind_available(kind): kind
        else if kind == .Well and self.kind_available(.Spinner): .Spinner
        else if self.kind_available(.Dart) and roll > 0.5: .Dart
        else: .Block

    pub fn place_enemy(mut self: Self, pos: V2, kind: Kind, elite: bool = false) -> bool:
        if self.enemy_count >= ENEMY_CAP: return false
        let m = self.table_minute()
        let difficulty = self.difficulty()
        var hp = ((kind.base_hp(m) as f64) * difficulty) as i32
        if elite: hp *= 12
        if hp < 1: hp = 1
        var speed = (self.rules.enemy_speed + self.random() * self.rules.enemy_speed_variation + limit(m * 6.0, 0.0, 60.0) + kind.speed_bonus()) * (1.0 + self.mods.overclock * 0.5)
        speed *= self.rules.speed_scale
        if elite: speed *= 0.85
        self.enemies[self.enemy_count] = Enemy {
            pos, hp, max_hp: hp, speed, kind, elite, size: if elite: 1.7 else: 1.0,
        }
        self.enemy_count += 1
        true

    // Spawns arrive in small clusters from one direction, so the swarm
    // closes from somewhere and standing still gets the ship surrounded.
    pub fn spawn_enemy(mut self: Self):
        let Some(pos) = self.spawn_point() else return
        let kind = self.pick_kind()
        let size = 1 + (self.random() * 3.0) as i32
        for k in 0..size:
            let angle = self.random() * 6.283185307
            let at = if k == 0: pos else: add(pos, V2 { x: cos(angle) * 28.0, y: sin(angle) * 28.0 })
            let _ = self.place_enemy(self.clamp_to_arena(at, 8.0), kind)

    fn spawn_elite(mut self: Self):
        let Some(pos) = self.spawn_point() else return
        var kind = self.pick_kind()
        if kind == .Well: kind = .Spinner
        let _ = self.place_enemy(pos, kind, true)

    // A boss fight is one on one: the swarm dissolves, and nothing spawns
    // until the boss is down.
    pub fn spawn_boss(mut self: Self):
        let which = limit((self.boss_index - 1) as f64, 0.0, 2.0) as i32
        var i = 0
        while i < self.enemy_count:
            let e: Enemy = self.enemies[i]
            if e.kind == .Null:
                i += 1
                continue
            if self.particle_count < PARTICLE_CAP - 300: self.burst(e.pos, V2 {}, 5, e.kind.tint(), 0.9)
            self.enemy_count -= 1
            self.enemies[i] = self.enemies[self.enemy_count]
        let Some(pos) = self.spawn_point() else return
        if self.place_enemy(pos, Kind.Boss):
            let at = self.enemy_count - 1
            let boss_health = (BOSS_HEALTH[which] * self.difficulty()) as i32
            self.enemies[at].boss = which
            self.enemies[at].hp = boss_health
            self.enemies[at].max_hp = boss_health
            self.enemies[at].facing = direction(sub(self.player, pos))
            self.enemies[at].timer = 2.0
            if which == 2: self.spawn_drones(pos)
            self.boss_alive = true
            self.boss_event = true
            self.freeze = self.rules.boss_stop
            self.zoom_timer = 2.4
            self.show(.BossName(boss: which), 2.4)

    // The Hive's four drones: they shield its core while any lives.
    fn spawn_drones(mut self: Self, at: V2):
        for k in 0..4:
            let angle = k as f64 * 1.5708
            if self.place_enemy(add(at, V2 { x: cos(angle) * 170.0, y: sin(angle) * 170.0 }), Kind.Weaver):
                let d = self.enemy_count - 1
                let hp = (220.0 * self.difficulty()) as i32
                self.enemies[d].drone = true
                self.enemies[d].eaten = k
                self.enemies[d].hp = hp
                self.enemies[d].max_hp = hp
                self.enemies[d].timer = 1.0 + k as f64 * 0.5

    fn drones_alive(self: &Self) -> i32:
        var n = 0
        for i in 0..self.enemy_count:
            if self.enemies[i].drone: n += 1
        n

    // What a hit on a boss is worth: weak points and armor.
    fn boss_damage_scale(self: &Self, e: Enemy, impact: V2) -> f64:
        match e.boss:
            0 => {
                // The Warden's back is its weak point.
                let along = impact.x * e.facing.x + impact.y * e.facing.y
                if along > 0.3: 3.5 else: 0.35
            }
            1 => if e.state == 3: 2.5 else: 0.5
            2 => if self.drones_alive() > 0: 0.08 else: 1.5
            _ => 1.0

    pub fn spawn_null(mut self: Self):
        let Some(pos) = self.spawn_point() else return
        if self.place_enemy(pos, Kind.Null):
            self.null_alive = true
            self.boss_event = true
            self.freeze = self.rules.boss_stop
            self.show(.Null, 2.5)

    // A formation of one kind from one side of the camera, flying its
    // vector for a few seconds before it turns to chase.
    pub fn spawn_event(mut self: Self, event: Event):
        let o = self.view_origin()
        let kind = kind_at(event.kind_index)
        let side: i32 = self.event_side
        let center = add(o, V2 { x: self.screen_w / 2.0, y: self.screen_h / 2.0 })
        match event.formation:
            .Sweep => {
                // A line across the far edge, all moving one way.
                for i in 0..event.count:
                    let t = (i as f64 + 0.5) / event.count as f64
                    let pos = match side:
                        0 => V2 { x: o.x - 80.0, y: o.y + t * self.screen_h }
                        1 => V2 { x: o.x + self.screen_w + 80.0, y: o.y + t * self.screen_h }
                        2 => V2 { x: o.x + t * self.screen_w, y: o.y - 80.0 }
                        _ => V2 { x: o.x + t * self.screen_w, y: o.y + self.screen_h + 80.0 }
                    let heading = match side:
                        0 => V2 { x: 1.0 }
                        1 => V2 { x: -1.0 }
                        2 => V2 { y: 1.0 }
                        _ => V2 { y: -1.0 }
                    if self.place_enemy(self.clamp_to_arena(pos, 6.0), kind):
                        self.enemies[self.enemy_count - 1].vel = scale(heading, 200.0)
                        self.enemies[self.enemy_count - 1].formation = 7.0
            }
            .Ring => {
                // A ring converging on the ship.
                for i in 0..event.count:
                    let angle = (i as f64) / event.count as f64 * 6.283185307
                    let pos = add(self.player, V2 { x: cos(angle) * 720.0, y: sin(angle) * 720.0 })
                    let _ = self.place_enemy(self.clamp_to_arena(pos, 6.0), kind)
            }
            .Spiral => {
                // A spiral unwinding from a corner of the view.
                let corner = match side:
                    0 => V2 { x: o.x - 40.0, y: o.y - 40.0 }
                    1 => V2 { x: o.x + self.screen_w + 40.0, y: o.y - 40.0 }
                    2 => V2 { x: o.x + self.screen_w + 40.0, y: o.y + self.screen_h + 40.0 }
                    _ => V2 { x: o.x - 40.0, y: o.y + self.screen_h + 40.0 }
                for i in 0..event.count:
                    let t = i as f64
                    let pos = add(corner, V2 { x: cos(t * 0.6) * t * 14.0, y: sin(t * 0.6) * t * 14.0 })
                    let _ = self.place_enemy(self.clamp_to_arena(pos, 6.0), kind)
            }
            .Lattice => {
                // A grid holding formation and drifting in together.
                let cols = 4
                let rows = (event.count + cols - 1) / cols
                let anchor = match side:
                    0 => V2 { x: o.x - 260.0, y: center.y - (rows as f64) * 30.0 }
                    1 => V2 { x: o.x + self.screen_w + 60.0, y: center.y - (rows as f64) * 30.0 }
                    2 => V2 { x: center.x - 120.0, y: o.y - 260.0 }
                    _ => V2 { x: center.x - 120.0, y: o.y + self.screen_h + 60.0 }
                let heading = direction(sub(center, add(anchor, V2 { x: 100.0, y: (rows as f64) * 30.0 })))
                for i in 0..event.count:
                    let pos = add(anchor, V2 { x: ((i % cols) as f64) * 60.0, y: ((i / cols) as f64) * 60.0 })
                    if self.place_enemy(self.clamp_to_arena(pos, 6.0), kind):
                        self.enemies[self.enemy_count - 1].vel = scale(heading, 90.0)
                        self.enemies[self.enemy_count - 1].formation = 6.0
            }
        self.show(.Event(formation: event.formation), 1.6)

    pub fn stress(mut self: Self, target: i32 = 350):
        // Populate the arena, preserving a safe circle around the player.
        let count = if target > ENEMY_CAP: ENEMY_CAP else: target
        while self.enemy_count < count:
            let pos = self.clamp_to_arena(V2 { x: 30.0 + self.random() * (self.rules.arena_width - 60.0), y: 30.0 + self.random() * (self.rules.arena_height - 60.0) }, 20.0)
            if length2(sub(pos, self.player)) < 180.0 * 180.0: continue
            let kind = kind_at((self.random() * 4.999) as i32)
            if self.place_enemy(pos, kind): self.enemies[self.enemy_count - 1].age = 0.2

    // ----- drops ---------------------------------------------------------

    pub fn drop_core(mut self: Self, pos: V2, value: i32):
        // Crowded floors merge new cores into a neighbor instead of cluttering.
        if self.core_count >= CORE_CAP / 2:
            var nearest = -1
            var best = 80.0 * 80.0
            if self.core_count >= CORE_CAP: best = 1.0e18
            for i in 0..self.core_count:
                let d = length2(sub(self.cores[i].pos, pos))
                if d < best:
                    best = d
                    nearest = i
            if nearest >= 0:
                self.cores[nearest].value += value
                return
        self.cores[self.core_count] = Core { pos, value }
        self.core_count += 1

    pub fn drop_pickup(mut self: Self, pos: V2, kind: PickupKind):
        if self.pickup_count >= PICKUP_CAP: return
        self.pickups[self.pickup_count] = Pickup { pos: self.clamp_to_arena(pos, 20.0), kind }
        self.pickup_count += 1

    fn random_pickup(mut self: Self, from_beacon: bool) -> PickupKind:
        let roll = self.random()
        if from_beacon and roll < 0.02: .Cache
        else if roll < 0.30: .Credits
        else if roll < 0.36: .Bundle
        else if roll < 0.56: .Tractor
        else if roll < 0.72: .Clear
        else if roll < 0.86: .Freeze
        else: .Repair

    // ----- combat helpers -----------------------------------------------

    pub fn kill_enemy(mut self: Self, index: i32, impact: V2, bounced: bool):
        if index < 0 or index >= self.enemy_count: return
        let e: Enemy = self.enemies[index]
        self.enemy_count -= 1
        self.enemies[index] = self.enemies[self.enemy_count]
        self.kills += 1
        self.kills_by_kind[e.kind.index()] += 1
        if bounced: self.bounced_kills += 1
        self.kill_event = true
        self.kill_energy = limit(self.kill_energy + 1.0, 0.0, 5.0)
        let power = if e.elite: 2.2 else: 1.35 + self.kill_energy * 0.12
        self.burst(e.pos, impact, if e.elite: 60 else: 22, e.kind.tint(), power)
        self.burst(e.pos, impact, 5, .White, 1.1)
        self.pulse(e.pos, (46.0 + self.kill_energy * 5.0) * e.size, e.kind.tint(), Some(e.kind))
        self.trauma = limit(self.trauma + 0.045, 0.0, 0.3)
        self.drop_core(e.pos, e.kind.core_value() * (if e.elite: 5 else: 1))
        // Now and then a kill leaves a repair behind, as a torch leaves
        // food in Vampire Survivors: healing is found in the fight.
        if self.random() < self.rules.repair_drop_chance: self.drop_pickup(e.pos, PickupKind.Repair)
        if e.elite:
            self.elites_killed += 1
            self.drop_pickup(e.pos, PickupKind.Cache)
            if self.random() < 0.5: self.drop_pickup(add(e.pos, V2 { x: 30.0 }), PickupKind.Credits)
        match e.kind:
            .Well => {
                // A well that dies bursts what it ate as a spray of darts.
                for i in 0..(4 + e.eaten):
                    let angle = (i as f64) * 6.283185307 / (4 + e.eaten) as f64
                    let pos = add(e.pos, V2 { x: cos(angle) * 40.0, y: sin(angle) * 40.0 })
                    if self.place_enemy(pos, Kind.Dart):
                        self.enemies[self.enemy_count - 1].vel = V2 { x: cos(angle) * 260.0, y: sin(angle) * 260.0 }
                        self.enemies[self.enemy_count - 1].formation = 1.2
            }
            .Boss => {
                self.boss_alive = false
                self.bosses_killed += 1
                self.boss_kill_event = true
                // The reward: a full repair, credits, and for a first kill
                // ever, a large one-time bonus and the record of it.
                self.health = self.max_health
                if e.boss >= 0:
                    self.boss_kills[e.boss] += 1
                    let bonus = 60 * (e.boss + 1)
                    self.credits += bonus
                    self.popup(add(e.pos, V2 { y: -40.0 }), .Credits(value: bonus))
                    let known = self.launch.bosses_known[e.boss]
                    if not known:
                        self.launch.bosses_known[e.boss] = true
                        let first = 400 * (e.boss + 1)
                        self.credits += first
                        self.first_kill_event = true
                        self.popup(add(e.pos, V2 { y: -70.0 }), .Credits(value: first))
                self.freeze = 0.3
                self.flash = 0.8
                self.trauma = 1.0
                self.breather = self.rules.breather
                self.drop_pickup(e.pos, PickupKind.Cache)
                self.drop_pickup(add(e.pos, V2 { x: 90.0 }), PickupKind.Bundle)
                if self.first_kill_event: self.show(.FirstKill(boss: e.boss), 3.0)
                else: self.show(.BossDown, 2.0)
                // Every other enemy dies with it, cores and all.
                var i = 0
                while i < self.enemy_count:
                    let other: Enemy = self.enemies[i]
                    if other.kind == .Null:
                        i += 1
                        continue
                    self.enemy_count -= 1
                    self.enemies[i] = self.enemies[self.enemy_count]
                    self.kills += 1
                    self.kills_by_kind[other.kind.index()] += 1
                    self.drop_core(other.pos, other.kind.core_value())
                    if self.particle_count < PARTICLE_CAP - 400: self.burst(other.pos, V2 {}, 6, other.kind.tint(), 1.2)
            }
            .Null => {
                self.null_alive = false
                self.null_killed = true
                self.freeze = 0.4
                self.flash = 1.0
                self.trauma = 1.0
                self.show(.Cleared, 3.0)
                self.finish(true)
            }
            _ => ()

    // Apply damage to one enemy; returns true when it died.
    pub fn damage_enemy(mut self: Self, index: i32, damage: i32, impact: V2, bounced: bool = false, cooldown: f64 = 0.12) -> bool:
        let target = self.enemies[index]
        let dealt = if target.kind == .Boss and target.boss >= 0: ((damage as f64) * self.boss_damage_scale(target, impact) + 0.5) as i32 else: damage
        self.enemies[index].hp -= dealt
        self.enemies[index].flash = 0.05
        self.enemies[index].hit_cd = cooldown
        let pos = self.enemies[index].pos
        if self.enemies[index].kind != .Boss and self.enemies[index].kind != .Null:
            self.enemies[index].pos = add(pos, scale(impact, 4.0))
        if self.particle_count < PARTICLE_CAP - 200: self.burst(pos, impact, 3, .Gold, 0.65)
        self.hit_event = true
        if self.enemies[index].hp <= 0:
            self.kill_enemy(index, impact, bounced)
            return true
        false

    // Enemies within a radius, each hit once per cooldown. Returns hits.
    fn damage_area(mut self: Self, pos: V2, radius: f64, damage: i32, bounced: bool = false, cooldown: f64 = 0.12) -> i32:
        var hits = 0
        var i = 0
        while i < self.enemy_count:
            let e: Enemy = self.enemies[i]
            let reach = radius + e.kind.radius() * e.size
            if e.hit_cd <= 0.0 and length2(sub(e.pos, pos)) <= reach * reach:
                hits += 1
                if not self.damage_enemy(i, damage, direction(sub(e.pos, pos)), bounced, cooldown): i += 1
            else: i += 1
        hits

    fn nearest_enemy(self: &Self, from: V2, max_distance: f64, skip_cd: bool) -> i32:
        var best = -1
        var best_d = max_distance * max_distance
        for i in 0..self.enemy_count:
            let e = self.enemies[i]
            if skip_cd and e.hit_cd > 0.0: continue
            let d = length2(sub(e.pos, from))
            if d < best_d:
                best_d = d
                best = i
        best

    fn fire_bullet(mut self: Self, pos: V2, vel: V2, stats: WeaponStats, weapon: Weapon):
        if self.bullet_count >= BULLET_CAP: return
        self.bullets[self.bullet_count] = Bullet {
            pos, vel, life: stats.lifetime, damage: stats.damage, pierce: stats.pierce, bounces: stats.bounces,
            weapon, homing: stats.homing, splits: stats.splits, shatters: stats.shatters,
        }
        self.bullet_count += 1

    // Damage everything along a lightning stroke that has not just been hit.
    fn strike_line(mut self: Self, a: V2, b: V2, damage: i32):
        self.break_beacons_on_segment(a, b, 8.0)
        var i = 0
        while i < self.enemy_count:
            let e = self.enemies[i]
            if e.hit_cd <= 0.0 and segment_hit(a, b, e.pos, 10.0 + e.kind.radius() * e.size):
                if not self.damage_enemy(i, damage, direction(sub(b, a))): i += 1
            else: i += 1

    // A random enemy in view, not struck in the last moment; -1 when none.
    fn random_visible_enemy(mut self: Self) -> i32:
        if self.enemy_count == 0: return -1
        for _ in 0..16:
            let i = (self.random() * (self.enemy_count as f64 - 0.001)) as i32
            let e = self.enemies[i]
            if e.hit_cd <= 0.0 and self.on_screen(e.pos, -20.0) and length2(sub(e.pos, self.player)) < 560.0 * 560.0: return i
        -1

    fn arc_chain(mut self: Self, from: V2, chain: i32, range: f64, damage: i32):
        var origin = from
        for _ in 0..chain:
            let target = self.nearest_enemy(origin, range, true)
            if target < 0: break
            let pos = self.enemies[target].pos
            if self.arc_count < ARC_CAP:
                self.arcs[self.arc_count] = ArcBolt { a: origin, b: pos, seed: self.rng }
                self.arc_count += 1
            let _ = self.damage_enemy(target, damage, direction(sub(pos, origin)))
            self.break_beacons_on_segment(origin, pos, 8.0)
            origin = pos

    fn detonate_mine(mut self: Self, index: i32):
        let m: Mine = self.mines[index]
        self.mine_count -= 1
        self.mines[index] = self.mines[self.mine_count]
        self.pulse(m.pos, m.radius, .Gold)
        self.burst(m.pos, V2 {}, 18, .Gold, 1.6)
        self.trauma = limit(self.trauma + 0.08, 0.0, 0.4)
        let _ = self.damage_area(m.pos, m.radius, m.damage)
        self.break_beacons_near(m.pos, m.radius)
        if m.chains: self.arc_chain(m.pos, 3, 200.0, m.damage / 2 + 1)

    fn fire_beam(mut self: Self, from: V2, heading: V2, stats: WeaponStats):
        let to = add(from, scale(heading, stats.radius))
        self.break_beacons_on_segment(from, to, 12.0)
        if self.beam_count < BEAM_CAP:
            self.beams[self.beam_count] = Beam { a: from, b: to, width: 10.0 + stats.damage as f64 }
            self.beam_count += 1
        var remaining = stats.pierce
        var i = 0
        while i < self.enemy_count and remaining > 0:
            let e = self.enemies[i]
            if e.hit_cd <= 0.0 and segment_hit(from, to, e.pos, 20.0 + e.kind.radius() * e.size):
                remaining -= 1
                if not self.damage_enemy(i, stats.damage, heading): i += 1
            else: i += 1
        if stats.shatters:
            // The beam shatters into bouncing shards where it ends.
            for k in 0..4:
                let angle = atan2(heading.y, heading.x) + (k as f64 - 1.5) * 0.5
                self.fire_bullet(to, V2 { x: cos(angle) * 600.0, y: sin(angle) * 600.0 }, WeaponStats { damage: stats.damage / 2 + 1, bounces: 2, lifetime: 1.6 }, .Shard)

    fn spawn_wave(mut self: Self, pos: V2, stats: WeaponStats):
        if self.wave_count >= SHOCKWAVE_CAP: return
        self.waves[self.wave_count] = Shockwave { pos, max_radius: stats.radius, damage: stats.damage }
        self.wave_count += 1
        self.pulse(pos, stats.radius * 0.6, .Cyan)

    // ----- weapons -------------------------------------------------------

    fn fire_weapons(mut self: Self, motion: V2, dt: f64):
        for slot in 0..SLOT_COUNT:
            let s: WeaponSlot = self.build.weapons[slot]
            if s.level == 0: continue
            let stats = weapon_stats(s.weapon, s.level, self.mods)
            self.build.weapons[slot].timer -= dt
            match s.weapon.family():
                .Orbiting => {
                    // Blades are positions on a ring; each hits once per cooldown.
                    // Fast enough that one blade sweeps the ring before a chaser crosses it.
                    let turn = dt * 6.0
                    self.build.weapons[slot].phase += turn
                    let slot_phase = self.build.weapons[slot].phase
                    var pulsed = false
                    for b in 0..stats.count:
                        let angle = slot_phase + (b as f64) * 6.283185307 / stats.count as f64
                        let blade = add(self.player, V2 { x: cos(angle) * stats.radius, y: sin(angle) * stats.radius })
                        let _ = self.damage_area(blade, 30.0, stats.damage, false, 0.3)
                        self.break_beacons_near(blade, 16.0)
                        if stats.ring_on_orbit and self.build.weapons[slot].timer <= 0.0 and not pulsed:
                            pulsed = true
                            self.spawn_wave(blade, WeaponStats { radius: 90.0, damage: stats.damage })
                    if pulsed: self.build.weapons[slot].timer = 1.4
                }
                _ => {
                    if self.build.weapons[slot].timer > 0.0: continue
                    match s.weapon.family():
                        .Aimed => {
                            if not self.launch.ship.can_aim(): continue
                            self.build.weapons[slot].timer = stats.cooldown
                            let pos = add(self.player, scale(self.aim, 26.0))
                            let side = perpendicular(self.aim)
                            for k in 0..stats.count:
                                let spread = (k as f64 - (stats.count as f64 - 1.0) / 2.0)
                                let heading = direction(add(self.aim, scale(side, spread * 0.09)))
                                self.fire_bullet(add(pos, scale(side, spread * 6.0)), scale(heading, stats.speed), stats, s.weapon)
                            self.muzzle = 0.055
                            self.shot_event = true
                        }
                        .Ring => {
                            self.build.weapons[slot].timer = stats.cooldown
                            self.spawn_wave(self.player, stats)
                            self.shot_event = true
                        }
                        .Homing => {
                            let target = self.nearest_enemy(self.player, 900.0, false)
                            if target < 0: continue
                            self.build.weapons[slot].timer = stats.cooldown
                            let toward = direction(sub(self.enemies[target].pos, self.player))
                            for k in 0..stats.count:
                                let angle = atan2(toward.y, toward.x) + (k as f64 - (stats.count as f64 - 1.0) / 2.0) * 0.5
                                self.fire_bullet(self.player, V2 { x: cos(angle) * stats.speed, y: sin(angle) * stats.speed }, stats, s.weapon)
                            self.shot_event = true
                        }
                        .Beam => {
                            // Along the movement, bent onto the nearest enemy within
                            // sixty degrees of it; standing still, at the nearest enemy.
                            // A beam that only follows the stick fires away from the
                            // swarm whenever the player backs off it.
                            let travel = if length2(motion) > 0.01: direction(motion) else if self.launch.ship.can_aim(): self.aim else: V2 {}
                            let target = self.nearest_enemy(self.player, stats.radius, false)
                            let toward = if target >= 0: direction(sub(self.enemies[target].pos, self.player)) else: V2 {}
                            let assisted = length2(toward) > 0.01 and (length2(travel) < 0.01 or travel.x * toward.x + travel.y * toward.y > 0.5)
                            let heading2 = if assisted: toward else if length2(travel) > 0.01: travel else: V2 { x: 1.0 }
                            self.build.weapons[slot].timer = stats.cooldown
                            // The Needle's card: its lance pierces twice as deep.
                            // Piercing everything scaled with the swarm itself and
                            // let an endless Needle run for an hour.
                            var beam = stats
                            if self.launch.ship == .Needle: beam.pierce *= 2
                            // Forward and back, like a whip's two sides: a ship
                            // retreating from the swarm still strikes it.
                            self.fire_beam(self.player, heading2, beam)
                            self.fire_beam(self.player, scale(heading2, -1.0), beam)
                            self.shot_event = true
                        }
                        .Dropped => {
                            if self.mine_count >= stats.max_active or self.mine_count >= MINE_CAP: continue
                            self.build.weapons[slot].timer = stats.cooldown
                            // Mines fall behind the ship along its path, spread a little,
                            // so a field forms where the ship has been.
                            let behind = if length2(motion) > 0.01: scale(direction(motion), -46.0) else: scale(self.aim, -46.0)
                            let angle = self.random() * 6.283185307
                            let jitter = V2 { x: cos(angle) * 18.0, y: sin(angle) * 18.0 }
                            let at = self.clamp_to_arena(add(self.player, add(behind, jitter)), 12.0)
                            self.mines[self.mine_count] = Mine { pos: at, radius: stats.radius, damage: stats.damage, chains: stats.chains_on_hit or self.launch.ship == .Sapper }
                            self.mine_count += 1
                        }
                        .Chain => {
                            // Lightning: bolts from the ship onto random enemies in
                            // view, each chaining on to its neighbors.
                            self.build.weapons[slot].timer = stats.cooldown
                            var struck = 0
                            let zap = ((stats.damage as f64) * self.rules.lightning_damage + 0.5) as i32
                            let zap_damage = if zap < 1: 1 else: zap
                            // The Phase carries one extra bolt.
                            let bolts = stats.count + (if self.launch.ship == .Phase: 1 else: 0)
                            for _ in 0..bolts:
                                let target = self.random_visible_enemy()
                                if target < 0: break
                                let pos = self.enemies[target].pos
                                let from = add(self.player, scale(direction(sub(pos, self.player)), 16.0))
                                if self.arc_count < ARC_CAP:
                                    self.arcs[self.arc_count] = ArcBolt { a: from, b: pos, seed: self.rng }
                                    self.arc_count += 1
                                self.pulse(pos, 44.0, .Violet)
                                let _ = self.damage_enemy(target, zap_damage, direction(sub(pos, from)))
                                // Anyone unlucky enough to be in the way is struck too.
                                self.strike_line(from, pos, zap_damage)
                                if stats.chain > 0: self.arc_chain(pos, stats.chain, stats.radius, zap_damage * 2 / 3 + 1)
                                struck += 1
                            if struck > 0: self.zap_event = true
                        }
                        .Bouncing => {
                            self.build.weapons[slot].timer = stats.cooldown
                            let base = if self.launch.ship.can_aim(): self.aim else: V2 { x: cos(self.elapsed * 3.1), y: sin(self.elapsed * 3.1) }
                            for k in 0..stats.count:
                                let angle = atan2(base.y, base.x) + (k as f64 - (stats.count as f64 - 1.0) / 2.0) * 0.35
                                self.fire_bullet(self.player, V2 { x: cos(angle) * stats.speed, y: sin(angle) * stats.speed }, stats, s.weapon)
                            self.shot_event = true
                        }
                        _ => ()
                }

    // ----- progression ---------------------------------------------------

    pub fn gain_xp(mut self: Self, value: i32):
        let gained = ((value as f64) * self.mods.xp + 0.5) as i32
        self.xp += if gained < 1: 1 else: gained
        while self.xp >= self.xp_next:
            self.xp -= self.xp_next
            self.level += 1
            self.xp_next = self.rules.xp_for_level(self.level)
            self.pending_levels += 1

    pub fn collect_core(mut self: Self, value: i32):
        self.cores_collected += 1
        self.core_event = true
        let before = combo_tier(self.combo)
        self.combo += 1
        if self.combo > self.best_combo: self.best_combo = self.combo
        let tier = combo_tier(self.combo)
        if tier > before: self.popup(add(self.player, V2 { y: -34.0 }), .ComboTier(tenths: COMBO_PAY[tier]))
        self.combo_timer = self.rules.combo_window
        self.gain_xp(value)
        // The combo pays credits by tier: x1.5 at 10, x2 at 25, x2.5 at 50,
        // x3 at 100.
        let pay = COMBO_PAY[combo_tier(self.combo)] as f64 / 10.0
        let endless_rate = if self.launch.endless: 0.35 else: 1.0
        self.credit_energy += 0.018 * pay * self.mods.credit * (value as f64) * endless_rate
        if self.credit_energy >= 1.0:
            let whole = self.credit_energy as i32
            self.credit_energy -= whole as f64
            self.credits += whole

    fn open_boost(mut self: Self, source: BoostSource):
        self.boost_source = source
        self.phase = .Boost
        self.freeze = 0.0
        self.roll_offers()

    // Draw the cards: a merge first, then a shuffle of the legal pool.
    // How often a card comes up relative to others: upgrades to what the
    // ship carries lead, so a player who commits to a build can steer it.
    fn offer_weight(self: &Self, pick: Pick) -> f64:
        match pick:
            .UpgradeWeapon(_) => self.rules.upgrade_weight
            .UpgradePassive(_) => self.rules.passive_upgrade_weight
            .NewWeapon(_) => self.rules.new_weapon_weight
            .NewPassive(_) => self.rules.new_passive_weight
            .Merge(_) => 0.0

    // Draw the cards: a ready merge first, then weighted draws without
    // replacement. A cache offers only what the ship already carries.
    fn roll_offers(mut self: Self):
        var pool = Vec.new()
        let all = self.build.candidates()
        let cache = self.boost_source == .Cache
        for p in all:
            let owned = match p:
                .UpgradeWeapon(_) => true
                .UpgradePassive(_) => true
                .Merge(_) => true
                _ => false
            if not cache or owned: pool.push(p)
        // A cache with nothing owned left to upgrade falls back to any card.
        if pool.len() == 0:
            for p in all: pool.push(p)
        let count = if self.mods.luck >= 0.3: 4 else: 3
        self.offer_count = 0
        // Every ready merge gets its own card, first: when an evolution and a
        // union share a component, the player chooses. Offering only the
        // first ready recipe hid the second for the rest of the run.
        if self.launch.ship.can_merge():
            for p in pool:
                if p.is_merge() and self.offer_count < count:
                    self.offers[self.offer_count] = Offer { pick: p, unseen: false }
                    self.offer_count += 1
        var weights = Vec.new()
        var total = 0.0
        for p in pool:
            let w = self.offer_weight(p)
            weights.push(w)
            total += w
        while self.offer_count < count and total > 0.0001:
            var roll = self.random() * total
            var chosen = -1
            for i in 0..pool.len() as i32:
                let w = weights[i]
                if w <= 0.0: continue
                if roll < w:
                    chosen = i
                    break
                roll -= w
            if chosen < 0:
                // Rounding at the top of the range: the last live card.
                for i in 0..pool.len() as i32:
                    let w = weights[i]
                    if w > 0.0: chosen = i
            if chosen < 0: break
            let pick = pool[chosen]
            let used = weights[chosen]
            total -= used
            weights[chosen] = 0.0
            let unseen = match pick:
                .NewWeapon(w) => not self.launch.taken_weapons[w.index()]
                .NewPassive(p) => not self.launch.taken_passives[p.index()]
                _ => false
            self.offers[self.offer_count] = Offer { pick, unseen }
            self.offer_count += 1
        // Nothing to offer: the build is complete. Resume.
        if self.offer_count == 0: self.resume()

    fn resume(mut self: Self):
        if self.pending_levels > 0:
            self.pending_levels -= 1
            self.level_event = true
            self.pulse(self.player, 160.0, .Lime)
            self.popup(self.player, .Level(level: self.level - self.pending_levels))
            self.freeze = self.rules.level_stop
            self.refresh_mods()
            if self.launch.ship == .Phase: self.invulnerable = self.mods.invuln_bonus
            self.open_boost(.LevelUp)
            return
        if self.pending_cache_items > 0:
            self.pending_cache_items -= 1
            self.cache_reveal = 1.0
            self.open_boost(.Cache)
            return
        self.phase = .Running

    // The player takes a card. Presentation ignores input while a cache spins.
    pub fn choose(mut self: Self, index: i32):
        if self.phase != .Boost or index < 0 or index >= self.offer_count or self.cache_reveal > 0.0: return
        let pick = self.offers[index].pick
        match pick:
            .NewWeapon(w) => { self.launch.taken_weapons[w.index()] = true }
            .NewPassive(p) => { self.launch.taken_passives[p.index()] = true }
            .Merge(w) => {
                self.launch.taken_weapons[w.index()] = true
                self.merge_event = true
                self.freeze = self.rules.merge_stop
                self.flash = 0.6
                self.pulse(self.player, 260.0, .White)
                self.burst(self.player, V2 {}, 90, .White, 2.2)
                self.show(.Merge(weapon: w), 2.4)
            }
            _ => ()
        self.build.apply(pick)
        self.refresh_mods()
        self.resume()

    pub fn reroll(mut self: Self):
        if self.phase != .Boost or self.rerolls <= 0 or self.cache_reveal > 0.0: return
        self.rerolls -= 1
        self.roll_offers()

    pub fn skip(mut self: Self):
        if self.phase != .Boost or self.skips <= 0 or self.cache_reveal > 0.0: return
        self.skips -= 1
        self.resume()

    pub fn banish(mut self: Self, index: i32):
        if self.phase != .Boost or self.banishes <= 0 or index < 0 or index >= self.offer_count or self.cache_reveal > 0.0: return
        if self.offers[index].pick.is_merge(): return
        self.banishes -= 1
        self.build.banish(self.offers[index].pick)
        self.roll_offers()

    pub fn open_cache(mut self: Self):
        self.caches_opened += 1
        self.cache_event = true
        // One item, or with luck three or five.
        let roll = self.random()
        let items = if roll < self.mods.luck * 0.08: 5 else if roll < self.mods.luck * 0.3: 3 else: 1
        self.pending_cache_items += items
        if self.phase == .Running: self.resume()

    // ----- health ----------------------------------------------------------

    pub fn hurt(mut self: Self, kind: Kind, elite: bool, raw: i32):
        if self.health <= 0 or self.invulnerable > 0.0 or self.phase != .Running: return
        var damage = raw - self.mods.armor
        if kind == .Null: damage = 1000
        if damage < 1: damage = 1
        self.health_before = self.health
        self.health -= damage
        self.hits_taken += 1
        self.combo = 0
        self.combo_timer = 0.0
        self.invulnerable = self.rules.invulnerability
        self.trauma = 0.7
        self.flash = 0.55
        self.freeze = self.rules.damage_stop
        self.hurt_event = true
        self.burst(self.player, V2 {}, 28, .White, 1.2)
        if self.health <= 0:
            if self.reboots > 0 and kind != .Null:
                // A reboot: full repair, a clearing pulse, three seconds of grace.
                self.reboots -= 1
                self.reboot_used = true
                self.health = self.max_health
                self.invulnerable = 3.0
                self.flash = 0.9
                self.freeze = 0.2
                self.pulse(self.player, 320.0, .White)
                self.burst(self.player, V2 {}, 80, .Cyan, 2.0)
                let _ = self.damage_area(self.player, 320.0, 9999)
                self.show(.Reboot, 2.0)
                return
            self.killer = Some(kind)
            self.killer_elite = elite
            self.trauma = 1.0
            self.flash = 0.9
            self.freeze = self.rules.death_stop
            self.death_event = true
            self.burst(self.player, V2 {}, 110, .Cyan, 2.0)
            self.burst(self.player, V2 {}, 40, .White, 2.4)
            self.pulse(self.player, 180.0, .Cyan)
            self.pulse(self.player, 100.0, .White)
            self.finish(self.cleared)

    // The player ends the run from the pause screen: banked like a death.
    pub fn abandon(mut self: Self):
        if self.phase == .Over: return
        self.finish(false)

    fn finish(mut self: Self, was_cleared: bool):
        self.cleared = was_cleared
        self.phase = .Over
        // The run's credits: kills, minutes, and the best combo, banked whatever happened.
        // Endless pays half: it is the long tail, not the fastest way to fill the shop.
        let rate = if self.launch.endless: 0.35 else: 1.0
        let bonus = (self.kills as f64 / 10.0 + self.minute() * 5.0 + self.best_combo as f64 / 4.0) * self.mods.credit * rate
        self.credits += bonus as i32

    // ----- the tick ----------------------------------------------------------

    fn effects(mut self: Self, dt: f64):
        self.trauma = limit(self.trauma - dt * 1.8, 0.0, 1.0)
        self.flash = limit(self.flash - dt * 2.8, 0.0, 1.0)
        self.muzzle = limit(self.muzzle - dt, 0.0, 1.0)
        self.kill_energy = limit(self.kill_energy - dt * 3.0, 0.0, 5.0)
        self.best_flare = limit(self.best_flare - dt, 0.0, 5.0)
        self.zoom_timer = limit(self.zoom_timer - dt, 0.0, 5.0)
        if self.banner.life > 0.0: self.banner.life -= dt
        var i = 0
        while i < self.particle_count:
            var p: Particle = self.particles[i]
            p.life -= dt
            if p.life <= 0.0:
                self.particle_count -= 1
                self.particles[i] = self.particles[self.particle_count]
                continue
            p.pos = add(p.pos, scale(p.vel, dt))
            p.vel = scale(p.vel, 1.0 / (1.0 + dt * 2.6))
            p.rotation += dt * 4.0
            self.particles[i] = p
            i += 1
        var j = 0
        while j < self.pulse_count:
            self.pulses[j].life -= dt
            if self.pulses[j].life <= 0.0:
                self.pulse_count -= 1
                self.pulses[j] = self.pulses[self.pulse_count]
                continue
            j += 1
        var k = 0
        while k < self.popup_count:
            self.popups[k].life -= dt
            self.popups[k].pos.y -= dt * 34.0
            if self.popups[k].life <= 0.0:
                self.popup_count -= 1
                self.popups[k] = self.popups[self.popup_count]
                continue
            k += 1
        var b = 0
        while b < self.beam_count:
            self.beams[b].life -= dt
            if self.beams[b].life <= 0.0:
                self.beam_count -= 1
                self.beams[b] = self.beams[self.beam_count]
                continue
            b += 1
        var a = 0
        while a < self.arc_count:
            self.arcs[a].life -= dt
            if self.arcs[a].life <= 0.0:
                self.arc_count -= 1
                self.arcs[a] = self.arcs[self.arc_count]
                continue
            a += 1

    fn rebuild_grid(mut self: Self):
        for cell in 0..CELL_COUNT: self.cell_heads[cell] = -1
        for e in 0..self.enemy_count:
            let cell = cell_index(self.enemies[e].pos)
            self.cell_next[e] = self.cell_heads[cell]
            self.cell_heads[cell] = e

    fn step_timeline(mut self: Self, dt: f64):
        if self.launch.endless and self.minute() >= 20.0:
            let loop_now = ((self.minute() - 10.0) / 10.0) as i32
            if loop_now > self.endless_loop:
                self.endless_loop = loop_now
                self.show(.Endless(cycle: loop_now), 2.5)
        else if not self.launch.endless and self.elapsed >= self.rules.run_cap and not self.null_alive and not self.cleared:
            // Surviving to the cap is a clear; the Null ends the run.
            self.cleared = true
            self.spawn_null()
        // Bosses.
        if let Some(minute) = self.boss_minute():
            if not self.launch.endless or self.minute() < 20.0:
                if self.minute() >= minute and not self.boss_alive:
                    self.boss_index += 1
                    self.spawn_boss()
        // During a boss fight nothing else arrives, and the elite clock waits.
        if self.boss_alive:
            self.next_elite += dt
            return
        // Elites every minute from three.
        if self.elapsed >= self.next_elite:
            self.next_elite += self.rules.elite_interval
            self.spawn_elite()
        // Events: telegraph for two seconds, then the formation.
        if self.event_telegraph > 0.0:
            self.event_telegraph -= dt
            if self.event_telegraph <= 0.0:
                let table = events()
                self.spawn_event(table[self.event_index])
                self.event_index += 1
        else if self.event_index < 12 and not self.launch.endless:
            let table = events()
            if self.minute() >= table[self.event_index].minute:
                self.event_telegraph = 2.0
                self.event_side = (self.random() * 3.999) as i32
        // Vampire Survivors' model: the arena is kept at a minimum number
        // of enemies, filled from just off screen, so standing still is
        // fatal within seconds and clearing buys only a moment. A trickle
        // of ordinary spawns rides on top.
        if self.breather <= 0.0 and not self.null_alive:
            let floor = (self.rules.minimum_alive(self.table_minute()) * self.rules.spawn_scale * (1.0 + self.mods.overclock) * self.loop_scale(1.3)) as i32
            self.refill_timer -= dt
            if self.enemy_count < floor and self.refill_timer <= 0.0 and self.enemy_count < ENEMY_CAP - 64:
                self.refill_timer = 0.12
                self.spawn_enemy()
        // Ordinary spawns, thinned in a breather and clamped to the budget.
        self.spawn_timer -= dt
        if self.spawn_timer <= 0.0:
            var rate = self.rules.spawn_rate(self.table_minute()) * self.rules.spawn_scale * (1.0 + self.mods.overclock) * self.loop_scale(1.3)
            if self.breather > 0.0: rate *= 0.25
            if self.null_alive: rate *= 0.5
            self.spawn_timer += 1.0 / rate
            if self.enemy_count < ENEMY_CAP - 64: self.spawn_enemy()
            else: self.spawn_timer += 0.05

    fn boss_position(self: &Self) -> Option[V2]:
        for i in 0..self.enemy_count:
            if self.enemies[i].kind == .Boss: return Some(self.enemies[i].pos)
        None

    fn hostile_shot(mut self: Self, from: V2, heading: V2, speed: f64, damage: i32):
        if self.bullet_count >= BULLET_CAP: return
        self.bullets[self.bullet_count] = Bullet { pos: from, vel: scale(direction(heading), speed), life: 5.0, damage, hostile: true, weapon: .Cannon }
        self.bullet_count += 1

    fn step_enemies(mut self: Self, dt: f64):
        let hive = self.boss_position()
        let frozen = self.enemies_frozen > 0.0
        for e in 0..self.enemy_count:
            var enemy: Enemy = self.enemies[e]
            enemy.age += dt
            enemy.flash = limit(enemy.flash - dt, 0.0, 1.0)
            enemy.hit_cd = limit(enemy.hit_cd - dt, 0.0, 1.0)
            if frozen and enemy.kind != .Null:
                self.enemies[e] = enemy
                continue
            if enemy.age < self.rules.spawn_grace:
                self.enemies[e] = enemy
                continue
            let to_player = sub(self.player, enemy.pos)
            let toward = self.path_toward(enemy.pos)
            let distance = sqrt(length2(to_player))
            var separation = V2 {}
            if enemy.kind != .Boss and enemy.kind != .Null and enemy.kind != .Well:
                let cell = cell_index(enemy.pos)
                let cx = cell % CELL_COLS
                let cy = cell / CELL_COLS
                for dy in -1..2:
                    for dx in -1..2:
                        let x = cx + dx
                        let y = cy + dy
                        if x < 0 or x >= CELL_COLS or y < 0 or y >= CELL_ROWS: continue
                        var other = self.cell_heads[y * CELL_COLS + x]
                        while other >= 0:
                            if other != e:
                                let delta = sub(enemy.pos, self.enemies[other].pos)
                                let d = sqrt(length2(delta))
                                let reach = 30.0 * enemy.size
                                if d > 0.01 and d < reach:
                                    separation = add(separation, scale(delta, (reach - d) / (reach * d)))
                            other = self.cell_next[other]
            var velocity = V2 {}
            if enemy.drone:
                // Drones hold a ring around the Hive and fire aimed bolts.
                if let Some(core) = hive:
                    let a = self.elapsed * 0.8 + enemy.eaten as f64 * 1.5708
                    enemy.pos = add(core, V2 { x: cos(a) * 170.0, y: sin(a) * 170.0 })
                enemy.timer -= dt
                if enemy.timer <= 0.0:
                    // A three-bolt burst at the ship.
                    enemy.timer = 1.8
                    let facing = direction(sub(self.player, enemy.pos))
                    let base = atan2(facing.y, facing.x)
                    for k in 0..3:
                        let a = base + (k as f64 - 1.0) * 0.12
                        self.hostile_shot(enemy.pos, V2 { x: cos(a), y: sin(a) }, 230.0, 3 + self.endless_loop)
                self.enemies[e] = enemy
                continue
            if enemy.formation > 0.0:
                enemy.formation -= dt
                velocity = enemy.vel
            else:
                match enemy.kind:
                    .Block => { velocity = scale(toward, enemy.speed) }
                    .Dart => {
                        // Rush straight at where the ship was, rest, repeat.
                        enemy.timer -= dt
                        if enemy.state == 0:
                            // A rush starts only on screen: no untelegraphed off-screen death.
                            if enemy.timer <= 0.0 and self.on_screen(enemy.pos, -20.0):
                                enemy.state = 1
                                enemy.timer = 1.0
                                // A rush a little slower than the ship: dodgeable, not escapable by standing.
                                enemy.vel = scale(toward, enemy.speed * 1.6)
                            else: velocity = scale(toward, enemy.speed * 0.5)
                        else:
                            velocity = enemy.vel
                            if enemy.timer <= 0.0:
                                enemy.state = 0
                                enemy.timer = 0.45
                    }
                    .Spinner => {
                        // Track, telegraph, charge.
                        enemy.timer -= dt
                        if enemy.state == 0:
                            velocity = scale(toward, enemy.speed)
                            if enemy.timer <= 0.0 and self.on_screen(enemy.pos, -20.0):
                                enemy.state = 1
                                enemy.timer = 0.5
                        else if enemy.state == 1:
                            enemy.flash = 0.02
                            enemy.vel = scale(toward, enemy.speed * 3.4)
                            if enemy.timer <= 0.0:
                                enemy.state = 2
                                enemy.timer = 0.6
                        else:
                            velocity = enemy.vel
                            if enemy.timer <= 0.0:
                                enemy.state = 0
                                enemy.timer = 1.6
                    }
                    .Weaver => {
                        // Hold range and lob slow bolts.
                        let want = 280.0
                        if distance > want + 40.0: velocity = scale(toward, enemy.speed)
                        else if distance < want - 40.0: velocity = scale(toward, -enemy.speed)
                        else: velocity = scale(perpendicular(toward), enemy.speed * 0.6)
                        enemy.timer -= dt
                        if enemy.timer <= 0.0 and distance < 620.0 and self.on_screen(enemy.pos, -20.0) and self.bullet_count < BULLET_CAP:
                            enemy.timer = 2.4
                            self.bullets[self.bullet_count] = Bullet { pos: enemy.pos, vel: scale(toward, 190.0), life: 4.0, damage: self.contact(enemy.kind), hostile: true, weapon: .Cannon }
                            self.bullet_count += 1
                    }
                    .Skimmer => {
                        // Sidestep the nearest incoming bolt; otherwise chase.
                        enemy.timer -= dt
                        velocity = scale(toward, enemy.speed)
                        if enemy.timer <= 0.0:
                            for b in 0..self.bullet_count:
                                let bullet = self.bullets[b]
                                if bullet.hostile: continue
                                let rel = sub(enemy.pos, bullet.pos)
                                let closing = rel.x * bullet.vel.x + rel.y * bullet.vel.y
                                if closing > 0.0 and length2(rel) < 130.0 * 130.0:
                                    let side = perpendicular(direction(bullet.vel))
                                    let sign = if side.x * rel.x + side.y * rel.y >= 0.0: 1.0 else: -1.0
                                    enemy.vel = scale(side, sign * enemy.speed * 4.0)
                                    enemy.timer = 0.55
                                    enemy.state = 1
                                    break
                        if enemy.state == 1:
                            velocity = add(velocity, enemy.vel)
                            enemy.vel = scale(enemy.vel, 1.0 / (1.0 + dt * 6.0))
                            if enemy.timer <= 0.0: enemy.state = 0
                    }
                    .Well => {
                        // Drift, pull, eat, grow. Full wells burst as darts.
                        enemy.timer -= dt
                        if enemy.timer <= 0.0:
                            enemy.timer = 2.0 + self.random() * 2.0
                            let angle = self.random() * 6.283185307
                            enemy.vel = V2 { x: cos(angle) * 30.0, y: sin(angle) * 30.0 }
                        velocity = add(enemy.vel, scale(toward, 12.0))
                        let reach = 220.0 * enemy.size
                        for o in 0..self.enemy_count:
                            if o == e: continue
                            let other: Enemy = self.enemies[o]
                            if other.kind == .Boss or other.kind == .Null or other.kind == .Well: continue
                            let delta = sub(enemy.pos, other.pos)
                            let d2 = length2(delta)
                            if d2 < reach * reach and d2 > 1.0:
                                let d = sqrt(d2)
                                self.enemies[o].pos = add(other.pos, scale(delta, (160.0 * dt) / d))
                                if d < 18.0 * enemy.size:
                                    // Eaten: no core, the well grows.
                                    self.enemies[o].hp = 0
                                    self.enemies[o].pos = V2 { x: -100000.0, y: -100000.0 }
                                    enemy.eaten += 1
                                    enemy.hp += 4
                                    enemy.max_hp += 4
                                    enemy.size = 1.0 + (enemy.eaten as f64) * 0.08
                        for c in 0..self.core_count:
                            let delta = sub(enemy.pos, self.cores[c].pos)
                            if length2(delta) < reach * reach: self.cores[c].pos = add(self.cores[c].pos, scale(direction(delta), 120.0 * dt))
                        if enemy.eaten >= 12:
                            enemy.hp = 0
                    }
                    .Boss => {
                        enemy.timer -= dt
                        let shot_damage = (if enemy.boss == 0: 2 else: 3) + self.endless_loop
                        match enemy.boss:
                            0 => {
                                // Warden: turns slowly to face the ship, drifts in,
                                // and sprays a turning spiral. Its back is the target.
                                let want = direction(sub(self.player, enemy.pos))
                                let turn = limit(dt * 0.9, 0.0, 1.0)
                                enemy.facing = direction(add(scale(enemy.facing, 1.0 - turn), scale(want, turn)))
                                velocity = scale(toward, enemy.speed * 0.45)
                                if enemy.timer <= 0.0:
                                    enemy.timer = 0.12
                                    enemy.state += 1
                                    let beat = enemy.state % 30
                                    if beat < 20:
                                        // A three-armed spiral, turning.
                                        enemy.angle += 0.26
                                        for k in 0..3:
                                            let a = enemy.angle + k as f64 * 2.0944
                                            self.hostile_shot(enemy.pos, V2 { x: cos(a), y: sin(a) }, 175.0, shot_damage)
                                    else if beat == 24:
                                        // Then an aimed fan at the ship.
                                        let facing = direction(sub(self.player, enemy.pos))
                                        let base = atan2(facing.y, facing.x)
                                        for k in 0..5:
                                            let a = base + (k as f64 - 2.0) * 0.14
                                            self.hostile_shot(enemy.pos, V2 { x: cos(a), y: sin(a) }, 260.0, shot_damage)
                            }
                            1 => {
                                // Lancer: closes in, locks a line, charges, and is
                                // stunned where it lands. Stunned is when it breaks.
                                if enemy.state == 0:
                                    velocity = scale(toward, enemy.speed * 0.8)
                                    enemy.facing = toward
                                    if enemy.timer <= 0.0:
                                        enemy.state = 1
                                        enemy.timer = 1.0
                                else if enemy.state == 1:
                                    enemy.facing = direction(sub(self.player, enemy.pos))
                                    enemy.flash = 0.02
                                    if enemy.timer <= 0.0:
                                        enemy.state = 2
                                        enemy.timer = 0.9
                                        enemy.vel = scale(enemy.facing, 950.0)
                                else if enemy.state == 2:
                                    velocity = enemy.vel
                                    let ahead = add(enemy.pos, scale(enemy.vel, dt))
                                    if enemy.timer <= 0.0 or not self.in_arena(ahead, -60.0):
                                        // Below half health it recovers faster.
                                        let enraged = enemy.hp * 2 < enemy.max_hp
                                        enemy.state = 3
                                        enemy.timer = if enraged: 1.1 else: 1.8
                                        self.trauma = limit(self.trauma + 0.4, 0.0, 1.0)
                                        let facing = direction(sub(self.player, enemy.pos))
                                        let base = atan2(facing.y, facing.x)
                                        for k in 0..9:
                                            let a = base + (k as f64 - 4.0) * 0.18
                                            self.hostile_shot(enemy.pos, V2 { x: cos(a), y: sin(a) }, 210.0, shot_damage)
                                else:
                                    if enemy.timer <= 0.0:
                                        enemy.state = 0
                                        enemy.timer = if enemy.hp * 2 < enemy.max_hp: 0.9 else: 2.0
                            }
                            _ => {
                                // Hive: drifts; its drones shield it. With every drone
                                // down it is open for eight seconds, then rebuilds them.
                                velocity = scale(toward, enemy.speed * 0.3)
                                if self.drones_alive() == 0:
                                    if enemy.state == 0:
                                        enemy.state = 1
                                        enemy.timer = 8.0
                                        enemy.angle = 0.0
                                    else if enemy.timer <= 0.0:
                                        enemy.state = 0
                                        self.spawn_drones(enemy.pos)
                                    else:
                                        // Open, it pulses rings of bolts.
                                        enemy.angle -= dt
                                        if enemy.angle <= 0.0:
                                            enemy.angle = 1.1
                                            let turn = self.random() * 0.5
                                            for k in 0..14:
                                                let a = turn + k as f64 * 0.4488
                                                self.hostile_shot(enemy.pos, V2 { x: cos(a), y: sin(a) }, 190.0, shot_damage)
                            }
                    }
                    .Null => { velocity = scale(toward, enemy.speed) }
            let velocity2 = if enemy.kind == .Boss or enemy.kind == .Null: velocity else: add(velocity, scale(movement(separation), 150.0))
            enemy.pos = add(enemy.pos, scale(velocity2, dt))
            // Nothing sits on the ship: enemies stop at a small core around
            // it, inside the contact reach, so they still hurt and the
            // player's silhouette is never covered.
            if enemy.kind != .Boss and enemy.kind != .Null:
                let off = sub(enemy.pos, self.player)
                let core = 28.0 + enemy.kind.radius() * (enemy.size - 1.0)
                if length2(off) < core * core:
                    let away = if length2(off) > 0.01: direction(off) else: V2 { x: 1.0 }
                    enemy.pos = add(self.player, scale(away, core))
            // Walls stop everyone; formation enemies turn to chase at the wall.
            let inset = enemy.kind.radius() * enemy.size * 0.5
            let clamped = self.clamp_to_arena(enemy.pos, inset)
            if clamped.x != enemy.pos.x or clamped.y != enemy.pos.y:
                enemy.formation = 0.0
                if enemy.kind == .Dart or enemy.kind == .Spinner or enemy.kind == .Boss: enemy.state = 0
            enemy.pos = clamped
            self.enemies[e] = enemy
        // Remove anything a well ate or that burst.
        var i = 0
        while i < self.enemy_count:
            if self.enemies[i].hp <= 0:
                let e = self.enemies[i]
                if e.kind == .Well and e.pos.x > -1000.0:
                    self.kill_enemy(i, V2 {}, false)
                else:
                    self.enemy_count -= 1
                    self.enemies[i] = self.enemies[self.enemy_count]
                continue
            i += 1

    fn step_bullets(mut self: Self, dt: f64):
        var b = 0
        while b < self.bullet_count:
            var bullet: Bullet = self.bullets[b]
            let previous: V2 = bullet.pos
            if bullet.hostile:
                bullet.pos = add(bullet.pos, scale(bullet.vel, dt))
                bullet.life -= dt
                var gone = bullet.life <= 0.0 or not self.in_arena(bullet.pos, 0.0) or self.in_wall(bullet.pos)
                if segment_hit(previous, bullet.pos, self.player, 16.0):
                    self.hurt(.Weaver, false, bullet.damage)
                    gone = true
                if gone:
                    self.bullet_count -= 1
                    self.bullets[b] = self.bullets[self.bullet_count]
                    continue
                self.bullets[b] = bullet
                b += 1
                continue
            // A sparse wake: one sparkle every third step keeps the muzzle clear.
            if bullet.steps % 3 == 0 and self.particle_count < PARTICLE_CAP - 600:
                let side = perpendicular(bullet.vel)
                let scatter = (self.random() - 0.5) * 0.10
                self.emit(Particle {
                    pos: previous, vel: add(scale(bullet.vel, -0.03), scale(side, scatter)),
                    life: 0.3, total: 0.3, size: 1.2, tint: .Gold,
                })
            bullet.steps += 1
            if bullet.homing:
                let target = self.nearest_enemy(bullet.pos, 700.0, false)
                if target >= 0:
                    let want = direction(sub(self.enemies[target].pos, bullet.pos))
                    let speed = sqrt(length2(bullet.vel))
                    bullet.vel = scale(direction(add(direction(bullet.vel), scale(want, dt * 9.0))), speed)
            bullet.pos = add(bullet.pos, scale(bullet.vel, dt))
            bullet.life -= dt
            // Walls: bounce while bounces remain, otherwise the bolt is spent.
            var spent = false
            let r: Rules = self.rules
            if bullet.pos.x < 0.0 or bullet.pos.x > r.arena_width or bullet.pos.y < 0.0 or bullet.pos.y > r.arena_height:
                if bullet.bounces > 0:
                    bullet.bounces -= 1
                    bullet.bounced = true
                    if bullet.pos.x < 0.0 or bullet.pos.x > r.arena_width: bullet.vel.x = -bullet.vel.x
                    if bullet.pos.y < 0.0 or bullet.pos.y > r.arena_height: bullet.vel.y = -bullet.vel.y
                    bullet.pos = self.clamp_to_arena(bullet.pos, 1.0)
                    self.pulse(bullet.pos, 24.0, .Gold)
                    if bullet.splits and self.bullet_count < BULLET_CAP - 1:
                        let side = perpendicular(direction(bullet.vel))
                        self.bullets[self.bullet_count] = Bullet { pos: bullet.pos, vel: add(scale(bullet.vel, 0.9), scale(side, 180.0)), life: bullet.life, damage: bullet.damage, bounces: bullet.bounces, bounced: true, weapon: bullet.weapon }
                        self.bullet_count += 1
                else: spent = true
            // Walls: a bolt bounces off the face it crossed, or is spent.
            let hit_wall = if spent: -1 else: self.wall_at(bullet.pos)
            if hit_wall >= 0:
                if bullet.bounces > 0:
                    bullet.bounces -= 1
                    bullet.bounced = true
                    let w = self.walls[hit_wall]
                    let from_side = previous.x <= w.x or previous.x >= w.x + w.w
                    if from_side: bullet.vel.x = -bullet.vel.x else: bullet.vel.y = -bullet.vel.y
                    bullet.pos = previous
                    self.pulse(bullet.pos, 24.0, .Gold)
                else: spent = true
            if not spent and self.in_void(bullet.pos):
                if bullet.bounces > 0:
                    bullet.bounces -= 1
                    bullet.bounced = true
                    let normal = direction(sub(bullet.pos, self.center()))
                    let along = bullet.vel.x * normal.x + bullet.vel.y * normal.y
                    bullet.vel = sub(bullet.vel, scale(normal, 2.0 * along))
                    bullet.pos = self.clamp_to_arena(bullet.pos, 1.0)
                    self.pulse(bullet.pos, 24.0, .Gold)
                else: spent = true
            var hit = false
            if not spent:
                // Enemies in the cells around the bolt; big enemies are few
                // and checked by radius as the grid cannot bound them.
                let cell = cell_index(bullet.pos)
                let cx = cell % CELL_COLS
                let cy = cell / CELL_COLS
                var target = -1
                for dy in -1..2:
                    if target >= 0: break
                    for dx in -1..2:
                        let x = cx + dx
                        let y = cy + dy
                        if x < 0 or x >= CELL_COLS or y < 0 or y >= CELL_ROWS: continue
                        var other = self.cell_heads[y * CELL_COLS + x]
                        while other >= 0:
                            if other >= self.enemy_count:
                                other = self.cell_next[other]
                                continue
                            let e = self.enemies[other]
                            if e.hit_cd <= 0.0 or bullet.pierce == 0:
                                if segment_hit(previous, bullet.pos, e.pos, r.bullet_hit_radius + (e.kind.radius() - 14.0) * e.size):
                                    target = other
                                    break
                            other = self.cell_next[other]
                        if target >= 0: break
                if target < 0:
                    for i in 0..self.enemy_count:
                        let e = self.enemies[i]
                        if e.size > 1.2 or e.kind == .Boss or e.kind == .Null:
                            if e.hit_cd <= 0.0 or bullet.pierce == 0:
                                if segment_hit(previous, bullet.pos, e.pos, r.bullet_hit_radius + e.kind.radius() * e.size):
                                    target = i
                                    break
                if target >= 0:
                    let impact = direction(bullet.vel)
                    let _ = self.damage_enemy(target, bullet.damage, impact, bullet.bounced)
                    if bullet.pierce > 0: bullet.pierce -= 1
                    else: hit = true
            if hit or spent or bullet.life <= 0.0:
                self.bullet_count -= 1
                self.bullets[b] = self.bullets[self.bullet_count]
                continue
            self.bullets[b] = bullet
            b += 1

    fn step_fields(mut self: Self, dt: f64):
        // Nova rings expand and hit each enemy once as they pass.
        var w = 0
        while w < self.wave_count:
            var wave: Shockwave = self.waves[w]
            wave.life -= dt
            let previous: f64 = wave.radius
            wave.radius = wave.max_radius * (1.0 - wave.life / wave.total)
            var i = 0
            while i < self.enemy_count:
                let e: Enemy = self.enemies[i]
                let d = sqrt(length2(sub(e.pos, wave.pos)))
                let reach = e.kind.radius() * e.size
                // Each ring strikes an enemy once, as its edge crosses it.
                if d - reach <= wave.radius and d + reach >= previous:
                    if not self.damage_enemy(i, wave.damage, direction(sub(e.pos, wave.pos))): i += 1
                else: i += 1
            // The ring's edge breaks any beacon it crosses.
            for k in 0..self.beacon_count:
                if not self.beacons[k].alive: continue
                let d = sqrt(length2(sub(self.beacons[k].pos, wave.pos)))
                if d - 20.0 <= wave.radius and d + 20.0 >= previous: self.break_beacon(k)
            if wave.life <= 0.0:
                self.wave_count -= 1
                self.waves[w] = self.waves[self.wave_count]
                continue
            self.waves[w] = wave
            w += 1
        // Mines detonate on contact.
        var m = 0
        while m < self.mine_count:
            self.mines[m].age += dt
            let mine = self.mines[m]
            var touched = false
            for i in 0..self.enemy_count:
                let e = self.enemies[i]
                if length2(sub(e.pos, mine.pos)) < (24.0 + e.kind.radius() * e.size) * (24.0 + e.kind.radius() * e.size):
                    touched = true
                    break
            if touched:
                self.detonate_mine(m)
                continue
            m += 1
        // Uncollected cores merge into larger cores after a few seconds so the
        // floor never fills with clutter. Twice a second is enough.
        let before = self.elapsed - dt
        if (self.elapsed * 2.0) as i32 != (before * 2.0) as i32: self.merge_cores()
        // Cores drift to the ship inside the magnet radius.
        let magnet = self.rules.magnet_radius * self.mods.magnet
        var c = 0
        while c < self.core_count:
            var core: Core = self.cores[c]
            core.age += dt
            let delta = sub(self.player, core.pos)
            let d2 = length2(delta)
            if d2 < 22.0 * 22.0:
                self.collect_core(core.value)
                if self.particle_count < PARTICLE_CAP - 300: self.burst(core.pos, V2 {}, 3, .Cyan, 0.5)
                self.core_count -= 1
                self.cores[c] = self.cores[self.core_count]
                continue
            if d2 < magnet * magnet:
                let pull = self.rules.core_speed * (1.0 + (magnet - sqrt(d2)) / magnet)
                core.pos = add(core.pos, scale(direction(delta), pull * dt))
            self.cores[c] = core
            c += 1
        // Pickups.
        var p = 0
        while p < self.pickup_count:
            self.pickups[p].age += dt
            let pickup: Pickup = self.pickups[p]
            if length2(sub(self.player, pickup.pos)) < 30.0 * 30.0:
                self.pickup_count -= 1
                self.pickups[p] = self.pickups[self.pickup_count]
                self.apply_pickup(pickup)
                continue
            p += 1
        // Beacons: any bullet destroys one; it drops a pickup and respawns.
        for i in 0..self.beacon_count:
            var beacon: Beacon = self.beacons[i]
            if not beacon.alive:
                beacon.respawn -= dt
                if beacon.respawn <= 0.0:
                    beacon.alive = true
                    beacon.pos = self.clamp_to_arena(V2 { x: 120.0 + self.random() * (self.rules.arena_width - 240.0), y: 120.0 + self.random() * (self.rules.arena_height - 240.0) }, 60.0)
                self.beacons[i] = beacon
                continue
            var b = 0
            while b < self.bullet_count:
                let bullet = self.bullets[b]
                if not bullet.hostile and length2(sub(bullet.pos, beacon.pos)) < 26.0 * 26.0:
                    self.beacons[i] = beacon
                    self.break_beacon(i)
                    beacon = self.beacons[i]
                    self.bullet_count -= 1
                    self.bullets[b] = self.bullets[self.bullet_count]
                    break
                b += 1
            self.beacons[i] = beacon

    // A beacon breaks, drops a pickup, and respawns elsewhere later.
    fn break_beacon(mut self: Self, i: i32):
        if not self.beacons[i].alive: return
        let pos = self.beacons[i].pos
        self.beacons[i].alive = false
        self.beacons[i].respawn = self.rules.beacon_respawn
        self.pulse(pos, 90.0, .Gold)
        self.burst(pos, V2 {}, 30, .Gold, 1.5)
        let kind = self.random_pickup(true)
        self.drop_pickup(pos, kind)

    // Every weapon breaks beacons, not only bullets: blades, rings, beams,
    // blasts, and lightning all hit what they touch.
    fn break_beacons_near(mut self: Self, pos: V2, radius: f64):
        for i in 0..self.beacon_count:
            if self.beacons[i].alive and length2(sub(self.beacons[i].pos, pos)) <= (radius + 20.0) * (radius + 20.0): self.break_beacon(i)

    fn break_beacons_on_segment(mut self: Self, a: V2, b: V2, width: f64):
        for i in 0..self.beacon_count:
            if self.beacons[i].alive and segment_hit(a, b, self.beacons[i].pos, width + 20.0): self.break_beacon(i)

    fn freeze_enemies(mut self: Self, seconds: f64):
        self.enemies_frozen = seconds

    fn repair(mut self: Self, amount: i32):
        self.health += amount
        if self.health > self.max_health: self.health = self.max_health

    fn merge_cores(mut self: Self):
        var i = 0
        while i < self.core_count:
            if self.cores[i].age < self.rules.core_merge_age:
                i += 1
                continue
            var j = i + 1
            while j < self.core_count:
                let other: Core = self.cores[j]
                if other.age >= self.rules.core_merge_age and length2(sub(other.pos, self.cores[i].pos)) < 60.0 * 60.0:
                    self.cores[i].value += other.value
                    self.core_count -= 1
                    self.cores[j] = self.cores[self.core_count]
                    continue
                j += 1
            i += 1

    fn apply_pickup(mut self: Self, pickup: Pickup):
        self.pickup_event = true
        self.popup(self.player, .Pickup(kind: pickup.kind))
        match pickup.kind:
            .Tractor => {
                for c in 0..self.core_count: self.cores[c].pos = add(self.player, scale(direction(sub(self.cores[c].pos, self.player)), 20.0))
                self.pulse(self.player, 400.0, .Cyan)
            }
            .Clear => {
                var i = 0
                while i < self.enemy_count:
                    let e = self.enemies[i]
                    if e.kind != .Boss and e.kind != .Null and self.on_screen(e.pos, 40.0):
                        self.kill_enemy(i, V2 {}, false)
                    else: i += 1
                self.flash = 0.7
                self.trauma = 0.6
                self.pulse(self.player, 500.0, .White)
            }
            .Freeze => self.freeze_enemies(5.0)
            .Repair => self.repair((self.max_health * 3 + 9) / 10)
            .Credits => {
                let value = ((1.0 * self.mods.credit) + 0.99) as i32
                self.credits += value
                self.popup(add(self.player, V2 { y: -20.0 }), .Credits(value: value))
            }
            .Bundle => {
                let value = ((20.0 * self.mods.credit) + 0.5) as i32
                self.credits += value
                self.popup(add(self.player, V2 { y: -20.0 }), .Credits(value: value))
            }
            .Cache => self.open_cache()

    pub fn tick(mut self: Self, input: Controls, dt: f64):
        self.effects(dt)
        // Aim is sampled even during hit-stop; simulation time alone pauses.
        if self.launch.ship.can_aim() and length2(input.aim) > 0.01: self.aim = direction(input.aim)
        if self.phase == .Boost:
            if self.cache_reveal > 0.0: self.cache_reveal = limit(self.cache_reveal - dt, 0.0, 1.0)
            return
        if self.freeze > 0.0:
            self.freeze = limit(self.freeze - dt, 0.0, 1.0)
            return
        if self.phase == .Over: return
        // dt is one step (STEP) or zero: a zero tick settles without time passing.
        if dt > 0.0: self.steps += 1
        self.elapsed = self.steps as f64 / STEPS_PER_SECOND as f64
        // The best-time marker: crossing it is called out once.
        if not self.best_crossed and self.launch.best_time > 0.0 and self.elapsed >= self.launch.best_time:
            self.best_crossed = true
            self.best_event = true
            self.best_flare = 2.0
            self.show(.NewBest, 2.0)
        self.invulnerable = limit(self.invulnerable - dt, 0.0, 5.0)
        if self.launch.ship == .Phase:
            self.phase_timer -= dt
            if self.phase_timer <= 0.0:
                // The rhythm slows as the Phase levels: its late game fades.
                self.phase_timer += PHASE_PERIOD + 0.45 * self.level as f64
                if self.invulnerable < PHASE_LENGTH: self.invulnerable = PHASE_LENGTH
        self.enemies_frozen = limit(self.enemies_frozen - dt, 0.0, 5.0)
        self.breather = limit(self.breather - dt, 0.0, 10.0)
        self.combo_timer -= dt
        if self.combo_timer <= 0.0 and self.combo > 0:
            self.combo = 0
        if self.mods.regen > 0.0 and self.health < self.max_health:
            self.regen_bank += self.mods.regen * dt
            if self.regen_bank >= 1.0:
                self.regen_bank -= 1.0
                self.health += 1
        let speed = self.rules.player_speed * self.mods.speed
        self.player = add(self.player, scale(movement(input.motion), speed * dt))
        self.player = self.clamp_to_arena(self.player, 14.0)
        self.follow(dt)
        self.fire_weapons(input.motion, dt)
        self.step_timeline(dt)
        self.rebuild_grid()
        if self.uses_paths:
            self.flow_timer -= dt
            if self.flow_timer <= 0.0:
                self.flow_timer = 0.25
                self.rebuild_flow()
        self.step_enemies(dt)
        // Enemies moved, died, and were eaten: the grid is rebuilt for bullets.
        // Bullet kills swap-remove, so the walk below also skips any index
        // past the live count.
        self.rebuild_grid()
        self.step_bullets(dt)
        self.step_fields(dt)
        // Contact.
        for e in 0..self.enemy_count:
            let enemy: Enemy = self.enemies[e]
            if enemy.age < self.rules.spawn_grace: continue
            let reach = self.rules.contact_radius + (enemy.kind.radius() - 14.0) * enemy.size
            if length2(sub(enemy.pos, self.player)) < reach * reach:
                self.hurt(enemy.kind, enemy.elite, self.contact(enemy.kind))
                break
        if self.phase == .Running and self.health > 0 and (self.pending_levels > 0 or self.pending_cache_items > 0): self.resume()

impl Copy for V2
impl Copy for Enemy
impl Copy for Bullet
impl Copy for Core
impl Copy for Pickup
impl Copy for Beacon
impl Copy for Mine
impl Copy for Beam
impl Copy for ArcBolt
impl Copy for Shockwave
impl Copy for Particle
impl Copy for Pulse
impl Copy for Popup
impl Copy for Banner
impl Copy for Controls
