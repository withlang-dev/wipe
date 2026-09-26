use loadout

// The roster. Each ship is a base weapon, one strength, one growth curve,
// one weakness, and one unlock condition, all stated in plain numbers.
pub enum Ship { | Claw | Dart | Hull | Prism | Halo | Needle | Sapper | Phase | Null }
impl Copy for Ship
impl Eq for Ship

pub const SHIP_COUNT: i32 = 9

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
        _ => .Null

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

    pub fn strength(self: &Self) -> str:
        match self:
            .Claw => "Balanced. +1 reroll per run"
            .Dart => "+25% move speed, +20% projectile speed"
            .Hull => "+50% max health, +1 armor"
            .Prism => "Shards bounce twice more, +20% area"
            .Halo => "+60% magnet, cores worth +25% XP"
            .Needle => "+35% damage, lance pierces everything"
            .Sapper => "+40% area, mines chain-detonate"
            .Phase => "Invulnerable 2 s on every level-up"
            .Null => "Starts at level 5 with 3 weapons, +30% credits"

    pub fn growth(self: &Self) -> str:
        match self:
            .Claw => "+1% damage per level"
            .Dart => "+1% move speed per level"
            .Hull => "+1 max health every 5 levels"
            .Prism => "+1% area per level"
            .Halo => "+2% magnet per level"
            .Needle => "+1% damage per level, +5% every 10"
            .Sapper => "+1% cooldown per level"
            .Phase => "+0.1 s invulnerability every 5 levels"
            .Null => "+1% credits per level"

    pub fn weakness(self: &Self) -> str:
        match self:
            .Claw => "None"
            .Dart => "Max health 2"
            .Hull => "-20% move speed"
            .Prism => "-15% damage"
            .Halo => "Cannot take the Cannon"
            .Needle => "Cannot aim: no Cannon, the right stick does nothing"
            .Sapper => "Only 4 weapon slots"
            .Phase => "Max health 1. Reboots do not work"
            .Null => "-40% XP gain. Cannot merge"

    pub fn condition(self: &Self) -> Condition:
        match self:
            .Claw => .Start
            .Dart => .Survive(seconds: 300)
            .Hull => .HitsSurvived(count: 20)
            .Prism => .BouncedKills(count: 200)
            .Halo => .LifetimeCores(count: 5000)
            .Needle => .Combo(count: 60)
            .Sapper => .MergesInRun(count: 2)
            .Phase => .ClearNoReboot
            .Null => .KillNull

    pub fn secret(self: &Self) -> bool: *self == .Null

    pub fn weapon_slots(self: &Self) -> i32:
        match self:
            .Sapper => 4
            _ => 6

    pub fn forbidden_weapon(self: &Self) -> Option[Weapon]:
        match self:
            .Halo => Some(.Cannon)
            .Needle => Some(.Cannon)
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
                m.speed *= 1.25 * (1.0 + 0.01 * l)
                m.proj_speed *= 1.2
                m.max_health = 2
            }
            .Hull => {
                m.max_health = ((m.max_health as f64) * 1.5) as i32 + level / 5
                m.armor += 1
                m.speed *= 0.8
            }
            .Prism => {
                m.rebound += 2
                m.area *= 1.2 * (1.0 + 0.01 * l)
                m.damage *= 0.85
            }
            .Halo => {
                m.magnet *= 1.6 * (1.0 + 0.02 * l)
                m.xp *= 1.25
            }
            .Needle => { m.damage *= 1.35 * (1.0 + 0.01 * l + 0.05 * (level / 10) as f64) }
            .Sapper => { m.cooldown *= 1.0 - 0.01 * l }
            .Phase => {
                m.max_health = 1
                m.invuln_bonus = 2.0 + 0.1 * (level / 5) as f64
            }
            .Null => {
                m.credit *= 1.3 * (1.0 + 0.01 * l)
                m.xp *= 0.6
            }
        if m.max_health < 1: m.max_health = 1
        m
