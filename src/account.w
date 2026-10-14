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
            .Damage => 400
            .FireRate => 400
            .Count => 1800
            .Area => 320
            .Speed => 280
            .Magnet => 220
            .Health => 360
            .Armor => 900
            .Regen => 800
            .Luck => 480
            .Credit => 520
            .Cooldown => 600
            .Reboots => 2400
            .Skips => 560
            .Rerolls => 640
            .Banishes => 720
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
        .Merges(n) => (s.merges as f64, n as f64)
        .HurryClear => (s.hurry_clears as f64, 1.0)

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
        .Mines => .Elites(count: 40)
        .Arc => .Start
        .Shard => .LifetimeKills(count: 30000)
        _ => .Start

pub fn passive_condition(p: Passive) -> Condition:
    match p:
        .Cooldown => .Bosses(count: 5)
        .Armor => .HitsTaken(count: 100)
        .Luck => .Caches(count: 10)
        .Credit => .Banked(credits: 5000)
        .Rebound => .BouncedKills(count: 50)
        .Overclock => .Bosses(count: 8)
        _ => .Start

pub fn ship_unlocked(ship: Ship, s: &Save) -> bool: met(ship.condition(), s)

// Stages open on a level reached within a run, so a failed run still opens
// doors (progression-plan §8; the numbers are the matrix's first guesses,
// to be set from the run log). The bonus arenas follow the normal ones.
pub fn stage_condition(stage: Stage) -> Condition:
    match stage:
        .Field => .Start
        .Corridor => .Level(level: 12)
        .Shaft => .Level(level: 20)
        .Ring => .Level(level: 28)
        .Cross => .Level(level: 35)
        .Pillars => .Survive(seconds: 600)
        .Maze => .Level(level: 12)
        .Gridlock => .Merges(count: 3)
        .Expanse => .Level(level: 28)

// Hurry opens with the first clear: the run in ten real minutes.
pub fn hurry_unlocked(s: &Save) -> bool: met(.Clear, s)

pub fn stage_unlocked(stage: Stage, s: &Save) -> bool: met(stage_condition(stage), s)

pub fn unlocked_ship_count(s: &Save) -> i32:
    var n = 0
    for i in 0..SHIP_COUNT:
        if ship_unlocked(ship_at(i), s): n += 1
    n

// The run's launch: ship, ranks, unlocks, and the best to beat.
pub fn launch_for(ship: Ship, s: &Save, endless: bool, hurry: bool = false) -> Launch:
    var l = Launch {
        ship, shop: shop_mods(s),
        reboots: s.ranks[12], skips: s.ranks[13], rerolls: s.ranks[14], banishes: s.ranks[15],
        taken_weapons: s.taken_weapons, taken_passives: s.taken_passives,
        best_time: if endless: s.best_endless[ship.index()] else: s.best_time[ship.index()],
        endless, hurry, bosses_known: s.boss_slain,
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

// Three open loops at once, so progression forks (progression-plan §3):
// `near` is the goal closest to done; `new` the one most recently begun
// (under a third of the way, the furthest along of those); `stretch` a
// stage or ship far off, the long-term pull. Each is a different goal.
pub type Threads { near: Option[NextUnlock] = None, new: Option[NextUnlock] = None, stretch: Option[NextUnlock] = None }

fn every_goal(s: &Save) -> List[NextUnlock]:
    var out: List[NextUnlock] = List.new()
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if ship.secret() and not s.null_killed and s.clears == 0: continue
        let c = ship.condition()
        if not met(c, s): out.push(NextUnlock { name: f"{ship.name()} ship", condition: c, fraction: fraction(c, s) })
    for i in 0..STAGE_COUNT:
        let c = stage_condition(stage_at(i))
        if not met(c, s): out.push(NextUnlock { name: f"{stage_at(i).name()} stage", condition: c, fraction: fraction(c, s) })
    for i in 0..BASE_WEAPON_COUNT:
        let c = weapon_condition(weapon_at(i))
        if not met(c, s): out.push(NextUnlock { name: weapon_at(i).name(), condition: c, fraction: fraction(c, s) })
    for i in 0..PASSIVE_COUNT:
        let c = passive_condition(passive_at(i))
        if not met(c, s): out.push(NextUnlock { name: passive_at(i).name(), condition: c, fraction: fraction(c, s) })
    if not hurry_unlocked(s): out.push(NextUnlock { name: "Hurry mode", condition: .Clear, fraction: fraction(.Clear, s) })
    out

fn same_goal(a: &Option[NextUnlock], b: &NextUnlock) -> bool:
    match a:
        Some(g) => g.name == b.name
        None => false

pub fn next_unlocks(s: &Save) -> Threads:
    let goals = every_goal(s)
    var t = Threads {}
    var near_f = -1.0
    for g in &goals:
        if g.fraction > near_f:
            near_f = g.fraction
            t.near = Some(NextUnlock { name: g.name.clone(), condition: g.condition, fraction: g.fraction })
    var new_f = 0.0
    for g in &goals:
        if same_goal(&t.near, g): continue
        if g.fraction > new_f and g.fraction < 0.34:
            new_f = g.fraction
            t.new = Some(NextUnlock { name: g.name.clone(), condition: g.condition, fraction: g.fraction })
    // Nothing begun yet (a fresh account): the first weapon or passive to
    // start on.
    if t.new.is_none():
        for g in &goals:
            if same_goal(&t.near, g) or g.name.ends_with(" stage") or g.name.ends_with(" ship") or g.name == "Hurry mode": continue
            t.new = Some(NextUnlock { name: g.name.clone(), condition: g.condition, fraction: g.fraction })
            break
    // A stage first, then a ship, the farthest off.
    var stretch_f = 2.0
    for pass in 0..2:
        if t.stretch.is_some(): break
        for g in &goals:
            if same_goal(&t.near, g) or same_goal(&t.new, g): continue
            let is_stage = g.name.ends_with(" stage")
            let is_ship = g.name.ends_with(" ship")
            if (pass == 0 and not is_stage) or (pass == 1 and not is_ship): continue
            if g.fraction < stretch_f:
                stretch_f = g.fraction
                t.stretch = Some(NextUnlock { name: g.name.clone(), condition: g.condition, fraction: g.fraction })
    t

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
pub fn new_ships(before: &Save, after: &Save) -> List[Ship]:
    var out = List.new()
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if not ship_unlocked(ship, before) and ship_unlocked(ship, after): out.push(ship)
    out

// Things a run unlocked, as names.
pub fn new_unlocks(before: &Save, after: &Save) -> List[str]:
    var out = List.new()
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

// ----- the progression score ----------------------------------------------------

// What a run changed for the account, as the plan's score (progression-plan
// §3): 3 for an unlock or a merge discovered, 2 for a rank bought or newly
// affordable, 1 for a named goal advanced a fifth of the way. Events are
// `kind:name` tokens for the run log. The window is from one run's log row
// to the next, so a shop visit between runs counts for the run it follows.
pub type ProgressReport { score: i32 = 0, events: List[str] = List.new() }

pub fn progress_score(before: &Save, after: &Save) -> ProgressReport:
    var r = ProgressReport {}
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if not ship_unlocked(ship, before) and ship_unlocked(ship, after):
            r.score += 3
            r.events.push(f"ship:{ship.name()}")
    for i in 0..BASE_WEAPON_COUNT:
        let w = weapon_at(i)
        if not met(weapon_condition(w), before) and met(weapon_condition(w), after):
            r.score += 3
            r.events.push(f"weapon:{w.name()}")
    for i in 0..PASSIVE_COUNT:
        let p = passive_at(i)
        if not met(passive_condition(p), before) and met(passive_condition(p), after):
            r.score += 3
            r.events.push(f"passive:{p.name()}")
    for i in 0..STAGE_COUNT:
        let stage = stage_at(i)
        if not met(stage_condition(stage), before) and met(stage_condition(stage), after):
            r.score += 3
            r.events.push(f"stage:{stage.name()}")
    // A merged weapon taken for the first time is a recipe discovered.
    for i in BASE_WEAPON_COUNT..WEAPON_COUNT:
        if not before.taken_weapons[i] and after.taken_weapons[i]:
            r.score += 3
            r.events.push(f"merge:{weapon_at(i).name()}")
    for i in 0..SHOP_COUNT:
        if after.ranks[i] > before.ranks[i]:
            r.score += 2
            r.events.push(f"rank:{shop_item_at(i).name()} {after.ranks[i]}")
    // The cheapest rank crossed from out of reach to affordable.
    if let Some(next) = next_rank(after):
        if before.credits < next.price and after.credits >= next.price:
            r.score += 2
            r.events.push(f"afford:{next.item.name()} {next.rank}")
    // A named goal a fifth closer, once per goal, only while still unmet.
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if ship.secret() and not after.null_killed and after.clears == 0: continue
        let c = ship.condition()
        if not met(c, after) and fraction(c, after) - fraction(c, before) >= 0.2:
            r.score += 1
            r.events.push(f"goal:{ship.name()} ship")
    for i in 0..BASE_WEAPON_COUNT:
        let c = weapon_condition(weapon_at(i))
        if not met(c, after) and fraction(c, after) - fraction(c, before) >= 0.2:
            r.score += 1
            r.events.push(f"goal:{weapon_at(i).name()}")
    for i in 0..PASSIVE_COUNT:
        let c = passive_condition(passive_at(i))
        if not met(c, after) and fraction(c, after) - fraction(c, before) >= 0.2:
            r.score += 1
            r.events.push(f"goal:{passive_at(i).name()}")
    for i in 0..STAGE_COUNT:
        let c = stage_condition(stage_at(i))
        if not met(c, after) and fraction(c, after) - fraction(c, before) >= 0.2:
            r.score += 1
            r.events.push(f"goal:{stage_at(i).name()} stage")
    r

// ----- session metrics ----------------------------------------------------------

// The five numbers of spec §10, kept for the session and shown in F1.
pub type Metrics {
    runs: i32 = 0, quick_retries: i32 = 0,
    lengths: List[f64],
    unlock_near: i32 = 0, shop_near: i32 = 0, results: i32 = 0,
}
pub fn Metrics.new() -> Metrics: Metrics { lengths: List.new() }
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
        var sorted = List.new()
        for v in self.lengths: sorted.push(v)
        for i in 1..n:
            var j = i
            while j > 0 and sorted[j - 1] > sorted[j]:
                let t: f64 = sorted[j]
                sorted[j] = sorted[j - 1]
                sorted[j - 1] = t
                j -= 1
        return sorted[n / 2]
    pub fn lines(self: &Self) -> List[str]:
        var out = List.new()
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
