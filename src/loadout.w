// Weapons, passives, merge recipes, and the run's build. Pure data and pure
// functions: the simulation asks for stats, the menus ask for names.

// Eight launch weapons, eight evolutions, four unions.
pub enum Weapon {
    | Cannon | Orbit | Nova | Seeker | Lance | Mines | Arc | Shard
    | Railgun | Corona | Supernova | Swarm | Pike | Minefield | Storm | Shatter
    | Tracer | Pulsar | Grid | Refractor
}
impl Copy for Weapon
impl Eq for Weapon

pub const WEAPON_COUNT: i32 = 20
pub const BASE_WEAPON_COUNT: i32 = 8
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
        8 => .Railgun
        9 => .Corona
        10 => .Supernova
        11 => .Swarm
        12 => .Pike
        13 => .Minefield
        14 => .Storm
        15 => .Shatter
        16 => .Tracer
        17 => .Pulsar
        18 => .Grid
        _ => .Refractor

// How a weapon fires. Merged weapons reuse a family with multipliers and
// flags, so one firing routine per family covers twenty weapons.
pub enum Family { | Aimed | Orbiting | Ring | Homing | Beam | Dropped | Chain | Bouncing }
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
            .Railgun => 8
            .Corona => 9
            .Supernova => 10
            .Swarm => 11
            .Pike => 12
            .Minefield => 13
            .Storm => 14
            .Shatter => 15
            .Tracer => 16
            .Pulsar => 17
            .Grid => 18
            .Refractor => 19

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
            .Railgun => "Railgun"
            .Corona => "Corona"
            .Supernova => "Supernova"
            .Swarm => "Swarm"
            .Pike => "Pike"
            .Minefield => "Minefield"
            .Storm => "Storm"
            .Shatter => "Shatter"
            .Tracer => "Tracer"
            .Pulsar => "Pulsar"
            .Grid => "Grid"
            .Refractor => "Refractor"

    pub fn describe(self: &Self) -> str:
        match self:
            .Cannon => "Aimed bolts. The one weapon the right stick commands."
            .Orbit => "Blades circle the ship."
            .Nova => "A ring burst around the ship."
            .Seeker => "Homing bolts at the nearest enemy."
            .Lance => "Piercing beams forward and back along the movement."
            .Mines => "Dropped on the path, detonating on contact."
            .Arc => "Lightning strikes random enemies about once a second. More bolts and longer chains as it levels."
            .Shard => "Fragments that ricochet off the arena walls."
            .Railgun => "Cannon evolved: three heavy bolts that pierce three."
            .Corona => "Orbit evolved: a wide, dense ring of blades."
            .Supernova => "Nova evolved: a vast ring, twice as often."
            .Swarm => "Seeker evolved: a cloud of fast homing bolts."
            .Pike => "Lance evolved: a longer beam that pierces far deeper."
            .Minefield => "Mines evolved: a dense field that chain-detonates."
            .Storm => "Arc evolved: a storm of bolts with long chains."
            .Shatter => "Shard evolved: every bounce splits the fragment."
            .Tracer => "Cannon and Seeker: aimed bolts that hunt."
            .Pulsar => "Orbit and Nova: blades that burst as they turn."
            .Grid => "Mines and Arc: detonations that chain lightning."
            .Refractor => "Lance and Shard: a deep beam that shatters where it ends."

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

    pub fn is_merged(self: &Self) -> bool: self.index() >= BASE_WEAPON_COUNT

    // Weapons that can be offered as new picks. Merged weapons only arrive
    // through their recipe.
    pub fn is_base(self: &Self) -> bool: self.index() < BASE_WEAPON_COUNT

// Fourteen passives: eight at launch, six unlockable.
pub enum Passive {
    | Damage | FireRate | Count | Area | ProjSpeed | Magnet | Speed | Health
    | Cooldown | Armor | Luck | Credit | Rebound | Overclock
}
impl Copy for Passive
impl Eq for Passive

pub const PASSIVE_COUNT: i32 = 14
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
        _ => .Overclock

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

// A merge recipe: weapons at max, key passive held at any level.
pub type Recipe { result: Weapon = .Railgun, first: Weapon = .Cannon, second: Option[Weapon] = None, key: Passive = .FireRate }
impl Copy for Recipe

pub const RECIPE_COUNT: i32 = 12

pub fn recipes() -> [Recipe; 12]:
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
    ]

pub fn recipe_for(result: Weapon) -> Option[Recipe]:
    for r in recipes():
        if r.result == result: return Some(r)
    None

// Every stat multiplier the build applies, computed once per change.
pub type Mods {
    damage: f64 = 1.0, cooldown: f64 = 1.0, cannon_rate: f64 = 1.0,
    count: i32 = 0, area: f64 = 1.0, proj_speed: f64 = 1.0,
    magnet: f64 = 1.0, speed: f64 = 1.0, max_health: i32 = 10,
    armor: i32 = 0, luck: f64 = 0.0, credit: f64 = 1.0,
    rebound: i32 = 0, overclock: f64 = 0.0, xp: f64 = 1.0,
    regen: f64 = 0.0, invuln_bonus: f64 = 0.0,
}
impl Copy for Mods

// The stats one weapon fires with this tick.
pub type WeaponStats {
    cooldown: f64 = 1.0, damage: i32 = 1, count: i32 = 1, speed: f64 = 900.0,
    radius: f64 = 100.0, pierce: i32 = 0, bounces: i32 = 0, lifetime: f64 = 1.6,
    chain: i32 = 3, homing: bool = false, splits: bool = false, chains_on_hit: bool = false,
    ring_on_orbit: bool = false, shatters: bool = false, max_active: i32 = 6,
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
            s.damage = 2 + level / 2
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
            // Two beams, forward and back, so each hits for less.
            s.damage = 2 + level / 2
            s.pierce = 2 + level / 2
        }
        .Dropped => {
            s.cooldown = 1.1 - (l - 1.0) * 0.06
            s.radius = 85.0 + l * 7.0
            s.damage = 2 + level
            s.max_active = 5 + step(level, 2, 2)
        }
        .Chain => {
            // One bolt at I, two at III, three at V; chains from II.
            s.cooldown = 1.0 - (l - 1.0) * 0.04
            s.count = 1 + (level - 1) / 3
            s.chain = (level - 1) / 2
            s.radius = 230.0
            s.damage = 6 + level * 2
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
        .Tracer => { s.homing = true; s.damage *= 2; s.count += 1 }
        .Pulsar => { s.count += 2; s.damage *= 2; s.ring_on_orbit = true }
        .Grid => { s.damage = s.damage * 3 / 2; s.max_active += 3; s.chains_on_hit = true }
        .Refractor => { s.pierce += 6; s.damage *= 2; s.shatters = true }
        _ => ()
    // Passives and shop ranks apply on top.
    s.damage = ((s.damage as f64) * mods.damage + 0.5) as i32
    if s.damage < 1: s.damage = 1
    s.cooldown *= mods.cooldown
    if weapon.family() == .Aimed: s.cooldown *= mods.cannon_rate
    if s.cooldown < 0.03: s.cooldown = 0.03
    if weapon.family() == .Aimed or weapon.family() == .Homing or weapon.family() == .Bouncing or weapon.family() == .Orbiting or weapon.family() == .Chain:
        s.count += mods.count
    s.radius *= mods.area
    s.speed *= mods.proj_speed
    s.bounces += mods.rebound
    s

// One weapon or passive slot. `level` zero means empty.
pub type WeaponSlot { weapon: Weapon = .Cannon, level: i32 = 0, timer: f64 = 0.0, phase: f64 = 0.0, seen: bool = false }
impl Copy for WeaponSlot
pub type PassiveSlot { passive: Passive = .Damage, level: i32 = 0 }
impl Copy for PassiveSlot

pub const SLOT_COUNT: i32 = 6

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
    weapon_slots: i32 = 6,
    banished_weapons: [bool; 20] = [false; 20],
    banished_passives: [bool; 14] = [false; 14],
    // Weapons and passives this account may be offered.
    unlocked_weapons: [bool; 20] = [false; 20],
    unlocked_passives: [bool; 14] = [false; 14],
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

    pub fn ready_merges(self: &Self) -> Vec[Weapon]:
        var out: Vec[Weapon] = Vec.new()
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

    pub fn candidates(self: &Self) -> Vec[Pick]:
        var out: Vec[Pick] = Vec.new()
        for m in self.ready_merges(): out.push(.Merge(result: m))
        let free_weapon = self.weapon_count() < self.weapon_slots
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
        let free_passive = self.passive_count() < SLOT_COUNT
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
        m.xp *= 1.0 + m.overclock
        m.credit *= 1.0 + m.overclock
        m
