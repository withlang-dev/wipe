// Weapons, passives, merge recipes, and the run's build. Pure data and pure
// functions: the simulation asks for stats, the menus ask for names.

// Eight launch weapons, eight evolutions, four unions.
pub enum Weapon {
    | Cannon | Orbit | Nova | Seeker | Lance | Mines | Arc | Shard
    | Tether | GravityWell | Drone | Lob
    | Flak | Turret | Sweep | TeslaField | Boomerang | Shockwave | Satellite | Repulsor
    | Railgun | Corona | Supernova | Swarm | Pike | Minefield | Storm | Shatter
    | LongTether | Singularity | TwinDrones | Barrage
    | Shrapnel | Battery | Lighthouse | StormCage | TwinReturn | Tremor | Constellation | Bastion
    | Tracer | Pulsar | Grid | Refractor | WellBurst | Net
}
impl Copy for Weapon
impl Eq for Weapon

// Twenty base weapons, their twenty evolutions, six unions (progression-matrix §1):
// base 0-19, evolutions 20-39, unions from 40.
pub const WEAPON_COUNT: i32 = 46
pub const BASE_WEAPON_COUNT: i32 = 20
// Five levels to a maxed weapon: a merge is six to eleven picks, reachable
// in most runs that aim for it and not in every run.
pub const MAX_WEAPON_LEVEL: i32 = 5
// The stat curves were written for eight levels; level V reads curve VIII.
pub const CURVE_TOP: i32 = 8

pub fn weapon_at(index: i32) -> Weapon:
    match index:
        0 => .Cannon
        1 => .Orbit
        2 => .Nova
        3 => .Seeker
        4 => .Lance
        5 => .Mines
        6 => .Arc
        7 => .Shard
        8 => .Tether
        9 => .GravityWell
        10 => .Drone
        11 => .Lob
        12 => .Flak
        13 => .Turret
        14 => .Sweep
        15 => .TeslaField
        16 => .Boomerang
        17 => .Shockwave
        18 => .Satellite
        19 => .Repulsor
        20 => .Railgun
        21 => .Corona
        22 => .Supernova
        23 => .Swarm
        24 => .Pike
        25 => .Minefield
        26 => .Storm
        27 => .Shatter
        28 => .LongTether
        29 => .Singularity
        30 => .TwinDrones
        31 => .Barrage
        32 => .Shrapnel
        33 => .Battery
        34 => .Lighthouse
        35 => .StormCage
        36 => .TwinReturn
        37 => .Tremor
        38 => .Constellation
        39 => .Bastion
        40 => .Tracer
        41 => .Pulsar
        42 => .Grid
        43 => .Refractor
        44 => .WellBurst
        _ => .Net

// How a weapon fires. Merged weapons reuse a family with multipliers and
// flags, so one firing routine per family covers twenty weapons.
pub enum Family { | Aimed | Orbiting | Ring | Homing | Beam | Dropped | Chain | Bouncing | Tether | Field | Drone | Lobbed | Cone | Turret | Sweep | Tesla | Return | Shock | Satellite | Repulsor }
impl Copy for Family
impl Eq for Family

extend Weapon:
    pub fn index(self: &Self) -> i32:
        match self:
            .Cannon => 0
            .Orbit => 1
            .Nova => 2
            .Seeker => 3
            .Lance => 4
            .Mines => 5
            .Arc => 6
            .Shard => 7
            .Tether => 8
            .GravityWell => 9
            .Drone => 10
            .Lob => 11
            .Flak => 12
            .Turret => 13
            .Sweep => 14
            .TeslaField => 15
            .Boomerang => 16
            .Shockwave => 17
            .Satellite => 18
            .Repulsor => 19
            .Railgun => 20
            .Corona => 21
            .Supernova => 22
            .Swarm => 23
            .Pike => 24
            .Minefield => 25
            .Storm => 26
            .Shatter => 27
            .LongTether => 28
            .Singularity => 29
            .TwinDrones => 30
            .Barrage => 31
            .Shrapnel => 32
            .Battery => 33
            .Lighthouse => 34
            .StormCage => 35
            .TwinReturn => 36
            .Tremor => 37
            .Constellation => 38
            .Bastion => 39
            .Tracer => 40
            .Pulsar => 41
            .Grid => 42
            .Refractor => 43
            .WellBurst => 44
            .Net => 45

    pub fn name(self: &Self) -> str:
        match self:
            .Cannon => "Cannon"
            .Orbit => "Orbit"
            .Nova => "Nova"
            .Seeker => "Seeker"
            .Lance => "Lance"
            .Mines => "Mines"
            .Arc => "Arc"
            .Shard => "Shard"
            .Tether => "Tether"
            .GravityWell => "Gravity Well"
            .Drone => "Drone"
            .Lob => "Lob"
            .Flak => "Flak"
            .Turret => "Turret"
            .Sweep => "Sweep"
            .TeslaField => "Tesla Field"
            .Boomerang => "Boomerang"
            .Shockwave => "Shockwave"
            .Satellite => "Satellite"
            .Repulsor => "Repulsor"
            .Railgun => "Railgun"
            .Corona => "Corona"
            .Supernova => "Supernova"
            .Swarm => "Swarm"
            .Pike => "Pike"
            .Minefield => "Minefield"
            .Storm => "Storm"
            .Shatter => "Shatter"
            .LongTether => "Long Tether"
            .Singularity => "Singularity"
            .TwinDrones => "Twin Drones"
            .Barrage => "Barrage"
            .Shrapnel => "Shrapnel"
            .Battery => "Battery"
            .Lighthouse => "Lighthouse"
            .StormCage => "Storm Cage"
            .TwinReturn => "Twin Return"
            .Tremor => "Tremor"
            .Constellation => "Constellation"
            .Bastion => "Bastion"
            .Tracer => "Tracer"
            .Pulsar => "Pulsar"
            .Grid => "Grid"
            .Refractor => "Refractor"
            .WellBurst => "Well Burst"
            .Net => "Net"

    pub fn describe(self: &Self) -> str:
        match self:
            .Cannon => "Aimed bolts. The one weapon you can aim."
            .Orbit => "Blades circle the ship."
            .Nova => "A ring burst around the ship."
            .Seeker => "Homing bolts at the nearest enemy."
            .Lance => "Piercing beams forward and back along the movement."
            .Mines => "A proximity mine where the ship is, every 3 s, never twice in one place. Area widens it; Projectiles arm more at once."
            .Arc => "Lightning from the ship strikes a random enemy each second, and anything in its path. More bolts, then chains, as it levels."
            .Shard => "Fragments that ricochet off the arena walls."
            .Tether => "A blade on a chain. Turn and it swings wide; the harder the turn, the harder it hits."
            .GravityWell => "A well where you aim: it pulls the swarm in and crushes what reaches the middle."
            .Drone => "A wingman that shoots whatever is not in front of you."
            .Lob => "A shell thrown along the aim, a fixed distance out, bursting where it lands. Nothing closer is touched."
            .Flak => "A short, wide cone of fragments. Close in and everything in front of you is shredded."
            .Turret => "An emplacement dropped where the ship is, firing at the nearest enemy for a while. Place it well."
            .Sweep => "A beam that turns slowly around the ship, burning everything it crosses."
            .TeslaField => "A constant field: everything near the ship is shocked, twice a second."
            .Boomerang => "Out along the aim and back along the same line, hitting twice."
            .Shockwave => "A ring that shoves the swarm back and marks it: what it touched takes more damage for a while."
            .Satellite => "A body on a slow orbit that catches hostile fire and breaks what it touches."
            .Repulsor => "Now and then, a zone around the ship that nothing can hold position in."
            .Railgun => "Cannon evolved: three heavy bolts that pierce three."
            .Corona => "Orbit evolved: a wide, dense ring of blades."
            .Supernova => "Nova evolved: a vast ring, twice as often."
            .Swarm => "Seeker evolved: a cloud of fast homing bolts."
            .Pike => "Lance evolved: a longer beam that pierces far deeper."
            .Minefield => "Mines evolved: a dense field that chain-detonates."
            .Storm => "Arc evolved: a storm of bolts with long chains."
            .Shatter => "Shard evolved: every bounce splits the fragment."
            .LongTether => "Tether evolved: a longer chain, a second blade halfway along it."
            .Singularity => "Gravity Well evolved: wider, longer, and it does not let go."
            .TwinDrones => "Drone evolved: two wingmen with chaining beams."
            .Barrage => "Lob evolved: three shells a volley, bigger bursts."
            .Shrapnel => "Flak evolved: more fragments, and they pierce."
            .Battery => "Turret evolved: four emplacements, faster fire."
            .Lighthouse => "Sweep evolved: two beams, opposite, turning faster."
            .StormCage => "Tesla Field evolved: a wider field whose shocks chain."
            .TwinReturn => "Boomerang evolved: two, out to each side and back."
            .Tremor => "Shockwave evolved: a wider ring, a harder shove, a longer mark."
            .Constellation => "Satellite evolved: three bodies on a wider orbit."
            .Bastion => "Repulsor evolved: a wider zone that lasts, and bites."
            .Tracer => "Cannon and Seeker: aimed bolts that hunt."
            .Pulsar => "Orbit and Nova: blades that burst as they turn."
            .Grid => "Mines and Arc: detonations that chain lightning."
            .Refractor => "Lance and Shard: a deep beam that shatters where it ends."
            .WellBurst => "Gravity Well and Nova: a well that gathers the swarm, then bursts."
            .Net => "Drone and Turret: three emplacements whose bolts chain lightning."

    pub fn family(self: &Self) -> Family:
        match self:
            .Cannon => .Aimed
            .Railgun => .Aimed
            .Tracer => .Aimed
            .Orbit => .Orbiting
            .Corona => .Orbiting
            .Pulsar => .Orbiting
            .Nova => .Ring
            .Supernova => .Ring
            .Seeker => .Homing
            .Swarm => .Homing
            .Lance => .Beam
            .Pike => .Beam
            .Refractor => .Beam
            .Mines => .Dropped
            .Minefield => .Dropped
            .Grid => .Dropped
            .Arc => .Chain
            .Storm => .Chain
            .Shard => .Bouncing
            .Shatter => .Bouncing
            .Tether => .Tether
            .LongTether => .Tether
            .GravityWell => .Field
            .Singularity => .Field
            .WellBurst => .Field
            .Drone => .Drone
            .TwinDrones => .Drone
            .Lob => .Lobbed
            .Barrage => .Lobbed
            .Flak => .Cone
            .Shrapnel => .Cone
            .Turret => .Turret
            .Battery => .Turret
            .Net => .Turret
            .Sweep => .Sweep
            .Lighthouse => .Sweep
            .TeslaField => .Tesla
            .StormCage => .Tesla
            .Boomerang => .Return
            .TwinReturn => .Return
            .Shockwave => .Shock
            .Tremor => .Shock
            .Satellite => .Satellite
            .Constellation => .Satellite
            .Repulsor => .Repulsor
            .Bastion => .Repulsor

    pub fn is_merged(self: &Self) -> bool: self.index() >= BASE_WEAPON_COUNT

    // Weapons that can be offered as new picks. Merged weapons only arrive
    // through their recipe.
    pub fn is_base(self: &Self) -> bool: self.index() < BASE_WEAPON_COUNT

// Fourteen passives: eight at launch, six unlockable.
pub enum Passive {
    | Damage | FireRate | Count | Area | ProjSpeed | Magnet | Speed | Health
    | Cooldown | Armor | Luck | Credit | Rebound | Overclock | Duration | Pierce | Failsafe
}
impl Copy for Passive
impl Eq for Passive

pub const PASSIVE_COUNT: i32 = 17
pub const MAX_PASSIVE_LEVEL: i32 = 5

pub fn passive_at(index: i32) -> Passive:
    match index:
        0 => .Damage
        1 => .FireRate
        2 => .Count
        3 => .Area
        4 => .ProjSpeed
        5 => .Magnet
        6 => .Speed
        7 => .Health
        8 => .Cooldown
        9 => .Armor
        10 => .Luck
        11 => .Credit
        12 => .Rebound
        13 => .Overclock
        14 => .Duration
        15 => .Pierce
        _ => .Failsafe

extend Passive:
    pub fn index(self: &Self) -> i32:
        match self:
            .Damage => 0
            .FireRate => 1
            .Count => 2
            .Area => 3
            .ProjSpeed => 4
            .Magnet => 5
            .Speed => 6
            .Health => 7
            .Cooldown => 8
            .Armor => 9
            .Luck => 10
            .Credit => 11
            .Rebound => 12
            .Overclock => 13
            .Duration => 14
            .Pierce => 15
            .Failsafe => 16

    pub fn name(self: &Self) -> str:
        match self:
            .Damage => "Damage"
            .FireRate => "Fire rate"
            .Count => "Projectiles"
            .Area => "Area"
            .ProjSpeed => "Velocity"
            .Magnet => "Magnet"
            .Speed => "Thrusters"
            .Health => "Hull"
            .Cooldown => "Cooldown"
            .Armor => "Armor"
            .Luck => "Luck"
            .Credit => "Salvage"
            .Rebound => "Rebound"
            .Overclock => "Overclock"
            .Duration => "Duration"
            .Pierce => "Pierce"
            .Failsafe => "Failsafe"

    // The delta of one more level, in plain numbers.
    pub fn describe(self: &Self) -> str:
        match self:
            .Damage => "+15% damage"
            .FireRate => "-8% cannon interval"
            .Count => "+1 projectile every other level"
            .Area => "+12% area and radius"
            .ProjSpeed => "+12% projectile speed"
            .Magnet => "+25% core pull radius"
            .Speed => "+8% move speed"
            .Health => "+2 max health, repair 1 health every 20 s"
            .Cooldown => "-6% every weapon's cooldown"
            .Armor => "ignore 1 more damage per hit"
            .Luck => "+10% cache size and a fourth card at III"
            .Credit => "+15% credits"
            .Rebound => "projectiles bounce off walls once more"
            .Overclock => "+10% enemies, +10% XP and credits"
            .Duration => "+12% to how long wells and shells last, and how far a shell flies"
            .Pierce => "every bolt passes through 1 more enemy"
            .Failsafe => "one revival a run: at I with 20% hull, more hull and grace with each level"

// A merge recipe: weapons at max, key passive held at any level.
pub type Recipe { result: Weapon = .Railgun, first: Weapon = .Cannon, second: Option[Weapon] = None, key: Passive = .FireRate }
impl Copy for Recipe

pub const RECIPE_COUNT: i32 = 26

pub fn recipes() -> [Recipe; 26]:
    [
        Recipe { result: .Railgun, first: .Cannon, key: .FireRate },
        Recipe { result: .Corona, first: .Orbit, key: .Area },
        Recipe { result: .Supernova, first: .Nova, key: .Health },
        Recipe { result: .Swarm, first: .Seeker, key: .ProjSpeed },
        Recipe { result: .Pike, first: .Lance, key: .Damage },
        Recipe { result: .Minefield, first: .Mines, key: .Cooldown },
        Recipe { result: .Storm, first: .Arc, key: .Count },
        Recipe { result: .Shatter, first: .Shard, key: .Speed },
        Recipe { result: .Tracer, first: .Cannon, second: Some(.Seeker), key: .Magnet },
        Recipe { result: .Pulsar, first: .Orbit, second: Some(.Nova), key: .Area },
        Recipe { result: .Grid, first: .Mines, second: Some(.Arc), key: .Cooldown },
        Recipe { result: .Refractor, first: .Lance, second: Some(.Shard), key: .ProjSpeed },
        Recipe { result: .LongTether, first: .Tether, key: .Duration },
        Recipe { result: .Singularity, first: .GravityWell, key: .Magnet },
        Recipe { result: .TwinDrones, first: .Drone, key: .Count },
        Recipe { result: .Barrage, first: .Lob, key: .Area },
        Recipe { result: .WellBurst, first: .GravityWell, second: Some(.Nova), key: .Area },
        Recipe { result: .Shrapnel, first: .Flak, key: .Pierce },
        Recipe { result: .Battery, first: .Turret, key: .Duration },
        Recipe { result: .Lighthouse, first: .Sweep, key: .Rebound },
        Recipe { result: .StormCage, first: .TeslaField, key: .Cooldown },
        Recipe { result: .TwinReturn, first: .Boomerang, key: .ProjSpeed },
        Recipe { result: .Tremor, first: .Shockwave, key: .Armor },
        Recipe { result: .Constellation, first: .Satellite, key: .Luck },
        Recipe { result: .Bastion, first: .Repulsor, key: .Health },
        Recipe { result: .Net, first: .Drone, second: Some(.Turret), key: .Credit },
    ]

pub fn recipe_for(result: Weapon) -> Option[Recipe]:
    for r in recipes():
        if r.result == result: return Some(r)
    None

// The mine field: eight armed at once, and Projectiles add up to four.
pub const MINE_BASE_CAP: i32 = 8
pub const MINE_CAP_BONUS: i32 = 4
// A mine's trigger reach, as a share of its blast radius.
pub const MINE_TRIGGER: f64 = 0.45

// Every stat multiplier the build applies, computed once per change.
pub type Mods {
    damage: f64 = 1.0, cooldown: f64 = 1.0, cannon_rate: f64 = 1.0,
    count: i32 = 0, area: f64 = 1.0, proj_speed: f64 = 1.0,
    magnet: f64 = 1.0, speed: f64 = 1.0, max_health: i32 = 10,
    armor: i32 = 0, luck: f64 = 0.0, credit: f64 = 1.0,
    rebound: i32 = 0, overclock: f64 = 0.0, xp: f64 = 1.0,
    regen: f64 = 0.0, invuln_bonus: f64 = 0.0,
    duration: f64 = 1.0,
    // Pierce adds to every bolt; Failsafe is the level of the one revival (0: none).
    pierce: i32 = 0, failsafe: i32 = 0,
}
impl Copy for Mods

// The stats one weapon fires with this tick.
pub type WeaponStats {
    cooldown: f64 = 1.0, damage: i32 = 1, count: i32 = 1, speed: f64 = 900.0,
    radius: f64 = 100.0, pierce: i32 = 0, bounces: i32 = 0, lifetime: f64 = 1.6,
    chain: i32 = 3, homing: bool = false, splits: bool = false, chains_on_hit: bool = false,
    ring_on_orbit: bool = false, shatters: bool = false, max_active: i32 = 6,
    // Fields: the pull in pixels a second, and a Nova ring when the well ends.
    pull: f64 = 0.0, burst_on_end: bool = false,
    // Drones: how many wingmen fly.
    drones: i32 = 1,
    // A fan's spread between bolts (radians); a ring's shove and its mark.
    spread: f64 = 0.09, push: f64 = 0.0, mark: f64 = 0.0,
}
impl Copy for WeaponStats

fn step(level: i32, every: i32, from: i32) -> i32:
    if level < from: 0 else: (level - from) / every + 1

pub fn weapon_stats(weapon: Weapon, merged_level: i32, mods: Mods) -> WeaponStats:
    // A merged weapon starts from its components at their maximum and grows
    // from there: merging must never make a build weaker.
    let curve = 1 + ((merged_level - 1) * (CURVE_TOP - 1) + (MAX_WEAPON_LEVEL - 2)) / (MAX_WEAPON_LEVEL - 1)
    // A merge is final: fixed stats two steps past its components' maximum.
    let level = if weapon.is_merged(): CURVE_TOP + 2 else: curve
    let l = level as f64
    var s = WeaponStats {}
    // Every family's damage grows with its level so a weapon taken at
    // minute two still matters at minute twelve; single-target families hit
    // harder per shot than area families, which hit many.
    match weapon.family():
        .Aimed => {
            // A modest start that grows: at level one the Cannon cannot keep up
            // with the opening swarm alone.
            s.cooldown = 1.0 / (4.5 * (1.0 + (l - 1.0) * 0.12))
            // Single-target damage against enemies that toughen from minute
            // two: a third more than the area weapons' curve, so aiming pays.
            s.damage = 3 + level * 2 / 3
            s.count = 1 + step(level, 2, 3)
            s.speed = 940.0
            s.lifetime = 1.6
        }
        .Orbiting => {
            s.cooldown = 0.25
            // One blade at level I, one more each level: five at V.
            s.count = if weapon.is_merged(): MAX_WEAPON_LEVEL else: merged_level
            s.radius = 75.0 + l * 6.0
            s.damage = 3 + level / 2
        }
        .Ring => {
            // Rings strike everything they cross, so they pulse slowly.
            s.cooldown = (2.6 - (l - 1.0) * 0.14) * 1.8
            s.radius = 130.0 + l * 12.0
            s.damage = 1 + level / 2
        }
        .Homing => {
            s.cooldown = 0.6 - (l - 1.0) * 0.03
            s.count = 2 + step(level, 2, 3)
            s.speed = 620.0
            s.damage = 6 + level * 2
            s.lifetime = 2.4
            s.homing = true
        }
        .Beam => {
            s.cooldown = 0.55 - (l - 1.0) * 0.025
            s.radius = 420.0 + l * 30.0
            // Two beams, forward and back, so each hits for less; a third more
            // than the area curve, as the Cannon.
            s.damage = 3 + level * 2 / 3
            s.pierce = 2 + level / 2
        }
        .Dropped => {
            // One every three seconds, faster with level; Fire rate and
            // Cooldown shorten it below. The field is capped, and
            // Projectiles raise the cap, never the rate (progression-plan
            // §5.2); the trigger ring is part of the blast radius.
            s.cooldown = 3.0 - (l - 1.0) * 0.15
            s.radius = 85.0 + l * 7.0
            s.damage = 3 + level
            s.max_active = MINE_BASE_CAP + (if mods.count > MINE_CAP_BONUS: MINE_CAP_BONUS else: mods.count)
        }
        .Tether => {
            // A blade on a chain: radius is the chain's length, cooldown how
            // often one enemy can be struck by it. Damage grows with the
            // blade's speed in game.w, so a committed turn hits hardest.
            s.cooldown = 0.22
            s.radius = 70.0 + l * 5.0
            s.damage = 4 + level * 2 / 3
            s.count = 1
        }
        .Field => {
            // A well where the ship aims, every few seconds, for a few
            // seconds: the pull in pixels a second, the crush at the middle.
            s.cooldown = 4.2 - (l - 1.0) * 0.2
            s.radius = 150.0 + l * 10.0
            s.lifetime = 3.0
            s.pull = 240.0 + l * 20.0
            s.damage = 2 + level / 2
        }
        .Drone => {
            // One system that escalates: a bolt; a faster bolt; a burst;
            // piercing; a short chaining beam at V.
            let lv = if weapon.is_merged(): MAX_WEAPON_LEVEL else: merged_level
            let rate = [0.55, 0.45, 0.4, 0.35, 0.3]
            let bolts = [1, 2, 3, 3, 4]
            let pierce = [0, 0, 0, 2, 2]
            let chain = [0, 0, 0, 0, 1]
            s.cooldown = rate[lv - 1]
            s.count = bolts[lv - 1]
            s.pierce = pierce[lv - 1]
            s.chain = chain[lv - 1]
            s.damage = 3 + level * 2 / 3
            s.speed = 820.0
            s.lifetime = 1.1
            s.drones = 1
        }
        .Lobbed => {
            // A shell to a fixed distance along the aim, bursting there:
            // lifetime is range over speed, radius the burst. Nothing nearer
            // than the range is touched.
            s.cooldown = 1.7 - (l - 1.0) * 0.08
            s.speed = 520.0
            s.lifetime = (170.0 + l * 22.0) / 520.0
            s.radius = 90.0 + l * 8.0
            s.damage = 4 + level
            s.count = 1
        }
        .Cone => {
            // Flak: a wide, short fan. Close in and all of it lands.
            s.cooldown = 0.85 - (l - 1.0) * 0.05
            s.count = 5 + step(level, 2, 2)
            s.spread = 0.2
            s.speed = 760.0
            s.lifetime = 0.24
            s.damage = 4 + level * 2 / 3
            s.pierce = 1
        }
        .Turret => {
            // An emplacement where the ship is, for a while; it fires at the
            // nearest enemy. radius is its reach, max_active how many stand.
            s.cooldown = 6.0 - (l - 1.0) * 0.25
            s.lifetime = 8.0
            s.radius = 480.0
            s.damage = 3 + level * 2 / 3
            s.speed = 900.0
            s.max_active = 2
            s.chain = 0
            // Each emplacement fires a three-bolt spread four times a second.
            s.count = 3
            s.pierce = 1
        }
        .Sweep => {
            // A beam turning around the ship: radius its length, speed its
            // turn in radians a second, damage per crossing.
            s.cooldown = 0.14
            s.radius = 300.0 + l * 20.0
            s.speed = 1.5 + (l - 1.0) * 0.08
            s.damage = 2 + level / 2
            s.pierce = 24
            s.count = 1
        }
        .Tesla => {
            // A constant field around the ship: everything inside is shocked
            // twice a second.
            s.cooldown = 0.5
            s.radius = 120.0 + l * 10.0
            s.damage = 2 + level / 2
        }
        .Return => {
            // Out along the aim for half its life, back along the same line
            // for the other half, hitting everything once each way.
            s.cooldown = 1.2 - (l - 1.0) * 0.06
            s.speed = 700.0
            s.lifetime = 1.2
            s.damage = 6 + level
            s.pierce = 40
            s.count = 1
        }
        .Shock => {
            // A ring that shoves and marks: what it touched takes half again
            // the damage for a while.
            s.cooldown = 4.5 - (l - 1.0) * 0.15
            s.radius = 200.0 + l * 12.0
            s.damage = 1 + level / 3
            s.push = 70.0
            s.mark = 2.5
        }
        .Satellite => {
            // Bodies on a slow orbit: count how many, radius the orbit.
            s.cooldown = 0.25
            s.radius = 100.0 + l * 4.0
            s.damage = 8 + level * 3 / 2
            s.count = 1
        }
        .Repulsor => {
            // Now and then, a zone nothing holds position in: lifetime how
            // long, radius how wide, push how hard, in pixels a second.
            s.cooldown = 6.0 - (l - 1.0) * 0.2
            s.lifetime = 2.5
            s.radius = 160.0 + l * 8.0
            s.push = 220.0
            s.damage = 1 + level / 3
        }
        .Chain => {
            // Bolts and chains by level, as designed: I one bolt; II two;
            // III two, each chaining once; IV two, chaining twice; V three,
            // chaining twice. A merge (Storm) is its own row below.
            let raw = if weapon.is_merged(): MAX_WEAPON_LEVEL else: merged_level
            let lv = if raw < 1: 1 else if raw > MAX_WEAPON_LEVEL: MAX_WEAPON_LEVEL else: raw
            let bolts = [1, 2, 2, 2, 3]
            let chains = [0, 0, 1, 2, 2]
            s.count = bolts[lv - 1]
            s.chain = chains[lv - 1]
            s.cooldown = 1.0
            s.radius = 230.0
            s.damage = 4 + level
        }
        .Bouncing => {
            s.cooldown = 0.55 - (l - 1.0) * 0.03
            s.count = 2 + step(level, 3, 3)
            s.bounces = 2 + step(level, 4, 4)
            s.speed = 640.0
            s.damage = 3 + level / 2
            s.pierce = 1 + level / 4
            s.lifetime = 2.6
        }
    // Merged weapons are the family with its numbers pushed and a flag. A
    // merge is roughly double its maxed components, not an order of
    // magnitude: the Railgun pierced everything at triple damage and
    // out-killed every other weapon five to one.
    match weapon:
        .Railgun => { s.count = 3; s.pierce = 3; s.damage = s.damage * 3 / 2; s.speed *= 1.3 }
        .Corona => { s.count += 4; s.radius *= 1.4; s.damage *= 2 }
        .Supernova => { s.damage = s.damage * 5 / 4; s.cooldown *= 0.95 }
        .Swarm => { s.count = s.count * 3 / 2 + 1; s.damage = s.damage * 3 / 2; s.cooldown *= 0.8; s.speed *= 1.3 }
        .Pike => { s.pierce += 6; s.damage = s.damage * 3 / 2; s.radius *= 1.4 }
        .Minefield => { s.cooldown *= 0.7; s.damage = s.damage * 3 / 2; s.max_active += 4; s.chains_on_hit = true }
        .Storm => { s.chain += 2; s.radius *= 1.3; s.damage = s.damage * 5 / 4; s.cooldown *= 0.85 }
        .Shatter => { s.bounces += 2; s.damage = s.damage * 3 / 2; s.pierce += 1; s.splits = true }
        .Tracer => { s.homing = true; s.damage *= 2; s.count += 2 }
        .Pulsar => { s.count += 2; s.damage *= 2; s.ring_on_orbit = true }
        .Grid => { s.damage = s.damage * 3 / 2; s.max_active += 3; s.chains_on_hit = true }
        .Refractor => { s.pierce += 6; s.damage *= 2; s.shatters = true }
        .LongTether => { s.radius *= 1.4; s.count = 2; s.damage = s.damage * 3 / 2 }
        .Singularity => { s.radius *= 1.4; s.pull *= 1.5; s.lifetime *= 1.5; s.damage = s.damage * 3 / 2 }
        .TwinDrones => { s.drones = 2; s.chain = 2; s.damage = s.damage * 3 / 2 }
        .Barrage => { s.count = 3; s.radius *= 1.3; s.damage = s.damage * 3 / 2 }
        .WellBurst => { s.radius *= 1.2; s.pull *= 1.2; s.damage = s.damage * 5 / 4; s.burst_on_end = true }
        .Shrapnel => { s.count += 4; s.pierce += 2; s.damage = s.damage * 3 / 2 }
        .Battery => { s.max_active = 4; s.cooldown *= 0.7; s.lifetime *= 1.5; s.damage = s.damage * 3 / 2 }
        .Lighthouse => { s.count = 2; s.speed *= 1.5; s.damage = s.damage * 3 / 2 }
        .StormCage => { s.radius *= 1.5; s.damage = s.damage * 3 / 2; s.chain = 2 }
        .TwinReturn => { s.count = 2; s.damage = s.damage * 3 / 2 }
        .Tremor => { s.radius *= 1.4; s.push *= 2.0; s.mark = 4.0; s.damage *= 2 }
        .Constellation => { s.count = 3; s.radius *= 1.2; s.damage = s.damage * 3 / 2 }
        .Bastion => { s.lifetime *= 1.6; s.radius *= 1.3; s.push *= 1.3; s.damage *= 2 }
        .Net => { s.max_active = 3; s.chain = 2; s.lifetime *= 1.3; s.damage = s.damage * 3 / 2 }
        _ => ()
    // Passives and shop ranks apply on top.
    s.damage = ((s.damage as f64) * mods.damage + 0.5) as i32
    if s.damage < 1: s.damage = 1
    s.cooldown *= mods.cooldown
    if weapon.family() == .Aimed or weapon.family() == .Dropped: s.cooldown *= mods.cannon_rate
    if s.cooldown < 0.03: s.cooldown = 0.03
    // Lightning bolts are the Arc's level table, not projectiles: each carries
    // its chain, so the Projectiles passive would multiply the weapon.
    if weapon.family() == .Aimed or weapon.family() == .Homing or weapon.family() == .Bouncing or weapon.family() == .Orbiting or weapon.family() == .Cone or weapon.family() == .Return:
        s.count += mods.count
    // Pierce: every bolt passes through more.
    if weapon.family() == .Aimed or weapon.family() == .Homing or weapon.family() == .Bouncing or weapon.family() == .Cone or weapon.family() == .Drone or weapon.family() == .Turret:
        s.pierce += mods.pierce
    s.radius *= mods.area
    s.speed *= mods.proj_speed
    s.bounces += mods.rebound
    // Duration: how long a well, a shell or a bolt lasts; a thrown shell's
    // range is its life, so Duration reaches farther too.
    s.lifetime *= mods.duration
    s

// One weapon or passive slot. `level` zero means empty.
pub type WeaponSlot { weapon: Weapon = .Cannon, level: i32 = 0, timer: f64 = 0.0, phase: f64 = 0.0, seen: bool = false }
impl Copy for WeaponSlot
pub type PassiveSlot { passive: Passive = .Damage, level: i32 = 0 }
impl Copy for PassiveSlot

// Storage for slots; how many a run may fill is below.
pub const SLOT_COUNT: i32 = 6
// Four weapons and four passives: fewer, heavier choices.
pub const WEAPON_SLOTS: i32 = 4
pub const PASSIVE_SLOTS: i32 = 4

// What a boost card offers.
pub enum Pick { | NewWeapon(weapon: Weapon) | UpgradeWeapon(weapon: Weapon) | NewPassive(passive: Passive) | UpgradePassive(passive: Passive) | Merge(result: Weapon) }
impl Copy for Pick

pub type Offer { pick: Pick = .NewWeapon(weapon: .Cannon), unseen: bool = false }
impl Copy for Offer

extend Pick:
    pub fn title(self: &Self) -> str:
        match self:
            .NewWeapon(w) => w.name()
            .UpgradeWeapon(w) => w.name()
            .NewPassive(p) => p.name()
            .UpgradePassive(p) => p.name()
            .Merge(w) => w.name()
    pub fn is_merge(self: &Self) -> bool:
        match self:
            .Merge(_) => true
            _ => false

// The run's build: six weapon slots, six passive slots, and the banish list.
pub type Build {
    weapons: [WeaponSlot; 6] = [WeaponSlot {}; 6],
    passives: [PassiveSlot; 6] = [PassiveSlot {}; 6],
    weapon_slots: i32 = WEAPON_SLOTS,
    // No new weapons below this level (the Ghost).
    weapon_lock: i32 = 0,
    banished_weapons: [bool; 46] = [false; 46],
    banished_passives: [bool; 17] = [false; 17],
    // Weapons and passives this account may be offered.
    unlocked_weapons: [bool; 46] = [false; 46],
    unlocked_passives: [bool; 17] = [false; 17],
    forbidden_weapon: Option[Weapon] = None,
    merges_this_run: i32 = 0,
}
impl Copy for Build

extend Build:
    pub fn weapon_level(self: &Self, weapon: Weapon) -> i32:
        for s in self.weapons:
            if s.level > 0 and s.weapon == weapon: return s.level
        0
    pub fn passive_level(self: &Self, passive: Passive) -> i32:
        for s in self.passives:
            if s.level > 0 and s.passive == passive: return s.level
        0
    pub fn weapon_count(self: &Self) -> i32:
        var n = 0
        for s in self.weapons:
            if s.level > 0: n += 1
        n
    pub fn passive_count(self: &Self) -> i32:
        var n = 0
        for s in self.passives:
            if s.level > 0: n += 1
        n
    pub fn add_weapon(mut self: Self, weapon: Weapon):
        for i in 0..self.weapon_slots:
            if self.weapons[i].level == 0:
                self.weapons[i] = WeaponSlot { weapon, level: 1 }
                return
    pub fn upgrade_weapon(mut self: Self, weapon: Weapon):
        for i in 0..SLOT_COUNT:
            if self.weapons[i].level > 0 and self.weapons[i].weapon == weapon:
                self.weapons[i].level += 1
                return
    pub fn add_passive(mut self: Self, passive: Passive):
        for i in 0..SLOT_COUNT:
            if self.passives[i].level == 0:
                self.passives[i] = PassiveSlot { passive, level: 1 }
                return
    pub fn upgrade_passive(mut self: Self, passive: Passive):
        for i in 0..SLOT_COUNT:
            if self.passives[i].level > 0 and self.passives[i].passive == passive:
                self.passives[i].level += 1
                return
    fn remove_weapon(mut self: Self, weapon: Weapon):
        for i in 0..SLOT_COUNT:
            if self.weapons[i].level > 0 and self.weapons[i].weapon == weapon:
                self.weapons[i] = WeaponSlot {}
                return

    // A complete recipe whose result is not yet owned.
    pub fn recipe_ready(self: &Self, r: Recipe) -> bool:
        if self.weapon_level(r.result) > 0: return false
        if self.weapon_level(r.first) < MAX_WEAPON_LEVEL: return false
        if let Some(second) = r.second:
            if self.weapon_level(second) < MAX_WEAPON_LEVEL: return false
        self.passive_level(r.key) > 0

    pub fn ready_merges(self: &Self) -> List[Weapon]:
        var out = List.new()
        for r in recipes():
            if self.recipe_ready(r): out.push(r.result)
        out

    // Consume the components into the merged weapon, in the first component's slot.
    pub fn merge(mut self: Self, result: Weapon):
        let Some(r) = recipe_for(result) else return
        if let Some(second) = r.second: self.remove_weapon(second)
        for i in 0..SLOT_COUNT:
            if self.weapons[i].level > 0 and self.weapons[i].weapon == r.first:
                // Merges are final and read as fully leveled.
                self.weapons[i] = WeaponSlot { weapon: result, level: MAX_WEAPON_LEVEL }
                self.merges_this_run += 1
                return

    // The nearest incomplete recipe: the result and how far away it is, as
    // a line for the results screen. None when no recipe is half held.
    pub fn nearest_recipe(self: &Self) -> Option[(Weapon, i32)]:
        var best: Option[(Weapon, i32)] = None
        for r in recipes():
            if self.weapon_level(r.result) > 0: continue
            let first = self.weapon_level(r.first)
            if first == 0: continue
            var distance = MAX_WEAPON_LEVEL - first
            if let Some(second) = r.second:
                let s = self.weapon_level(second)
                if s == 0: continue
                distance += MAX_WEAPON_LEVEL - s
            if self.passive_level(r.key) == 0: distance += 1
            if distance == 0: continue
            let better = match best:
                Some((_, d)) => distance < d
                None => true
            if better: best = Some((r.result, distance))
        best

    pub fn apply(mut self: Self, pick: Pick):
        match pick:
            .NewWeapon(w) => self.add_weapon(w)
            .UpgradeWeapon(w) => self.upgrade_weapon(w)
            .NewPassive(p) => self.add_passive(p)
            .UpgradePassive(p) => self.upgrade_passive(p)
            .Merge(w) => self.merge(w)

    pub fn banish(mut self: Self, pick: Pick):
        match pick:
            .NewWeapon(w) => { self.banished_weapons[w.index()] = true }
            .UpgradeWeapon(w) => { self.banished_weapons[w.index()] = true }
            .NewPassive(p) => { self.banished_passives[p.index()] = true }
            .UpgradePassive(p) => { self.banished_passives[p.index()] = true }
            .Merge(_) => {}

    // Every legal pick, merges first. The caller shuffles and takes three.
    // True when a merge that consumed this weapon is in the build.
    pub fn merged_away(self: &Self, w: Weapon) -> bool:
        for r in recipes():
            if self.weapon_level(r.result) == 0: continue
            if r.first == w: return true
            if let Some(second) = r.second:
                if second == w: return true
        false

    // `level` is the run's: a ship may hold its new weapons back until one.
    pub fn candidates(self: &Self, run_level: i32 = 99) -> List[Pick]:
        var out: List[Pick] = List.new()
        for m in self.ready_merges(): out.push(.Merge(result: m))
        let free_weapon = self.weapon_count() < self.weapon_slots and run_level >= self.weapon_lock
        for i in 0..BASE_WEAPON_COUNT:
            let w = weapon_at(i)
            if self.banished_weapons[i] or not self.unlocked_weapons[i]: continue
            // A weapon that went into a merge is spent for the run.
            if self.merged_away(w): continue
            if let Some(f) = self.forbidden_weapon:
                if f == w: continue
            let level = self.weapon_level(w)
            if level == 0 and free_weapon: out.push(.NewWeapon(weapon: w))
            else if level > 0 and level < MAX_WEAPON_LEVEL: out.push(.UpgradeWeapon(weapon: w))
        // Merged weapons are final: never offered as upgrades.
        let free_passive = self.passive_count() < PASSIVE_SLOTS
        for i in 0..PASSIVE_COUNT:
            let p = passive_at(i)
            if self.banished_passives[i] or not self.unlocked_passives[i]: continue
            let level = self.passive_level(p)
            if level == 0 and free_passive: out.push(.NewPassive(passive: p))
            else if level > 0 and level < MAX_PASSIVE_LEVEL: out.push(.UpgradePassive(passive: p))
        out

    // Multipliers from passives alone; the caller adds ship and shop.
    pub fn passive_mods(self: &Self, base: Mods) -> Mods:
        var m = base
        for s in self.passives:
            if s.level == 0: continue
            let l = s.level as f64
            match s.passive:
                .Damage => { m.damage *= 1.0 + 0.15 * l }
                .FireRate => { m.cannon_rate *= 1.0 - 0.08 * l }
                .Count => { m.count += (s.level + 1) / 2 }
                .Area => { m.area *= 1.0 + 0.12 * l }
                .ProjSpeed => { m.proj_speed *= 1.0 + 0.12 * l }
                .Magnet => { m.magnet *= 1.0 + 0.25 * l }
                .Speed => { m.speed *= 1.0 + 0.08 * l }
                .Health => {
                    m.max_health += 2 * s.level
                    m.regen += 0.05 * l
                }
                .Cooldown => { m.cooldown *= 1.0 - 0.06 * l }
                .Armor => { m.armor += s.level }
                .Luck => { m.luck += 0.1 * l }
                .Credit => { m.credit *= 1.0 + 0.15 * l }
                .Rebound => { m.rebound += s.level }
                .Overclock => { m.overclock += 0.1 * l }
                .Duration => { m.duration *= 1.0 + 0.12 * l }
                .Pierce => { m.pierce += s.level }
                .Failsafe => { m.failsafe = s.level }
        m.xp *= 1.0 + m.overclock
        m.credit *= 1.0 + m.overclock
        m
