// Merge odds: full runs by a player who knows exactly which merge they want.
// They take every card that advances the recipe, reroll and banish when
// nothing helps, fight with the playtest pilot, and play to death or the
// cap. The report is how often the merge actually happens: the target is
// about two runs in three, so a merge is earned by choices and luck, not
// promised.
//
//   ./out/bin/odds [runs per recipe]
use std.process.args
use std.string.parse
use game
use tuning
use loadout
use ships

fn fly(g: &Game) -> Controls:
    var push = V2 {}
    var aim = g.aim
    var nearest = 1.0e12
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        let d = sub(g.player, e.pos)
        let d2 = length2(d)
        if d2 < nearest:
            nearest = d2
            aim = scale(d, -1.0)
        let fear = if e.kind == .Boss or e.kind == .Null: 380.0 else: 230.0
        if d2 < fear * fear and d2 > 1.0: push = add(push, scale(d, 1.0 / d2 * (if e.kind == .Boss: 400.0 else: 90.0)))
    for i in 0..g.bullet_count:
        let b: Bullet = g.bullets[i]
        if not b.hostile: continue
        let d = sub(g.player, b.pos)
        let d2 = length2(d)
        if d2 < 160.0 * 160.0 and d2 > 1.0: push = add(push, scale(d, 1.0 / d2 * 160.0))
    let threatened = nearest < 200.0 * 200.0
    var core_target = -1
    var core_best = 700.0 * 700.0
    for i in 0..g.core_count:
        let d2 = length2(sub(g.cores[i].pos, g.player))
        if d2 < core_best:
            core_best = d2
            core_target = i
    if core_target >= 0:
        push = add(push, scale(direction(sub(g.cores[core_target].pos, g.player)), if threatened: 0.3 else: 1.2))
    for i in 0..g.pickup_count:
        let d = sub(g.pickups[i].pos, g.player)
        if length2(d) > 1.0: push = add(push, scale(direction(d), 0.4))
    push = add(push, scale(sub(g.center(), g.player), 0.0007))
    Controls { motion: movement(scale(push, 3.0)), aim }

fn part_of(r: Recipe, w: Weapon) -> bool:
    if r.first == w: return true
    match r.second:
        Some(x) => x == w
        None => false

// How much a card advances the recipe; zero when it does not.
fn value(g: &Game, r: Recipe, pick: Pick) -> f64:
    match pick:
        .Merge(w) => if w == r.result: 1000.0 else: 0.0
        .NewWeapon(w) => if part_of(r, w): 100.0 else: 0.0
        .UpgradeWeapon(w) => if part_of(r, w): 60.0 - g.build.weapon_level(w) as f64 else: 0.0
        .NewPassive(p) => if p == r.key: 90.0 else: 0.0
        .UpgradePassive(_) => 0.0

// A card that does not help the recipe. The expert fills weapon slots
// early (full slots stop new weapons from diluting the offers), and after
// that prefers passives that keep the run alive.
fn filler(g: &Game, r: Recipe, pick: Pick) -> f64:
    // Keep room for the components the recipe still needs.
    var needed = 0
    if g.build.weapon_level(r.first) == 0: needed += 1
    if let Some(second) = r.second:
        if g.build.weapon_level(second) == 0: needed += 1
    let room = g.build.weapon_slots - g.build.weapon_count() - needed
    match pick:
        .NewWeapon(_) => if room > 0: 15.0 else: 0.0
        .UpgradePassive(p) => if p == .Damage or p == .Health or p == .Magnet: 12.0 else: 8.0
        .NewPassive(p) => if p == .Damage or p == .Health or p == .Magnet: 10.0 else: 6.0
        .UpgradeWeapon(_) => 7.0
        .Merge(_) => 20.0

type Outcome { merged: bool = false, minute: f64 = 0.0, level: i32 = 0, cleared: bool = false }
impl Copy for Outcome

// The ship a player who knows the recipe would fly: one that starts with a
// component.
fn ship_for(r: Recipe) -> Ship:
    for i in 0..SHIP_COUNT:
        let ship = ship_at(i)
        if ship == .Null: continue
        if ship.base_weapon() == r.first: return ship
    .Claw

fn attempt(r: Recipe, seed: i32, rerolls: i32, banishes: i32, skips: i32) -> Outcome:
    var g = Game.new()
    var launch = Launch { ship: ship_for(r), rerolls, banishes, skips }
    for i in 0..BASE_WEAPON_COUNT: launch.unlocked_weapons[i] = true
    for i in 0..PASSIVE_COUNT: launch.unlocked_passives[i] = true
    // A player who knows the game has some shop ranks.
    launch.shop.damage = 1.1
    launch.shop.max_health = 12
    launch.shop.magnet = 1.2
    g.rng = 97531 +% (seed as u32) *% 2654435761
    g.start(launch)
    var merged_at = -1.0
    var steps = 0
    while g.phase != .Over and steps < 120 * 60 * 21:
        steps += 1
        g.clear_events()
        g.tick(fly(&g), 1.0 / 120.0)
        var guard = 0
        while g.phase == .Boost and guard < 20:
            guard += 1
            if g.cache_reveal > 0.0: g.cache_reveal = 0.0
            var best = 0
            var best_value = 0.0
            for i in 0..g.offer_count:
                let v = value(&g, r, g.offers[i].pick)
                if v > best_value:
                    best_value = v
                    best = i
            if best_value > 0.0:
                if g.offers[best].pick.is_merge() and merged_at < 0.0: merged_at = g.elapsed
                g.choose(best)
                continue
            // Nothing helps: reroll, else banish a weapon that competes for
            // slots, else skip, else take the least harmful card.
            if g.rerolls > 0:
                g.reroll()
                continue
            var banish_at = -1
            for i in 0..g.offer_count:
                if filler(&g, r, g.offers[i].pick) <= 0.0: banish_at = i
            if g.banishes > 0 and banish_at >= 0:
                g.banish(banish_at)
                continue
            var take = 0
            var take_value = -1.0
            for i in 0..g.offer_count:
                let v = filler(&g, r, g.offers[i].pick)
                if v > take_value:
                    take_value = v
                    take = i
            g.choose(take)
    Outcome { merged: merged_at >= 0.0, minute: if merged_at >= 0.0: merged_at / 60.0 else: g.minute(), level: g.level, cleared: g.cleared }

fn main:
    let argv = args()
    let runs = if argv.len() > 1: parse(argv[1]) else: 24
    var picks: Vec[Weapon] = Vec.new()
    for i in BASE_WEAPON_COUNT..WEAPON_COUNT: picks.push(weapon_at(i))
    print(f"merge odds: {runs} runs each, a player chasing one recipe on the ship that starts with it")
    for plan in 0..2:
        let rerolls = if plan == 0: 1 else: 3
        let banishes = if plan == 0: 0 else: 3
        let skips = if plan == 0: 0 else: 2
        print(f"-- rerolls {rerolls}, banishes {banishes}, skips {skips}")
        var all_hits = 0
        var all_runs = 0
        for target in picks:
            let Some(r) = recipe_for(target) else continue
            var hits = 0
            var minutes = 0.0
            var levels = 0
            for seed in 0..runs:
                let o = attempt(r, seed + plan * 1000, rerolls, banishes, skips)
                levels += o.level
                if o.merged:
                    hits += 1
                    minutes += o.minute
            let mean_minute = if hits > 0: minutes / hits as f64 else: 0.0
            let kind = if r.second.is_some(): "union" else: "evolution"
            print(f"{target.name()} ({kind}, {ship_for(r).name()}): {hits}/{runs} = {hits * 100 / runs}%, merged at minute {mean_minute as i32} on average, mean final level {levels / runs}")
            all_hits += hits
            all_runs += runs
        print(f"overall {all_hits * 100 / all_runs}%")
    0
