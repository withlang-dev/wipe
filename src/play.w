// Playtest driver: a scripted player drives the real app (screens, runs,
// boosts, pause, results, shop, collection, save) through the same input
// path as the keyboard and pad, checks invariants every frame, logs what a
// playtester would note, and saves frames at the moments worth looking at.
//
//   WIPE_SAVE_DIR=/tmp/wipe-play ./out/bin/play [runs]
use c_import("raylib.h")
use std.process.env
use std.process.args
use std.string.parse
use game
use tuning
use loadout
use ships
use save
use account
use input
use presentation
use app

const DT: f64 = 1.0 / 60.0

// What the scripted player is doing across frames.
type Player {
    rng: u32 = 424242,
    wait: f64 = 0.0,           // seconds of "reading" before the next press
    frame: i32 = 0,
    run_frames: i32 = 0,
    paused_once: bool = false,
    boost_seen: i32 = 0,
    shop_visits: i32 = 0,
    collection_visits: i32 = 0,
    ship_rotation: i32 = 0,
    rerolls_used: i32 = 0, skips_used: i32 = 0, banishes_used: i32 = 0,
    abandoned: bool = false, refunded: bool = false,
}
extend Player:
    fn roll(mut self: Self) -> f64:
        self.rng = self.rng *% 1664525 +% 1013904223
        (self.rng % 65536) as f64 / 65535.0

// Combat: keep distance from the closest threats, drift toward cores and
// pickups, stay off the walls, aim at the nearest enemy.
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
    for i in 0..g.pickup_count:
        let d = sub(g.pickups[i].pos, g.player)
        let d2 = length2(d)
        if d2 > 1.0: push = add(push, scale(d, 1.0 / sqrt(d2) * 0.25))
    // Like a player: when nothing is close, go and sweep up the nearest core.
    let threatened = nearest < 200.0 * 200.0
    var core_target = -1
    var core_best = 700.0 * 700.0
    for i in 0..g.core_count:
        let d2 = length2(sub(g.cores[i].pos, g.player))
        if d2 < core_best:
            core_best = d2
            core_target = i
    if core_target >= 0:
        let toward = direction(sub(g.cores[core_target].pos, g.player))
        push = add(push, scale(toward, if threatened: 0.3 else: 1.2))
    push = add(push, scale(sub(g.center(), g.player), 0.0007))
    // The driver speaks screen space for aim, like the mouse.
    Controls { motion: movement(scale(push, 3.0)), aim }

// Card preference: a merge, then weapons it already has, then new weapons,
// then passives that are recipe keys.
fn pick_card(g: &Game) -> i32:
    var best = 0
    var best_score = -1000.0
    for i in 0..g.offer_count:
        let o: Offer = g.offers[i]
        let score = match o.pick:
            .Merge(_) => 100.0
            .UpgradeWeapon(w) => 40.0 + (g.build.weapon_level(w) as f64)
            .NewWeapon(_) => 30.0
            .UpgradePassive(p) => 20.0 + (if p == .Damage or p == .FireRate or p == .Area: 5.0 else: 0.0)
            .NewPassive(p) => 15.0 + (if p == .Health or p == .Magnet: 4.0 else: 0.0)
        if score > best_score:
            best_score = score
            best = i
    best

type Log { lines: Vec[str] }
extend Log:
    fn note(mut self: Self, text: str):
        print(text)
        self.lines.push(text)

fn finite(v: f64) -> bool: v == v and v < 1.0e12 and v > -1.0e12

fn main:
    let argv = args()
    let runs_target = if argv.len() > 1: parse(argv[1]) else: 6
    if env("WIPE_SAVE_DIR").len() == 0:
        eprint("play: set WIPE_SAVE_DIR to a scratch directory")
        return 1
    SetTraceLogLevel(LOG_WARNING)
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | playtest")
    if not IsWindowReady(): return 1
    defer: CloseWindow()
    SetExitKey(KEY_NULL)
    SetTargetFPS(0)
    let renderer = Renderer.open()
    if not renderer.valid(): return 1
    var log_veteran = false
    var wipe = App.open()
    // A veteran account: everything open, so the driver reaches ship select,
    // stages, endless, and every ship.
    if env("WIPE_PLAY_VETERAN") == "1":
        wipe.save.clears = 3
        wipe.save.no_reboot_clear = true
        wipe.save.null_killed = true
        wipe.save.best_combo = 2000
        wipe.save.best_hits_survived = 40
        wipe.save.bounced_kills = 500
        wipe.save.cores = 10000
        wipe.save.best_merges_in_run = 2
        wipe.save.elites = 60
        wipe.save.bosses = 12
        wipe.save.best_level = 40
        wipe.save.kills = 40000
        wipe.save.credits = 6000
        wipe.save.ranks[13] = 3
        wipe.save.ranks[14] = 3
        wipe.save.ranks[15] = 3
        for i in 0..SHIP_COUNT:
            wipe.save.best_time[i] = 1200.0
            wipe.save.cleared[i] = true
        wipe.save.held[0] = 1200.0
        wipe.screen = .Title
        log_veteran = true
    var p = Player {}
    if log_veteran: p.ship_rotation = 1
    var log = Log { lines: Vec.new() }
    var failures = 0
    var worst_tick = 0.0
    var runs_done = 0
    var clock = 0.0
    var over_since = -1.0
    var results_since = -1.0
    var last_screen: Screen = wipe.screen
    var last_level = 0
    var last_boss = false
    // Pacing: level-up times, boost overlays, chained overlays, boss fights.
    var level_times: Vec[f64] = Vec.new()
    var boost_opens = 0
    var boost_seconds = 0.0
    var chained = 0
    var last_boost_close = -10.0
    var was_boost = false
    var boss_started = 0.0
    var boss_fights: Vec[f64] = Vec.new()
    var run_seconds = 0.0
    var caches = 0
    var gap_sum: [f64; 5] = [0.0; 5]
    var gap_count: [i32; 5] = [0; 5]
    var first_level_sum = 0.0
    var first_level_runs = 0
    var shots = 0
    log.note(f"start: screen {screen_name(wipe.screen)} (fresh save launches straight into a run)")
    while runs_done < runs_target and p.frame < 60 * 60 * 200:
        p.frame += 1
        clock += DT
        var m = MenuInput {}
        var continue_shop = true
        var controls = Controls { aim: wipe.game.aim }
        // ----- the player's decision for this frame -----------------------
        if p.wait > 0.0: p.wait -= DT
        else:
            match wipe.screen:
                .Title => {
                    // Look around first: the shop and the collection once each.
                    if p.shop_visits == 0 and wipe.save.credits > 0: m.shop = true
                    else if p.collection_visits == 0 and wipe.save.runs > 0: m.collection = true
                    else: m.confirm = true
                    p.wait = 0.8
                }
                .Select => {
                    // Rotate through unlocked ships, one press at a time.
                    let target = p.ship_rotation % SHIP_COUNT
                    let want = ship_at(target)
                    if not ship_unlocked(want, &wipe.save): p.ship_rotation += 1
                    else if wipe.ship_cursor != target:
                        m.right = true
                        p.wait = 0.15
                    else if log_veteran and p.ship_rotation % 3 == 1 and wipe.stage.index() != (p.ship_rotation / 3) % STAGE_COUNT:
                        m.rb = true
                        p.wait = 0.15
                    else if log_veteran and p.ship_rotation % 4 == 2 and not wipe.endless:
                        m.down = true
                        p.wait = 0.15
                    else:
                        m.confirm = true
                        p.ship_rotation += 1
                        p.wait = 0.5
                }
                .Run => {
                    let g = &wipe.game
                    if g.phase == .Boost:
                        // Read the cards like a person: half a second.
                        if g.cache_reveal > 0.0: m.confirm = (p.roll() < 0.3)
                        else:
                            let r = p.roll()
                            if g.rerolls > 0 and r < 0.10:
                                m.reroll = true
                                p.rerolls_used += 1
                            else if g.skips > 0 and r < 0.14:
                                m.skip = true
                                p.skips_used += 1
                            else if g.banishes > 0 and r < 0.30:
                                // Banish the card under the cursor, as a player would.
                                m.banish = true
                                p.banishes_used += 1
                            else:
                                m.digit = pick_card(g) + 1
                                p.boost_seen += 1
                        p.wait = 0.45
                    else if g.phase == .Running and not p.paused_once and g.elapsed > 30.0:
                        m.start = true
                        p.paused_once = true
                        p.wait = 0.6
                    else: controls = fly(g)
                }
                .Pause => {
                    // Once, abandon the run from here: down to the fourth item, A twice.
                    if runs_done == 2 and not p.abandoned:
                        if wipe.pause_cursor != 3: m.down = true
                        else:
                            m.confirm = true
                            if wipe.confirm_abandon: p.abandoned = true
                        p.wait = 0.2
                    // Nudge the volume once, then resume.
                    else if wipe.pause_cursor == 0 and p.roll() < 0.5:
                        m.down = true
                        p.wait = 0.2
                    else if wipe.pause_cursor == 1:
                        m.left = true
                        m.back = true
                    else: m.confirm = true
                    p.wait = 0.3
                }
                .Results => {
                    // Read for a second and a half, then act.
                    let reading = results_since >= 0.0 and clock - results_since < 1.5
                    if not reading:
                        let affordable = match next_rank(&wipe.save):
                            Some(r) => r.price <= wipe.save.credits
                            None => false
                        if p.collection_visits == 0 and runs_done >= 2: m.collection = true
                        else if affordable and p.shop_visits < runs_done + 1: m.shop = true
                        else if wipe.results.new_ships.len() > 0: m.tab = true
                        else if unlocked_ship_count(&wipe.save) > 1 and runs_done % 2 == 1: m.back = true
                        else: m.confirm = true
                        p.wait = 0.3
                }
                .Shop => {
                    // Once, refund everything (Y asks, Y confirms) and rebuy.
                    if not p.refunded and not log_veteran and wipe.save.spent > 0 and p.shop_visits >= 2:
                        m.collection = true
                        if wipe.confirm_refund:
                            p.refunded = true
                            log.note(f"  shop: refund of {wipe.save.spent}")
                        p.wait = 0.2
                        continue_shop = false
                    // Buy what is affordable at the cursor, walk the list, leave.
                    if continue_shop:
                        let item = shop_item_at(wipe.shop_cursor)
                        let rank = wipe.save.ranks[item.index()]
                        let can_buy = rank < item.max_rank() and item.price(rank) <= wipe.save.credits
                        if can_buy: m.confirm = true
                        else if p.roll() < 0.8: m.down = true
                        else: m.back = true
                        p.wait = 0.2
                }
                .Collection => {
                    if p.roll() < 0.25: m.back = true
                    else if p.roll() < 0.5: m.rb = true
                    else: m.right = true
                    p.wait = 0.25
                }
        // ----- step the real app ------------------------------------------
        let before_credits = wipe.save.credits
        let started = GetTime()
        wipe.step(m, controls, DT)
        let tick_ms = (GetTime() - started) * 1000.0
        if tick_ms > worst_tick and wipe.screen == .Run: worst_tick = tick_ms
        if wipe.screen == .Shop and wipe.save.credits < before_credits:
            log.note(f"  shop: bought for {before_credits - wipe.save.credits}, {wipe.save.credits} left")
        // ----- what a playtester notices ----------------------------------
        if wipe.screen != last_screen:
            if wipe.screen == .Shop: p.shop_visits += 1
            if wipe.screen == .Collection: p.collection_visits += 1
            if wipe.screen == .Results and (last_screen == .Run or last_screen == .Pause):
                results_since = clock
                runs_done += 1
                let r = &wipe.results
                let delay = if over_since >= 0.0: clock - over_since else: 0.0
                log.note(f"run {runs_done}: {r.ship.name()} on {r.stage.name()}, {stamp(r.elapsed)}, level {r.level}, kills {r.kills}, combo x{r.best_combo}, +{r.earned} credits (bank {r.bank}); {r.cause}; results after {(delay * 1000.0) as i32} ms")
                if delay > 0.7:
                    failures += 1
                    log.note(f"  FAIL: results took {(delay * 1000.0) as i32} ms after death (spec: half a second)")
                if r.new_ships.len() > 0: log.note(f"  new ship: {r.new_ships[0].name()}")
                for u in r.unlocks: log.note(f"  unlocked: {u}")
                over_since = -1.0
            if wipe.screen == .Run and last_screen != .Pause:
                p.paused_once = false
                level_times = Vec.new()
                last_boss = false
                let mode = if wipe.game.launch.endless: " ENDLESS" else: ""
                log.note(f"  launch: {wipe.game.launch.ship.name()} on {wipe.stage.name()}{mode}, best to beat {stamp(wipe.game.launch.best_time)}")
                last_level = wipe.game.level
            last_screen = wipe.screen
        if wipe.screen == .Run:
            let g = &wipe.game
            let boosting = g.phase == .Boost
            if boosting:
                boost_seconds += DT
                if not was_boost:
                    boost_opens += 1
                    // Another overlay within half a second of the last one closing.
                    if clock - last_boost_close < 0.5: chained += 1
                    if g.boost_source == .LevelUp:
                        let t: f64 = g.elapsed
                        if level_times.len() == 0:
                            first_level_sum += t
                            first_level_runs += 1
                        else:
                            let gap = t - level_times[level_times.len() - 1]
                            let band = if t < 120.0: 0 else if t < 300.0: 1 else if t < 600.0: 2 else if t < 900.0: 3 else: 4
                            gap_sum[band] += gap
                            gap_count[band] += 1
                        level_times.push(t)
                    else: caches += 1
            else if was_boost: last_boost_close = clock
            was_boost = boosting
            if g.phase == .Running: run_seconds += DT
            if g.boss_alive and not last_boss: boss_started = g.elapsed
            if not g.boss_alive and last_boss and g.bosses_killed > 0: boss_fights.push(g.elapsed - boss_started)
            if g.phase == .Over and over_since < 0.0: over_since = clock
            if g.level > last_level and g.phase == .Boost:
                if g.level <= 3 or g.level % 10 == 0: log.note(f"    level {g.level} at {stamp(g.elapsed)}")
                last_level = g.level
            if g.boss_alive and not last_boss: log.note(f"    boss at {stamp(g.elapsed)}, {g.enemy_count} enemies")
            if not g.boss_alive and last_boss and g.bosses_killed > 0: log.note(f"    boss down at {stamp(g.elapsed)}")
            last_boss = g.boss_alive
            if g.merge_event: log.note(f"    merge at {stamp(g.elapsed)}")
            if g.best_event: log.note(f"    passed the best time at {stamp(g.elapsed)}")
            if g.null_alive and g.boss_event: log.note(f"    the Null at {stamp(g.elapsed)}")
            // Invariants.
            var broken = ""
            if not finite(g.player.x) or not finite(g.player.y): broken = "player position not finite"
            else if not g.in_arena(g.player, 0.5): broken = "player outside the arena"
            else if g.health > g.max_health: broken = f"health {g.health} above max {g.max_health}"
            else if g.phase != .Over and g.health <= 0: broken = "alive with no health"
            else if g.enemy_count < 0 or g.enemy_count > ENEMY_CAP: broken = "enemy count out of range"
            else if g.phase == .Boost and g.offer_count <= 0: broken = "boost with no cards"
            else if g.xp < 0: broken = "negative xp"
            for i in 0..g.enemy_count:
                if not finite(g.enemies[i].pos.x) or not finite(g.enemies[i].pos.y): broken = "enemy position not finite"
            if broken.len() > 0:
                failures += 1
                log.note(f"  FAIL at {stamp(g.elapsed)}: {broken}")
            if g.phase == .Over and over_since >= 0.0 and clock - over_since > 2.0:
                failures += 1
                log.note("  FAIL: stuck on a finished run for two seconds")
                over_since = clock
        if wipe.save.credits < 0:
            failures += 1
            log.note("  FAIL: negative credits")
        // ----- look at it -------------------------------------------------
        // Every screen change, and a frame every twenty seconds of play.
        let interesting = (wipe.screen == .Run and p.frame % (60 * 20) == 0) or (wipe.screen != .Run and p.frame % 90 == 0 and shots < 400)
        if interesting or p.frame % 6 == 0:
            let _ = wipe.draw(&renderer, clock)
        if interesting and shots < 400:
            let _ = wipe.draw(&renderer, clock)
            let name = f"out/play/{shots:03}-{screen_name(wipe.screen)}.png"
            TakeScreenshot(name)
            shots += 1
    log.note("pacing:")
    if first_level_runs > 0: log.note(f"  first level-up: mean {(first_level_sum / first_level_runs as f64) as i32} s into a run")
    let bands = ["0-2 min", "2-5 min", "5-10 min", "10-15 min", "15-20 min"]
    for b in 0..5:
        if gap_count[b] > 0: log.note(f"  level-up gap {bands[b]}: mean {(gap_sum[b] / gap_count[b] as f64) as i32} s over {gap_count[b]} level-ups")
    let share = if run_seconds > 0.0: boost_seconds * 100.0 / (run_seconds + boost_seconds) else: 0.0
    log.note(f"  card overlays: {boost_opens}, {chained} opened within half a second of the last, {share as i32}% of run time spent choosing, caches {caches}")
    var fight_total = 0.0
    for f in boss_fights: fight_total += f
    if boss_fights.len() > 0: log.note(f"  boss fights: {boss_fights.len()}, mean {(fight_total / boss_fights.len() as f64) as i32} s")
    log.note(f"playtest: {runs_done} runs, {p.frame / 60} s of play, {p.boost_seen} cards taken, rerolls {p.rerolls_used}, skips {p.skips_used}, banishes {p.banishes_used}, shop visits {p.shop_visits}, collection visits {p.collection_visits}")
    let worst_hundredths = (worst_tick * 100.0) as i32
    log.note(f"worst app step during a run: {worst_hundredths / 100}.{worst_hundredths % 100} ms")
    log.note(f"save: {wipe.save.runs} runs, {wipe.save.credits} credits, {wipe.save.spent} spent, {unlocked_ship_count(&wipe.save)} ships")
    if log_veteran and (p.skips_used == 0 or p.banishes_used == 0 or p.rerolls_used == 0):
        failures += 1
        log.note("  FAIL: reroll, skip, or banish never exercised")
    if not p.abandoned:
        failures += 1
        log.note("  FAIL: the abandon flow never completed")
    log.note(f"abandoned a run: {p.abandoned}; refunded: {p.refunded}")
    log.note(f"failures: {failures}")
    let code = if failures > 0: 1 else: 0
    return code

fn screen_name(s: Screen) -> str:
    match s:
        .Title => "title"
        .Select => "select"
        .Run => "run"
        .Pause => "pause"
        .Results => "results"
        .Shop => "shop"
        .Collection => "collection"
