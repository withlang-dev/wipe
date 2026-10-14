use loadout
use tuning

// The roster. Each ship is a base weapon, one strength, one growth curve,
// one weakness, and one unlock condition, all stated in plain numbers.
pub enum Ship {
    | Claw | Dart | Hull | Prism | Halo | Needle | Sapper | Phase | Null
    | Lasher | Anchor | Carrier | Warden
    | Hawk | Volt | Mortar | Brace | Sentry | Lantern | Coil | Kestrel | Rampart | Orbital
    | Ghost | Glass | Mirror
}
impl Copy for Ship
impl Eq for Ship

// Twenty-five: nine authored originals, four authored newcomers, ten
// specialists that teach a weapon, two secrets (progression-matrix §4).
pub const SHIP_COUNT: i32 = 26

pub fn ship_at(index: i32) -> Ship:
    match index:
        0 => .Claw
        1 => .Dart
        2 => .Hull
        3 => .Prism
        4 => .Halo
        5 => .Needle
        6 => .Sapper
        7 => .Phase
        8 => .Null
        9 => .Lasher
        10 => .Anchor
        11 => .Carrier
        12 => .Warden
        13 => .Hawk
        14 => .Volt
        15 => .Mortar
        16 => .Brace
        17 => .Sentry
        18 => .Lantern
        19 => .Coil
        20 => .Kestrel
        21 => .Rampart
        22 => .Orbital
        23 => .Ghost
        24 => .Glass
        _ => .Mirror

// A run fact that unlocks something. Progress is read from the save.
pub enum Condition {
    | Start
    | Survive(seconds: i32)
    | SurviveWith(weapon: Weapon, seconds: i32)
    | HitsSurvived(count: i32)
    | BouncedKills(count: i32)
    | LifetimeCores(count: i32)
    | Combo(count: i32)
    | MergesInRun(count: i32)
    | ClearNoReboot
    | KillNull
    | Level(level: i32)
    | LifetimeKills(count: i32)
    | Elites(count: i32)
    | Caches(count: i32)
    | Banked(credits: i32)
    | HitsTaken(count: i32)
    | Clear
    | Bosses(count: i32)
    | Merges(count: i32)
    | HurryClear
    | Deaths(count: i32)
    // The derelict in a stage recovered (progression-plan §7).
    | Derelict(stage: Stage)
    // A stage cleared; and challenge stages cleared, lifetime.
    | ClearStage(stage: Stage)
    | ChallengeClears(count: i32)
}
impl Copy for Condition

// m:ss for a whole number of seconds.
pub fn clock(seconds: i32) -> str:
    let minutes = seconds / 60
    let secs = seconds % 60
    if secs < 10: f"{minutes}:0{secs}" else: f"{minutes}:{secs}"

extend Condition:
    pub fn describe(self: &Self) -> str:
        match self:
            .Start => "Available from the start"
            .Survive(s) => f"Survive {clock(s)}"
            .SurviveWith(w, s) => f"Survive {clock(s)} holding the {w.name()}"
            .HitsSurvived(n) => f"Take {n} hits in one run and survive"
            .BouncedKills(n) => f"Kill {n} enemies with bounced shards"
            .LifetimeCores(n) => f"Collect {n} cores, lifetime"
            .Combo(n) => f"Reach combo x{n}"
            .MergesInRun(n) => f"Complete {n} merges in one run"
            .ClearNoReboot => "Clear a 20-minute run without a reboot"
            .KillNull => "Face what ends the run, and end it first"
            .Level(l) => f"Reach level {l} in one run"
            .LifetimeKills(n) => f"Kill {n} enemies, lifetime"
            .Elites(n) => f"Kill {n} elites, lifetime"
            .Caches(n) => f"Open {n} caches, lifetime"
            .Banked(n) => f"Bank {n} credits, lifetime"
            .HitsTaken(n) => f"Take {n} hits, lifetime"
            .Clear => "Clear a 20-minute run"
            .Bosses(n) => f"Kill {n} bosses, lifetime"
            .Merges(n) => f"Complete {n} merges, lifetime"
            .HurryClear => "Clear a run in Hurry"
            .Deaths(n) => f"Lose {n} runs"
            .Derelict(stage) => f"Recover the derelict in the {stage.name()}"
            .ClearStage(stage) => f"Clear the {stage.name()}"
            .ChallengeClears(n) => f"Clear {n} challenge stages"

extend Ship:
    pub fn index(self: &Self) -> i32:
        match self:
            .Claw => 0
            .Dart => 1
            .Hull => 2
            .Prism => 3
            .Halo => 4
            .Needle => 5
            .Sapper => 6
            .Phase => 7
            .Null => 8
            .Lasher => 9
            .Anchor => 10
            .Carrier => 11
            .Warden => 12
            .Hawk => 13
            .Volt => 14
            .Mortar => 15
            .Brace => 16
            .Sentry => 17
            .Lantern => 18
            .Coil => 19
            .Kestrel => 20
            .Rampart => 21
            .Orbital => 22
            .Ghost => 23
            .Glass => 24
            .Mirror => 25

    pub fn name(self: &Self) -> str:
        match self:
            .Claw => "Claw"
            .Dart => "Dart"
            .Hull => "Hull"
            .Prism => "Prism"
            .Halo => "Halo"
            .Needle => "Needle"
            .Sapper => "Sapper"
            .Phase => "Phase"
            .Null => "Null"
            .Lasher => "Lasher"
            .Anchor => "Anchor"
            .Carrier => "Carrier"
            .Warden => "Warden"
            .Hawk => "Hawk"
            .Volt => "Volt"
            .Mortar => "Mortar"
            .Brace => "Brace"
            .Sentry => "Sentry"
            .Lantern => "Lantern"
            .Coil => "Coil"
            .Kestrel => "Kestrel"
            .Rampart => "Rampart"
            .Orbital => "Orbital"
            .Ghost => "Ghost"
            .Glass => "Glass"
            .Mirror => "Mirror"

    pub fn base_weapon(self: &Self) -> Weapon:
        match self:
            .Claw => .Cannon
            .Dart => .Seeker
            .Hull => .Nova
            .Prism => .Shard
            .Halo => .Orbit
            .Needle => .Lance
            .Sapper => .Mines
            .Phase => .Arc
            .Null => .Nova
            .Lasher => .Tether
            .Anchor => .GravityWell
            .Carrier => .Drone
            .Warden => .Repulsor
            .Hawk => .Seeker
            .Volt => .Arc
            .Mortar => .Lob
            .Brace => .Flak
            .Sentry => .Turret
            .Lantern => .Sweep
            .Coil => .TeslaField
            .Kestrel => .Boomerang
            .Rampart => .Shockwave
            .Orbital => .Satellite
            .Ghost => .Satellite
            .Glass => .Lob
            .Mirror => .Shard

    pub fn strength(self: &Self) -> str:
        match self:
            .Claw => "Balanced. +1 reroll per run"
            .Dart => "+25% move speed, +20% projectile speed, +1 seeker"
            .Hull => "Double max health, +1 armor, self-repair"
            .Prism => "+1 shard, three more bounces, +20% area"
            .Halo => "+60% magnet, +1 orbit blade, cores worth +25% XP"
            .Needle => "+35% damage, faster cooldowns, lance pierce doubled"
            .Sapper => "+50% area, faster cooldowns, mines chain-detonate"
            .Phase => "Phases out on a rhythm, +1 lightning bolt, invulnerable 3 s on level-up"
            .Null => "Starts at level 5 with three weapons at III, +30% credits"
            .Lasher => "+20% damage; the Tether's chain is a third longer"
            .Anchor => "Wells pull half again as hard and last longer; +2 max health"
            .Carrier => "Two drones from the start, +1 bolt each; +10% fire rate"
            .Warden => "Self-repair, +1 armor; the Repulsor's zone lasts half again"
            .Hawk => "+25% projectile speed, +1 seeker"
            .Volt => "+15% damage; lightning strikes more often"
            .Mortar => "Shells fly +20% farther; +10% area"
            .Brace => "+1 fragment every fan; +10% damage"
            .Sentry => "Emplacements stand +30% longer"
            .Lantern => "Faster cooldowns; the beam turns quicker"
            .Coil => "+20% area; the field reaches farther"
            .Kestrel => "+20% projectile speed, +1 boomerang"
            .Rampart => "+1 armor; rings shove harder"
            .Orbital => "+2 max health; the orbit is wider"
            .Ghost => "Double damage once its weapons wake"
            .Glass => "Triple damage"
            .Mirror => "Every projectile is reflected once more; +15% damage"

    pub fn growth(self: &Self) -> str:
        match self:
            .Claw => "+1% damage per level"
            .Dart => "None: its edge is the opening"
            .Hull => "+1 max health per level, armor every 6"
            .Prism => "+1% area per level"
            .Halo => "+1 blade every 6 levels"
            .Needle => "+3% damage per level"
            .Sapper => "The cooldown edge fades after level 18"
            .Phase => "Its damage edge fades with level"
            .Null => "+1% credits per level"
            .Lasher => "+1% damage per level"
            .Anchor => "+1 max health every 5 levels"
            .Carrier => "+1% fire rate per level"
            .Warden => "+1 armor every 8 levels"
            .Hawk => "+1% projectile speed per level"
            .Volt => "+1% damage per level"
            .Mortar => "+1% range per level"
            .Brace => "+1% damage per level"
            .Sentry => "+1% emplacement life per level"
            .Lantern => "+1% cooldown per level"
            .Coil => "+1% area per level"
            .Kestrel => "+1% projectile speed per level"
            .Rampart => "+1% area per level"
            .Orbital => "+1 max health every 6 levels"
            .Ghost => "+2% damage per level"
            .Glass => "+1% damage per level"
            .Mirror => "+1% damage per level"

    pub fn weakness(self: &Self) -> str:
        match self:
            .Claw => "None"
            .Dart => "Half max health"
            .Hull => "-15% move speed"
            .Prism => "Weak first minute"
            .Halo => "Cannot take the Cannon"
            .Needle => "Cannot aim: no Cannon"
            .Sapper => "Only 3 weapon slots"
            .Phase => "Max health 1. Reboots do not work"
            .Null => "-25% XP gain. Cannot merge"
            .Lasher => "-15% move speed"
            .Anchor => "Held for a beat as each well is laid"
            .Carrier => "Cannot take the Cannon"
            .Warden => "-5% move speed, -10% damage"
            .Hawk => "-10% max health"
            .Volt => "-10% max health"
            .Mortar => "-10% move speed"
            .Brace => "-10% projectile speed"
            .Sentry => "-10% move speed"
            .Lantern => "-10% damage"
            .Coil => "-10% max health"
            .Kestrel => "-10% max health"
            .Rampart => "-10% move speed"
            .Orbital => "-10% damage"
            .Ghost => "No new weapons until level 8: passives only"
            .Glass => "Max health 1"
            .Mirror => "-10% move speed"

    pub fn condition(self: &Self) -> Condition:
        match self:
            .Claw => .Start
            .Dart => .Survive(seconds: 300)
            .Hull => .HitsSurvived(count: 20)
            .Prism => .BouncedKills(count: 200)
            .Halo => .LifetimeCores(count: 5000)
            .Needle => .Combo(count: 3000)
            .Sapper => .MergesInRun(count: 2)
            .Phase => .ClearNoReboot
            .Null => .KillNull
            .Lasher => .Derelict(stage: .Corridor)
            .Anchor => .Derelict(stage: .Shaft)
            .Carrier => .Derelict(stage: .Ring)
            .Warden => .HurryClear
            .Hawk => .Survive(seconds: 480)
            .Volt => .Elites(count: 5)
            .Mortar => .Survive(seconds: 720)
            .Brace => .SurviveWith(weapon: .Flak, seconds: 300)
            .Sentry => .Derelict(stage: .Cross)
            .Lantern => .Survive(seconds: 900)
            .Coil => .Bosses(count: 6)
            .Kestrel => .SurviveWith(weapon: .Boomerang, seconds: 300)
            .Rampart => .Clear
            .Orbital => .HitsSurvived(count: 30)
            .Ghost => .Deaths(count: 25)
            .Glass => .Derelict(stage: .Expanse)
            .Mirror => .ClearStage(stage: .Mirror)

    pub fn secret(self: &Self) -> bool: *self == .Null or *self == .Ghost or *self == .Glass or *self == .Mirror

    // The Ghost flies on passives alone until this level.
    pub fn weapon_lock_level(self: &Self) -> i32:
        match self:
            .Ghost => 8
            _ => 0

    pub fn weapon_slots(self: &Self) -> i32:
        match self:
            .Sapper => WEAPON_SLOTS - 1
            _ => WEAPON_SLOTS

    pub fn forbidden_weapon(self: &Self) -> Option[Weapon]:
        match self:
            .Halo => Some(.Cannon)
            .Needle => Some(.Cannon)
            .Carrier => Some(.Cannon)
            _ => None

    pub fn can_aim(self: &Self) -> bool: *self != .Needle
    pub fn can_merge(self: &Self) -> bool: *self != .Null
    pub fn reboots_work(self: &Self) -> bool: *self != .Phase
    pub fn starting_level(self: &Self) -> i32:
        match self:
            .Null => 5
            _ => 1
    pub fn extra_rerolls(self: &Self) -> i32:
        match self:
            .Claw => 1
            _ => 0

    // Strength and growth applied to the run's multipliers.
    pub fn apply(self: &Self, base: Mods, level: i32) -> Mods:
        var m = base
        let l = level as f64
        match self:
            .Claw => { m.damage *= 1.0 + 0.01 * l }
            .Dart => {
                m.speed *= 1.25
                m.proj_speed *= 1.2
                m.count += 1
                m.max_health = m.max_health / 2
            }
            .Hull => {
                // The late wall: health doubles and keeps growing, armor
                // thickens, and the hull slowly repairs itself.
                m.max_health = m.max_health * 2 + level * 3 / 2
                m.armor += 1 + level / 4
                m.regen += 0.6
                m.speed *= 0.9
            }
            .Prism => {
                // The middle game: an extra shard and two more bounces.
                m.rebound += 3
                m.count += 1
                m.damage *= 1.06
                m.area *= 1.2 * (1.0 + 0.01 * l)
            }
            .Halo => {
                m.magnet *= 1.6 * (1.0 + 0.02 * l)
                m.xp *= 1.25
                // One more blade now and one every eight levels: a slow
                // start that catches up.
                m.count += 1 + level / 5
                m.damage *= 1.15
            }
            .Needle => {
                // The late killer: damage compounds with every level, and
                // every weapon cycles faster.
                m.damage *= 1.35 * (1.0 + 0.025 * l)
                m.cooldown *= 0.66
            }
            .Sapper => {
                // The card promised +40% area; it was never applied.
                // Peaks early: the bonus fades as the run goes on.
                m.area *= 1.5
                m.cooldown *= 0.62 * (1.0 + 0.14 * clamp(l - 16.0, 0.0, 30.0))
                m.max_health += 3
            }
            .Phase => {
                m.max_health = 1
                m.invuln_bonus = 3.0 + 0.1 * (level / 5) as f64
                // Strongest in the middle game; the edge fades with level.
                m.cooldown *= 0.8
                m.damage *= clamp(1.9 - 0.035 * l, 0.8, 1.9)
            }
            .Null => {
                m.credit *= 1.3 * (1.0 + 0.01 * l)
                m.xp *= 0.75
                m.max_health += 3
            }
            .Lasher => { m.damage *= 1.2 * (1.0 + 0.01 * l); m.speed *= 0.85; m.area *= 1.33 }
            .Anchor => { m.max_health += 2 + level / 5; m.duration *= 1.3; m.damage *= 1.25 }
            .Carrier => { m.count += 1; m.cooldown *= 0.9 * (1.0 - 0.01 * clamp(l, 0.0, 40.0)) }
            .Warden => { m.regen += 0.5; m.armor += 1 + level / 8; m.speed *= 0.95; m.damage *= 0.9; m.duration *= 1.5 }
            .Hawk => { m.proj_speed *= 1.25 * (1.0 + 0.01 * l); m.count += 1; m.max_health = m.max_health * 9 / 10 }
            .Volt => { m.damage *= 1.15 * (1.0 + 0.01 * l); m.cooldown *= 0.9; m.max_health = m.max_health * 9 / 10 }
            .Mortar => { m.duration *= 1.2 * (1.0 + 0.01 * l); m.area *= 1.1; m.speed *= 0.9 }
            .Brace => { m.count += 1; m.damage *= 1.1 * (1.0 + 0.01 * l); m.proj_speed *= 0.9 }
            .Sentry => { m.duration *= 1.3 * (1.0 + 0.01 * l); m.speed *= 0.9 }
            .Lantern => { m.cooldown *= 0.85 * (1.0 - 0.01 * clamp(l, 0.0, 40.0)); m.damage *= 0.9 }
            .Coil => { m.area *= 1.2 * (1.0 + 0.01 * l); m.max_health = m.max_health * 9 / 10 }
            .Kestrel => { m.proj_speed *= 1.2 * (1.0 + 0.01 * l); m.count += 1; m.max_health = m.max_health * 9 / 10 }
            .Rampart => { m.armor += 1; m.area *= 1.0 + 0.01 * l; m.speed *= 0.9 }
            .Orbital => { m.max_health += 2 + level / 6; m.area *= 1.2; m.damage *= 0.9 }
            .Ghost => { m.damage *= 2.0 * (1.0 + 0.02 * l) }
            .Glass => { m.max_health = 1; m.damage *= 3.0 * (1.0 + 0.01 * l) }
            .Mirror => { m.rebound += 1; m.damage *= 1.15 * (1.0 + 0.01 * l); m.speed *= 0.9 }
        if m.max_health < 1: m.max_health = 1
        m

fn clamp(n: f64, lo: f64, hi: f64) -> f64:
    if n < lo: lo else if n > hi: hi else: n
