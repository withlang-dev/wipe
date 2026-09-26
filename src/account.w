use loadout
use ships
use game
use save
use tuning

// The shop: permanent ranks bought with credits. Ranks are small; prices
// escalate so the next rank is about 1.3 runs of income away.
pub enum ShopItem {
    | Damage | FireRate | Count | Area | Speed | Magnet | Health | Armor
    | Regen | Luck | Credit | Cooldown | Reboots | Skips | Rerolls | Banishes
}
impl Copy for ShopItem
impl Eq for ShopItem

pub fn shop_item_at(index: i32) -> ShopItem:
    match index:
        0 => .Damage
        1 => .FireRate
        2 => .Count
        3 => .Area
        4 => .Speed
        5 => .Magnet
        6 => .Health
        7 => .Armor
        8 => .Regen
        9 => .Luck
        10 => .Credit
        11 => .Cooldown
        12 => .Reboots
        13 => .Skips
        14 => .Rerolls
        _ => .Banishes

extend ShopItem:
    pub fn index(self: &Self) -> i32:
        match self:
            .Damage => 0
            .FireRate => 1
            .Count => 2
            .Area => 3
            .Speed => 4
            .Magnet => 5
            .Health => 6
            .Armor => 7
            .Regen => 8
            .Luck => 9
            .Credit => 10
            .Cooldown => 11
            .Reboots => 12
            .Skips => 13
            .Rerolls => 14
            .Banishes => 15
    pub fn name(self: &Self) -> str:
        match self:
            .Damage => "Damage"
            .FireRate => "Fire rate"
            .Count => "Projectiles"
            .Area => "Area"
            .Speed => "Thrusters"
            .Magnet => "Magnet"
            .Health => "Hull"
            .Armor => "Armor"
            .Regen => "Repair"
            .Luck => "Luck"
            .Credit => "Salvage"
            .Cooldown => "Cooldown"
            .Reboots => "Reboots"
            .Skips => "Skips"
            .Rerolls => "Rerolls"
            .Banishes => "Banish"
    pub fn max_rank(self: &Self) -> i32:
        match self:
            .Count => 2
            .Armor => 3
            .Reboots => 2
            .Skips => 3
            .Rerolls => 3
            .Banishes => 3
            .Regen => 3
            _ => 5
    pub fn base_price(self: &Self) -> i32:
        match self:
            .Damage => 200
            .FireRate => 200
            .Count => 900
            .Area => 160
            .Speed => 140
            .Magnet => 110
            .Health => 180
            .Armor => 450
            .Regen => 400
            .Luck => 240
            .Credit => 260
            .Cooldown => 300
            .Reboots => 1200
            .Skips => 280
            .Rerolls => 320
            .Banishes => 360
    // The price of the rank after `rank`: base, then +60% per rank.
    pub fn price(self: &Self, rank: i32) -> i32:
        var p = self.base_price() as f64
        for _ in 0..rank: p *= 1.6
        ((p / 10.0) as i32) * 10
    // One rank's effect, in plain numbers, at a rank.
    pub fn effect(self: &Self, rank: i32) -> str:
        match self:
            .Damage => f"+{rank * 5}% damage"
            .FireRate => f"-{rank * 4}% cannon interval"
            .Count => f"+{rank} projectile"
            .Area => f"+{rank * 5}% area"
            .Speed => f"+{rank * 4}% move speed"
            .Magnet => f"+{rank * 10}% magnet"
            .Health => f"+{rank} max health"
            .Armor => f"ignore the first {rank} damage of every hit"
            .Regen => f"repair 1 health every {if rank == 0: 0 else: 30 / rank} s"
            .Luck => f"+{rank * 10}% luck"
            .Credit => f"+{rank * 10}% credits"
            .Cooldown => f"-{rank * 3}% cooldowns"
            .Reboots => f"{rank} reboot per run"
            .Skips => f"{rank} skip per run"
            .Rerolls => f"{rank} reroll per run"
            .Banishes => f"{rank} banish per run"

pub const SHOP_COUNT: i32 = 16

// Apply every rank to the base multipliers a run starts from.
pub fn shop_mods(save: &Save) -> Mods:
    var m = Mods {}
    let r = save.ranks
    m.damage *= 1.0 + 0.05 * r[0] as f64
    m.cannon_rate *= 1.0 - 0.04 * r[1] as f64
    m.count += r[2]
    m.area *= 1.0 + 0.05 * r[3] as f64
    m.speed *= 1.0 + 0.04 * r[4] as f64
    m.magnet *= 1.0 + 0.10 * r[5] as f64
    m.max_health += r[6]
    m.armor += r[7]
    m.regen = if r[8] > 0: (r[8] as f64) / 30.0 else: 0.0
    m.luck += 0.1 * r[9] as f64
    m.credit *= 1.0 + 0.10 * r[10] as f64
    m.cooldown *= 1.0 - 0.03 * r[11] as f64
    m

// ----- unlocks --------------------------------------------------------------------

// Progress toward a condition, as (current, goal).
pub fn progress(c: Condition, s: &Save) -> (f64, f64):
    match c:
        .Start => (1.0, 1.0)
        .Survive(secs) => (best_any(s), secs as f64)
        .SurviveWith(w, secs) => (s.held[w.index()], secs as f64)
        .HitsSurvived(n) => (s.best_hits_survived as f64, n as f64)
        .BouncedKills(n) => (s.bounced_kills as f64, n as f64)
        .LifetimeCores(n) => (s.cores as f64, n as f64)
        .Combo(n) => (s.best_combo as f64, n as f64)
        .MergesInRun(n) => (s.best_merges_in_run as f64, n as f64)
        .ClearNoReboot => (if s.no_reboot_clear: 1.0 else: 0.0, 1.0)
        .KillNull => (if s.null_killed: 1.0 else: 0.0, 1.0)
        .Level(l) => (s.best_level as f64, l as f64)
        .LifetimeKills(n) => (s.kills as f64, n as f64)
        .Elites(n) => (s.elites as f64, n as f64)
        .Caches(n) => (s.caches as f64, n as f64)
        .Banked(n) => (s.banked as f64, n as f64)
        .HitsTaken(n) => (s.hits as f64, n as f64)
        .Clear => (s.clears as f64, 1.0)
        .Bosses(n) => (s.bosses as f64, n as f64)

pub fn met(c: Condition, s: &Save) -> bool:
    let (have, need) = progress(c, s)
    have >= need

pub fn fraction(c: Condition, s: &Save) -> f64:
    let (have, need) = progress(c, s)
    if need <= 0.0: 1.0 else if have >= need: 1.0 else: have / need

fn best_any(s: &Save) -> f64:
    var best = 0.0
    for i in 0..SHIP_COUNT:
        if s.best_time[i] > best: best = s.best_time[i]
    best

// Launch weapons and passives beyond the starting set each have a condition.
pub fn weapon_condition(w: Weapon) -> Condition:
    match w:
        .Cannon => .Start
        .Orbit => .Start
        .Nova => .Start
        .Seeker => .Start
        .Lance => .SurviveWith(weapon: .Cannon, seconds: 900)
        .Mines => .Elites(count: 10)
        .Arc => .Level(level: 20)
        .Shard => .LifetimeKills(count: 3000)
        _ => .Start

pub fn passive_condition(p: Passive) -> Condition:
    match p:
        .Cooldown => .Bosses(count: 3)
        .Armor => .HitsTaken(count: 100)
        .Luck => .Caches(count: 10)
        .Credit => .Banked(credits: 5000)
        .Rebound => .BouncedKills(count: 50)
        .Overclock => .Clear
        _ => .Start

pub fn ship_unlocked(ship: Ship, s: &Save) -> bool: met(ship.condition(), s)

pub fn stage_condition(stage: Stage) -> Condition:
    match stage:
        .Field => .Start
        .Corridor => .Clear
        .Shaft => .Bosses(count: 10)

pub fn stage_unlocked(stage: Stage, s: &Save) -> bool: met(stage_condition(stage), s)

pub fn unlocked_ship_count(s: &Save) -> i32:
    var n = 0
    for i in 0..SHIP_COUNT:
        if ship_unlocked(ship_at(i), s): n += 1
    n

// The run's launch: ship, ranks, unlocks, and the best to beat.
pub fn launch_for(ship: Ship, s: &Save, endless: bool) -> Launch:
    var l = Launch {
        ship, shop: shop_mods(s),
        reboots: s.ranks[12], skips: s.ranks[13], rerolls: s.ranks[14], banishes: s.ranks[15],
        taken_weapons: s.taken_weapons, taken_passives: s.taken_passives,
        best_time: if endless: s.best_endless[ship.index()] else: s.best_time[ship.index()],
        endless,
    }
    for i in 0..BASE_WEAPON_COUNT: l.unlocked_weapons[i] = met(weapon_condition(weapon_at(i)), s)
    for i in 0..PASSIVE_COUNT: l.unlocked_passives[i] = met(passive_condition(passive_at(i)), s)
    l

// ----- open loops for the results screen ------------------------------------------

// The next unlock: prefer a ship within 30% of its condition, otherwise the
// nearest incomplete condition of anything.
pub type NextUnlock { name: str, condition: Condition, fraction: f64 = 0.0 }

pub fn next_unlock(s: &Save) -> Option[NextUnlock]:
    var best: Option[NextUnlock] = None
    var best_f = -1.0
    var ship_pick: Option[NextUnlock] = None
    var ship_f = -1.0
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if ship.secret() and not s.null_killed and s.clears == 0: continue
        let c = ship.condition()
        if met(c, s): continue
        let f = fraction(c, s)
        if f >= 0.7 and f > ship_f:
            ship_f = f
            ship_pick = Some(NextUnlock { name: f"{ship.name()} ship", condition: c, fraction: f })
        if f > best_f:
            best_f = f
            best = Some(NextUnlock { name: f"{ship.name()} ship", condition: c, fraction: f })
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        let c = weapon_condition(w)
        if met(c, s): continue
        let f = fraction(c, s)
        if f > best_f:
            best_f = f
            best = Some(NextUnlock { name: w.name(), condition: c, fraction: f })
    for i in 0..PASSIVE_COUNT:
        let p = passive_at(i)
        let c = passive_condition(p)
        if met(c, s): continue
        let f = fraction(c, s)
        if f > best_f:
            best_f = f
            best = Some(NextUnlock { name: p.name(), condition: c, fraction: f })
    if ship_pick.is_some(): ship_pick else: best

// The next shop rank: the cheapest one not yet bought.
pub type NextRank { item: ShopItem = .Damage, rank: i32 = 0, price: i32 = 0 }
impl Copy for NextRank

pub fn next_rank(s: &Save) -> Option[NextRank]:
    var best: Option[NextRank] = None
    var best_price = 2147483647
    for i in 0..SHOP_COUNT:
        let item = shop_item_at(i)
        let rank = s.ranks[i]
        if rank >= item.max_rank(): continue
        let price = item.price(rank)
        if price < best_price:
            best_price = price
            best = Some(NextRank { item, rank: rank + 1, price })
    best

// Every ship newly unlocked by a run, comparing before and after.
pub fn new_ships(before: &Save, after: &Save) -> Vec[Ship]:
    var out: Vec[Ship] = Vec.new()
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if not ship_unlocked(ship, before) and ship_unlocked(ship, after): out.push(ship)
    out

// Things a run unlocked, as names.
pub fn new_unlocks(before: &Save, after: &Save) -> Vec[str]:
    var out: Vec[str] = Vec.new()
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if not ship_unlocked(ship, before) and ship_unlocked(ship, after): out.push(f"{ship.name()} ship")
    for i in 0..BASE_WEAPON_COUNT:
        let c = weapon_condition(weapon_at(i))
        if not met(c, before) and met(c, after): out.push(weapon_at(i).name())
    for i in 0..PASSIVE_COUNT:
        let c = passive_condition(passive_at(i))
        if not met(c, before) and met(c, after): out.push(passive_at(i).name())
    for i in 0..STAGE_COUNT:
        let c = stage_condition(stage_at(i))
        if not met(c, before) and met(c, after): out.push(f"{stage_at(i).name()} stage")
    out

// ----- session metrics ----------------------------------------------------------

// The five numbers of spec §10, kept for the session and shown in F1.
pub type Metrics {
    runs: i32 = 0, quick_retries: i32 = 0,
    lengths: Vec[f64],
    unlock_near: i32 = 0, shop_near: i32 = 0, results: i32 = 0,
}
pub fn Metrics.new() -> Metrics: Metrics { lengths: Vec.new() }
extend Metrics:
    pub fn record(mut self: Self, length: f64, unlock_fraction: f64, shop_fraction: f64):
        self.runs += 1
        self.results += 1
        self.lengths.push(length)
        if unlock_fraction >= 0.7: self.unlock_near += 1
        if shop_fraction >= 0.7: self.shop_near += 1
    pub fn median(self: &Self) -> f64:
        let n = self.lengths.len() as i32
        if n == 0: return 0.0
        var sorted: Vec[f64] = Vec.new()
        for v in self.lengths: sorted.push(v)
        for i in 1..n:
            var j = i
            while j > 0 and sorted[j - 1] > sorted[j]:
                let t: f64 = sorted[j]
                sorted[j] = sorted[j - 1]
                sorted[j - 1] = t
                j -= 1
        return sorted[n / 2]
    pub fn lines(self: &Self) -> Vec[str]:
        var out: Vec[str] = Vec.new()
        let denominator = if self.results > 0: self.results else: 1
        out.push(f"RUNS THIS SESSION  {self.runs}")
        out.push(f"RETRIES < 3 S      {self.quick_retries}")
        let median = self.median() as i32
        let seconds = median % 60
        let pad = if seconds < 10: "0" else: ""
        out.push(f"MEDIAN RUN         {median / 60}:{pad}{seconds}")
        out.push(f"UNLOCK WITHIN 30%  {self.unlock_near * 100 / denominator}%")
        out.push(f"RANK WITHIN 30%    {self.shop_near * 100 / denominator}%")
        out
