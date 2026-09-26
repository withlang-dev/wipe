use c_import("raylib.h")
use game
use tuning
use loadout
use ships
use save
use account
use input
use presentation

// The screens of spec §11. One confirm, one back, everywhere.
pub enum Screen { | Title | Select | Run | Pause | Results | Shop | Collection }
impl Copy for Screen
impl Eq for Screen

pub enum Tab { | Ships | Weapons | Passives | Merges | Registry | Stages }
impl Copy for Tab
impl Eq for Tab
pub const TAB_COUNT: i32 = 6
fn tab_at(i: i32) -> Tab:
    match i:
        0 => .Ships
        1 => .Weapons
        2 => .Passives
        3 => .Merges
        4 => .Registry
        _ => .Stages
extend Tab:
    fn index(self: &Self) -> i32:
        match self:
            .Ships => 0
            .Weapons => 1
            .Passives => 2
            .Merges => 3
            .Registry => 4
            .Stages => 5
    fn name(self: &Self) -> str:
        match self:
            .Ships => "SHIPS"
            .Weapons => "WEAPONS"
            .Passives => "PASSIVES"
            .Merges => "MERGES"
            .Registry => "REGISTRY"
            .Stages => "STAGES"
    fn count(self: &Self) -> i32:
        match self:
            .Ships => SHIP_COUNT
            .Weapons => BASE_WEAPON_COUNT
            .Passives => PASSIVE_COUNT
            .Merges => RECIPE_COUNT
            .Registry => KIND_COUNT
            .Stages => STAGE_COUNT

// What the results screen shows, captured once when the run ends.
pub type ResultsView {
    ship: Ship = .Claw, stage: Stage = .Field,
    cleared: bool = false, endless: bool = false,
    elapsed: f64 = 0.0, previous_best: f64 = 0.0, new_best: bool = false,
    cause: str = "",
    level: i32 = 1, best_combo: i32 = 0, kills: i32 = 0,
    kills_by_kind: [i32; 8] = [0; 8],
    build: Build = Build {},
    earned: i32 = 0, bank: i32 = 0,
    next_unlock: Option[NextUnlock] = None,
    next_rank: Option[NextRank] = None,
    bar: f64 = 0.0,
    merge: Option[(Weapon, i32)] = None,
    new_ships: Vec[Ship],
    unlocks: Vec[str],
    shown: f64 = 0.0,
}

pub type App {
    screen: Screen = .Title, return_to: Screen = .Title,
    save: Save = Save {}, file: SaveFile, notice: LoadNotice = .Fresh, notice_timer: f64 = 6.0,
    game: Game, attract: Game, attract_frame: i32 = 0,
    ship: Ship = .Claw, stage: Stage = .Field, endless: bool = false,
    ship_cursor: i32 = 0, stage_cursor: i32 = 0,
    boost_cursor: i32 = 0, pause_cursor: i32 = 0, confirm_abandon: bool = false,
    shop_cursor: i32 = 0, shop_by_price: bool = false, confirm_refund: bool = false, shop_flash: f64 = 0.0,
    tab: Tab = .Ships, collection_cursor: i32 = 0,
    results: ResultsView,
    metrics: Metrics,
    death_timer: f64 = 0.0,
    quit: bool = false, quit_hold: f64 = 0.0,
    input: Input = Input {}, menu: MenuState = MenuState {},
    debug: bool = false, frame_ms: f64 = 16.67,
    // Presentation sound cues for the audio layer.
    ui_move: bool = false, ui_confirm: bool = false, ui_buy: bool = false,
}

pub fn App.open() -> App:
    var file = SaveFile.open()
    let (save, notice) = file.load()
    var app = App {
        file, save, notice,
        game: Game.new(), attract: Game.new(),
        results: ResultsView { new_ships: Vec.new(), unlocks: Vec.new() },
        metrics: Metrics.new(),
    }
    app.ship = ship_at(limit(save.last_ship as f64, 0.0, (SHIP_COUNT - 1) as f64) as i32)
    if not ship_unlocked(app.ship, &app.save): app.ship = .Claw
    app.ship_cursor = app.ship.index()
    app.input.deadzone = save.deadzone
    // The attract simulation is the real game with a scripted pilot.
    app.attract.rules.contact_radius = 0.0
    app.attract.rng = 987654
    // A fresh save launches straight into the Claw: no menus before the first run.
    if app.notice == .Fresh: app.launch()
    app

// The attract pilot: circles the arena center and aims at the nearest enemy.
fn pilot(g: &Game, frame: i32) -> Controls:
    let t = frame as f64 / 60.0
    let c = g.center()
    let goal = V2 { x: c.x + cos(t * 0.5) * 420.0, y: c.y + sin(t * 0.5) * 300.0 }
    var aim = V2 { x: cos(t * 2.3), y: sin(t * 2.3) }
    var nearest = 1.0e12
    for e in 0..g.enemy_count:
        let delta = sub(g.enemies[e].pos, g.player)
        if length2(delta) < nearest:
            nearest = length2(delta)
            aim = delta
    Controls { motion: scale(sub(goal, g.player), 1.0 / 70.0), aim }

fn wrap(value: i32, count: i32) -> i32:
    if count <= 0: 0 else: ((value % count) + count) % count

extend App:
    fn persist(mut self: Self):
        if not self.file.store(&self.save) and not self.file.read_only:
            eprint(f"WIPE could not write its save at {self.file.path}")

    fn go(mut self: Self, screen: Screen):
        if screen == .Shop or screen == .Collection:
            if self.screen != .Shop and self.screen != .Collection: self.return_to = self.screen
        self.screen = screen
        self.ui_confirm = true
        if screen == .Shop: self.shop_cursor = self.default_shop_cursor()
        if screen == .Select: self.ship_cursor = self.ship.index()

    pub fn launch(mut self: Self):
        self.launch_as(self.ship)

    pub fn launch_as(mut self: Self, ship: Ship):
        self.ship = ship
        if self.save.last_ship != ship.index():
            self.save.last_ship = ship.index()
            self.persist()
        let endless = self.endless and self.save.cleared[ship.index()]
        let rules = self.stage.rules()
        self.game.rules = rules
        self.game.rng = 1234567 +% (self.save.runs as u32) *% 2654435761
        self.game.start(launch_for(ship, &self.save, endless))
        self.screen = .Run
        self.boost_cursor = 0
        self.death_timer = 0.0

    // Bank the run, star the bests, compute the open loops, save at once.
    pub fn finish_run(mut self: Self):
        let before: Save = self.save
        let previous = if self.game.launch.endless: before.best_endless[self.ship.index()] else: before.best_time[self.ship.index()]
        let (after, new_best) = record_run(before, &self.game)
        self.save = after
        self.persist()
        let g = &self.game
        let killer = match g.killer:
            Some(kind) => {
                let who = if kind == .Null: "the Null" else if g.killer_elite: f"an elite {kind.name()}" else: f"a {kind.name()}"
                f"Wiped by {who} at {g.health_before} health, minute {(g.elapsed / 60.0) as i32}"
            }
            None => if g.null_killed: "The Null is down. You ended what ends the run." else: "Run abandoned"
        let cause = if g.cleared and not g.null_killed: "Cleared. The Null ended the run at 20:00" else: killer
        let unlock = next_unlock(&self.save)
        let rank = next_rank(&self.save)
        self.results = ResultsView {
            ship: self.ship, stage: self.stage,
            cleared: g.cleared, endless: g.launch.endless,
            elapsed: g.elapsed, previous_best: previous, new_best,
            cause,
            level: g.level, best_combo: g.best_combo, kills: g.kills,
            kills_by_kind: g.kills_by_kind,
            build: g.build,
            earned: g.credits, bank: self.save.credits,
            next_unlock: unlock,
            next_rank: rank,
            bar: limit(g.xp as f64 / g.xp_next as f64, 0.0, 1.0),
            // A merge is a near miss only when it was near: three levels or fewer.
            merge: match g.build.nearest_recipe():
                Some((w, d)) => if g.launch.ship.can_merge() and d <= 3: Some((w, d)) else: None
                None => None,
            new_ships: new_ships(&before, &self.save),
            unlocks: new_unlocks(&before, &self.save),
            shown: GetTime(),
        }
        let unlock_fraction = match &self.results.next_unlock:
            Some(u) => u.fraction
            None => 0.0
        let shop_fraction = match rank:
            Some(r) => limit(self.save.credits as f64 / r.price as f64, 0.0, 1.0)
            None => 0.0
        self.metrics.record(self.game.elapsed, unlock_fraction, shop_fraction)
        self.screen = .Results

    fn retry(mut self: Self, ship: Ship):
        if GetTime() - self.results.shown < 3.0: self.metrics.quick_retries += 1
        self.launch_as(ship)

    fn default_shop_cursor(self: &Self) -> i32:
        // The cheapest affordable row, or the closest unaffordable one.
        var best = 0
        var best_price = 2147483647
        var closest = 0
        var closest_gap = 2147483647
        for row in 0..SHOP_COUNT:
            let item = self.shop_row(row)
            let rank = self.save.ranks[item.index()]
            if rank >= item.max_rank(): continue
            let price = item.price(rank)
            if price <= self.save.credits and price < best_price:
                best_price = price
                best = row
            if price - self.save.credits < closest_gap:
                closest_gap = price - self.save.credits
                closest = row
        if best_price < 2147483647: best else: closest

    // Shop rows in display order: by category, or by next price.
    fn shop_row(self: &Self, row: i32) -> ShopItem:
        if not self.shop_by_price: return shop_item_at(row)
        var order: [i32; 16] = [0; 16]
        for i in 0..SHOP_COUNT: order[i] = i
        for i in 1..SHOP_COUNT:
            var j = i
            while j > 0 and self.sort_key(order[j - 1]) > self.sort_key(order[j]):
                let t: i32 = order[j]
                order[j] = order[j - 1]
                order[j - 1] = t
                j -= 1
        shop_item_at(order[row])
    fn sort_key(self: &Self, index: i32) -> i32:
        let item = shop_item_at(index)
        let rank = self.save.ranks[index]
        if rank >= item.max_rank(): 1000000000 else: item.price(rank)

    fn buy(mut self: Self):
        let item = self.shop_row(self.shop_cursor)
        let i = item.index()
        let rank = self.save.ranks[i]
        if rank >= item.max_rank(): return
        let price = item.price(rank)
        if price > self.save.credits: return
        self.save.credits -= price
        self.save.spent += price
        self.save.ranks[i] += 1
        self.shop_flash = 0.4
        self.ui_buy = true
        self.persist()

    fn refund(mut self: Self):
        self.save.credits += self.save.spent
        self.save.spent = 0
        for i in 0..SHOP_COUNT: self.save.ranks[i] = 0
        self.ui_buy = true
        self.persist()

    // ----- update -------------------------------------------------------------

    pub fn update(mut self: Self, pad: PadFrame, dt: f64):
        self.ui_move = false
        self.ui_confirm = false
        self.ui_buy = false
        let m = self.menu.sample(pad)
        self.notice_timer = limit(self.notice_timer - dt, 0.0, 10.0)
        self.shop_flash = limit(self.shop_flash - dt, 0.0, 1.0)
        if IsKeyPressed(KEY_F1): self.debug = not self.debug
        match self.screen:
            .Title => self.update_title(m, dt)
            .Select => self.update_select(m)
            .Run => self.update_run(m, pad, dt)
            .Pause => self.update_pause(m)
            .Results => self.update_results(m)
            .Shop => self.update_shop(m)
            .Collection => self.update_collection(m)
        if self.screen == .Title or self.screen == .Select or self.screen == .Shop or self.screen == .Collection:
            // The attract simulation keeps flying behind the menus.
            self.attract_frame += 1
            let controls = pilot(&self.attract, self.attract_frame)
            self.attract.clear_events()
            self.attract.tick(controls, dt)
            self.attract.tick(controls, 0.0)
            if self.attract.phase == .Boost: self.attract.choose(0)
            if self.attract.minute() > 6.0 or self.attract.phase == .Over: self.attract.reset()

    fn update_title(mut self: Self, m: MenuInput, dt: f64):
        if m.confirm:
            if unlocked_ship_count(&self.save) > 1 or stage_unlocked(.Corridor, &self.save): self.go(.Select)
            else: self.launch_as(.Claw)
        else if m.shop: self.go(.Shop)
        else if m.collection: self.go(.Collection)
        else if IsKeyPressed(KEY_ESCAPE): self.quit = true
        // On a pad, quitting is a one second hold of B.
        if m.back_held and not IsKeyDown(KEY_ESCAPE):
            self.quit_hold += dt
            if self.quit_hold >= 1.0: self.quit = true
        else: self.quit_hold = 0.0
        if m.click:
            if inside(m.mouse, 520, 430, 240, 40): self.update_title(MenuInput { confirm: true }, 0.0)
            else if inside(m.mouse, 470, 480, 150, 30): self.go(.Shop)
            else if inside(m.mouse, 660, 480, 180, 30): self.go(.Collection)

    fn update_select(mut self: Self, m: MenuInput):
        if m.left or m.right:
            self.ship_cursor = wrap(self.ship_cursor + (if m.right: 1 else: -1), SHIP_COUNT)
            self.ui_move = true
        let cursor_ship = ship_at(self.ship_cursor)
        if m.lb or m.rb:
            var next = self.stage.index()
            for _ in 0..STAGE_COUNT:
                next = wrap(next + (if m.rb: 1 else: -1), STAGE_COUNT)
                if stage_unlocked(stage_at(next), &self.save): break
            self.stage = stage_at(next)
            self.ui_move = true
        if (m.up or m.down) and self.save.cleared[cursor_ship.index()]:
            self.endless = not self.endless
            self.ui_move = true
        if m.click:
            for i in 0..SHIP_COUNT:
                let (x, y) = select_card_origin(i)
                if inside(m.mouse, x, y, 112, 112):
                    if self.ship_cursor == i and ship_unlocked(ship_at(i), &self.save): self.launch_as(ship_at(i))
                    self.ship_cursor = i
                    return
        if m.confirm and ship_unlocked(cursor_ship, &self.save): self.launch_as(cursor_ship)
        else if m.back: self.go(.Title)
        else if m.shop: self.go(.Shop)
        else if m.collection: self.go(.Collection)

    fn update_run(mut self: Self, m: MenuInput, pad: PadFrame, dt: f64):
        let g = &self.game
        if g.phase == .Boost:
            self.update_boost(m)
        else if m.start and g.phase == .Running:
            self.screen = .Pause
            self.pause_cursor = 0
            self.confirm_abandon = false
            return
        // Aim is resolved against the ship's position on screen.
        let screen_player = sub(self.game.player, self.game.view_origin())
        let controls = self.input.sample(screen_player, self.game.aim, pad)
        self.game.clear_events()
        var steps = 0
        var accumulator = limit(dt, 0.0, 0.1)
        while accumulator >= 1.0 / 120.0 - 0.00001:
            self.game.tick(controls, 1.0 / 120.0)
            accumulator -= 1.0 / 120.0
            steps += 1
        if steps == 0: self.game.tick(controls, 0.0)
        if self.game.phase == .Over:
            self.death_timer += dt
            // The death burst gets its moment; any press skips it.
            if self.death_timer >= 0.5 or (self.death_timer > 0.15 and m.confirm): self.finish_run()

    fn update_boost(mut self: Self, m: MenuInput):
        let count = self.game.offer_count
        if self.game.cache_reveal > 0.0:
            if m.confirm: self.game.cache_reveal = 0.0
            return
        if m.left or m.right:
            self.boost_cursor = wrap(self.boost_cursor + (if m.right: 1 else: -1), count)
            self.ui_move = true
        if m.mouse_moved or m.click:
            for i in 0..count:
                let (x, y, w, h) = boost_card_rect(i, count)
                if inside(m.mouse, x, y, w, h):
                    self.boost_cursor = i
                    if m.click: self.take(i)
                    return
        if m.digit > 0 and m.digit <= count: self.take(m.digit - 1)
        else if m.confirm: self.take(self.boost_cursor)
        else if m.reroll: self.game.reroll()
        else if m.skip: self.game.skip()
        else if m.banish: self.game.banish(self.boost_cursor)
        if self.boost_cursor >= self.game.offer_count: self.boost_cursor = 0

    fn take(mut self: Self, index: i32):
        self.game.choose(index)
        self.boost_cursor = 0
        self.ui_confirm = true

    fn update_pause(mut self: Self, m: MenuInput):
        let items = 5
        if m.up or m.down:
            self.pause_cursor = wrap(self.pause_cursor + (if m.down: 1 else: -1), items)
            self.confirm_abandon = false
            self.ui_move = true
        if m.left or m.right:
            let step = if m.right: 0.1 else: -0.1
            if self.pause_cursor == 1: self.save.volume = limit(self.save.volume + step, 0.0, 1.0)
            if self.pause_cursor == 2:
                self.save.deadzone = limit(self.save.deadzone + step * 0.5, 0.05, 0.5)
                self.input.deadzone = self.save.deadzone
            self.ui_move = true
        if m.back or m.start:
            self.persist()
            self.screen = .Run
            return
        if m.confirm:
            match self.pause_cursor:
                0 => {
                    self.persist()
                    self.screen = .Run
                }
                3 => {
                    if self.confirm_abandon:
                        // Abandoning banks what the run earned so far.
                        self.game.phase = .Over
                        self.finish_run()
                    else: self.confirm_abandon = true
                }
                4 => {
                    self.persist()
                    self.game.phase = .Over
                    self.finish_run()
                    self.go(.Title)
                }
                _ => ()

    fn update_results(mut self: Self, m: MenuInput):
        if m.confirm: self.retry(self.results.ship)
        else if m.tab and self.results.new_ships.len() > 0: self.retry(self.results.new_ships[0])
        else if m.back: self.go(.Select)
        else if m.shop: self.go(.Shop)
        else if m.collection: self.go(.Collection)
        else if m.click:
            if inside(m.mouse, 200, 720, 200, 40): self.retry(self.results.ship)
            else if inside(m.mouse, 420, 720, 200, 40): self.go(.Select)
            else if inside(m.mouse, 640, 720, 200, 40): self.go(.Shop)
            else if inside(m.mouse, 860, 720, 220, 40): self.go(.Collection)

    fn update_shop(mut self: Self, m: MenuInput):
        if m.up or m.down:
            self.shop_cursor = wrap(self.shop_cursor + (if m.down: 1 else: -1), SHOP_COUNT)
            self.confirm_refund = false
            self.ui_move = true
        if m.lb or m.rb:
            let current = self.shop_row(self.shop_cursor)
            self.shop_by_price = not self.shop_by_price
            for row in 0..SHOP_COUNT:
                if self.shop_row(row) == current: self.shop_cursor = row
        if m.click or m.mouse_moved:
            for row in 0..SHOP_COUNT:
                if inside(m.mouse, 80, 110 + row * 30, 780, 28):
                    self.shop_cursor = row
                    if m.click: self.buy()
        if m.confirm: self.buy()
        else if m.collection:
            // Y is refund here: it asks once.
            if self.confirm_refund:
                self.refund()
                self.confirm_refund = false
            else if self.save.spent > 0: self.confirm_refund = true
        else if m.back: self.go(self.return_to)

    fn update_collection(mut self: Self, m: MenuInput):
        if m.lb or m.rb:
            self.tab = tab_at(wrap(self.tab.index() + (if m.rb: 1 else: -1), TAB_COUNT))
            self.collection_cursor = 0
            self.ui_move = true
        let count = self.tab.count()
        if m.left or m.right:
            self.collection_cursor = wrap(self.collection_cursor + (if m.right: 1 else: -1), count)
            self.ui_move = true
        if m.up or m.down:
            self.collection_cursor = limit((self.collection_cursor + (if m.down: 5 else: -5)) as f64, 0.0, (count - 1) as f64) as i32
            self.ui_move = true
        if m.click:
            for t in 0..TAB_COUNT:
                if inside(m.mouse, 60 + t * 130, 70, 120, 28): self.tab = tab_at(t)
            for i in 0..count:
                let (x, y) = collection_card_origin(i)
                if inside(m.mouse, x, y, 140, 104): self.collection_cursor = i
        if m.back: self.go(self.return_to)

    // ----- draw -----------------------------------------------------------------

    pub fn draw(self: &Self, renderer: &Renderer, clock: f64) -> f64:
        match self.screen:
            .Run => {
                let cam = renderer.begin_world(&self.game, clock, 1.0)
                let hud = Hud { best_time: self.game.launch.best_time, bank: self.save.credits }
                let info = self.debug_info()
                renderer.draw_run(&self.game, cam, hud, self.boost_cursor, clock, if self.debug: Some(&info) else: None)
            }
            .Pause => {
                let cam = renderer.begin_world(&self.game, clock, 1.0)
                let hud = Hud { best_time: self.game.launch.best_time, bank: self.save.credits, show_hints: false }
                renderer.draw_run(&self.game, cam, hud, self.boost_cursor, clock, None)
                self.draw_pause()
            }
            .Results => {
                let _ = renderer.begin_world(&self.game, clock, 0.12)
                self.draw_results(clock)
            }
            _ => {
                let _ = renderer.begin_world(&self.attract, clock, 0.3)
                match self.screen:
                    .Title => self.draw_title(clock)
                    .Select => self.draw_select(clock)
                    .Shop => self.draw_shop(clock)
                    .Collection => self.draw_collection(clock)
                    _ => ()
                if self.debug:
                    let info = self.debug_info()
                    DrawRectangle(40, 96, 340, 30 + info.metrics.len() as i32 * 18, ink(0.94))
                    var y = 106
                    for line_text in info.metrics:
                        label(line_text.clone(), 55, y, 12, lime(0.8))
                        y += 18
                    label(f"SAVE {info.save_path}", 55, y, 10, white(0.45))
            }
        renderer.present()

    fn debug_info(self: &Self) -> DebugInfo:
        DebugInfo { frame_ms: self.frame_ms, save_path: self.file.path.clone(), metrics: self.metrics.lines() }

    fn credits_corner(self: &Self):
        neon_right(commas(self.save.credits), 1250, 24, 28, gold(1.0))
        label("CREDITS", 1250 - MeasureText("CREDITS", 10), 56, 10, gold(0.6))

    fn notice_line(self: &Self):
        if self.notice_timer <= 0.0: return
        let text = match self.notice:
            .Restored => "Your save could not be read; the backup was restored."
            .SetAside => "Your save could not be read and was set aside beside the new one. Starting fresh."
            .TooNew(v) => f"This save was written by a newer WIPE (format {v}). Progress will not be saved."
            _ => ""
        if text.len() > 0: centered(text, 740, 14, magenta(limit(self.notice_timer, 0.0, 1.0)))

    fn draw_title(self: &Self, clock: f64):
        centered("W I P E : S U R V I V A L", 190, 54, cyan(1.0))
        draw_ship(.Claw, V2 { x: 640.0, y: 330.0 }, V2 { x: cos(clock * 0.6), y: sin(clock * 0.6) }, 1.0, 3.2)
        centered("[A / SPACE]  LAUNCH", 440, 22, white(0.7 + 0.3 * sin(clock * 3.0)))
        neon("[X]  SHOP", 480, 486, 16, gold(0.9))
        neon("[Y / C]  COLLECTION", 660, 486, 16, lime(0.9))
        var best = 0.0
        for i in 0..SHIP_COUNT:
            if self.save.best_time[i] > best: best = self.save.best_time[i]
        let footer = f"BEST {stamp(best)}   ·   RUNS {commas(self.save.runs)}   ·   KILLS {commas(self.save.kills)}   ·   CREDITS {commas(self.save.credits)}   ·   v0.2"
        centered(footer, 690, 14, white(0.55))
        centered("ESC  QUIT     HOLD B ON A CONTROLLER", 716, 10, white(0.3))
        if self.quit_hold > 0.0: DrawRectangle(540, 734, (200.0 * self.quit_hold) as i32, 3, magenta(0.9))
        self.notice_line()

    fn draw_select(self: &Self, clock: f64):
        neon("SELECT SHIP", 40, 24, 30, cyan(1.0))
        self.credits_corner()
        if stage_unlocked(.Corridor, &self.save):
            neon(f"STAGE  {self.stage.name()}", 40, 64, 16, magenta(1.0))
            label("[LB / RB]", 40 + MeasureText(f"STAGE  {self.stage.name()}", 16) + 12, 67, 10, white(0.5))
        for i in 0..SHIP_COUNT:
            let ship = ship_at(i)
            let (x, y) = select_card_origin(i)
            let unlocked = ship_unlocked(ship, &self.save)
            let selected = i == self.ship_cursor
            DrawRectangle(x, y, 112, 112, ink(0.9))
            DrawRectangleLinesEx(Rectangle { x: x as f32, y: y as f32, width: 112.0, height: 112.0 }, if selected: 3.0 else: 1.0, if selected: white(1.0) else: cyan(0.35))
            let center = V2 { x: (x + 56) as f64, y: (y + 48) as f64 }
            if unlocked:
                draw_ship(ship, center, V2 { x: 0.0, y: -1.0 }, 1.0, 1.9)
                centered_at(ship.name().to_upper(), x + 56, y + 88, 14, white(1.0))
            else:
                draw_ship(ship, center, V2 { x: 0.0, y: -1.0 }, 0.18, 1.9)
                centered_at(if ship.secret(): "?" else: "LOCKED", x + 56, y + 88, 12, white(0.35))
        let ship = ship_at(self.ship_cursor)
        let unlocked = ship_unlocked(ship, &self.save)
        // The detail panel: the ship's card.
        panel(80, 270, 440, 360, if unlocked: cyan(1.0) else: white(0.3))
        draw_ship(ship, V2 { x: 300.0, y: 450.0 }, V2 { x: cos(clock * 0.8), y: sin(clock * 0.8) }, if unlocked: 1.0 else: 0.2, 5.0)
        let x = 560
        neon(ship.name().to_upper(), x, 274, 36, white(1.0))
        if unlocked:
            label("BASE WEAPON", x, 330, 12, white(0.5))
            neon(ship.base_weapon().name(), x + 150, 326, 18, gold(1.0))
            label("STRENGTH", x, 364, 12, white(0.5))
            label(ship.strength(), x + 150, 362, 16, lime(1.0))
            label("GROWTH", x, 394, 12, white(0.5))
            label(ship.growth(), x + 150, 392, 16, cyan(1.0))
            label("WEAKNESS", x, 424, 12, white(0.5))
            label(ship.weakness(), x + 150, 422, 16, magenta(1.0))
            let best = self.save.best_time[ship.index()]
            label(f"BEST  {stamp(best)}     RUNS  {self.save.ship_runs[ship.index()]}", x, 470, 16, white(0.75))
            let cleared: bool = self.save.cleared[ship.index()]
            if cleared:
                let mode = if self.endless: "ENDLESS" else: "20:00 RUN"
                neon(f"MODE  {mode}", x, 510, 18, if self.endless: magenta(1.0) else: white(0.9))
                label("[UP / DOWN] TOGGLE", x + 220, 514, 10, white(0.5))
                if self.endless: label(f"BEST ENDLESS  {stamp(self.save.best_endless[ship.index()])}", x, 540, 14, magenta(0.8))
        else:
            let c = ship.condition()
            label("LOCKED", x, 330, 14, white(0.5))
            let text = if ship.secret(): f"Hint: \"{c.describe()}\"" else: c.describe()
            label(text, x, 360, 18, white(1.0))
            let f = fraction(c, &self.save)
            if not ship.secret() or self.save.clears > 0:
                DrawRectangle(x, 400, 400, 8, white(0.15))
                DrawRectangle(x, 400, (400.0 * f) as i32, 8, gold(0.9))
                label(f"{(f * 100.0) as i32}%", x + 410, 398, 12, gold(0.9))
        let controls = "[A] LAUNCH     [B] BACK     [X] SHOP     [Y] COLLECTION"
        centered(controls, 690, 14, white(0.7))

    fn draw_pause(self: &Self):
        DrawRectangle(0, 0, WIDTH, HEIGHT, ink(0.6))
        panel(440, 220, 400, 330, cyan(1.0))
        centered("PAUSED", 240, 30, cyan(1.0))
        let vol = (self.save.volume * 100.0 + 0.5) as i32
        let dz = (self.save.deadzone * 100.0 + 0.5) as i32
        let abandon = if self.confirm_abandon: "ABANDON RUN? PRESS A AGAIN" else: "ABANDON RUN (BANKS CREDITS)"
        let items = ["RESUME", f"VOLUME  < {vol}% >", f"DEADZONE  < {dz}% >", abandon, "QUIT TO TITLE"]
        for i in 0..5:
            let selected = i == self.pause_cursor
            centered(items[i].clone(), 300 + i * 44, 20, if selected: white(1.0) else: white(0.45))
            if selected: DrawRectangle(470, 300 + i * 44 + 26, 340, 2, cyan(0.8))
        centered("[B / START] RESUME", 520, 12, white(0.5))

    fn draw_results(self: &Self, clock: f64):
        let r = &self.results
        let t = GetTime() - r.shown
        let title = if r.cleared: "CLEARED" else if r.endless: "ENDLESS OVER" else: "RUN OVER"
        neon(title, 60, 28, 34, if r.cleared: gold(1.0) else: magenta(1.0))
        // Credits count up into the bank with the delta pinned beside it.
        let counting = limit(t / 0.8, 0.0, 1.0)
        let shown_bank = r.bank - r.earned + (r.earned as f64 * counting) as i32
        neon_right(commas(shown_bank), 1240, 24, 30, gold(1.0))
        neon_right(f"+{commas(r.earned)} THIS RUN", 1240, 58, 14, gold(0.9))
        label("BANKED", 1240 - MeasureText("BANKED", 10), 78, 10, gold(0.6))
        // The near miss first and largest.
        let delta_line = if r.new_best and r.previous_best <= 0.0: f"SURVIVED {stamp(r.elapsed)}   FIRST RECORD"
            else if r.new_best: f"SURVIVED {stamp(r.elapsed)}   NEW BEST BY {gap_text(r.elapsed - r.previous_best)}"
            else: f"SURVIVED {stamp(r.elapsed)}   {gap_text(r.previous_best - r.elapsed)} SHORT OF YOUR BEST {stamp(r.previous_best)}"
        neon(delta_line, 60, 96, 32, if r.new_best: gold(1.0) else: white(1.0))
        if r.new_best: DrawPoly(Vector2 { x: 40.0, y: 112.0 }, 5, (10.0 + 2.0 * sin(clock * 6.0)) as f32, -90.0, gold(1.0))
        if t > 0.2: neon(r.cause.clone(), 60, 140, 18, magenta(0.95))
        if t > 0.35:
            label(f"LEVEL {r.level}     BEST COMBO x{r.best_combo}     KILLS {commas(r.kills)}     SHIP {r.ship.name().to_upper()}     STAGE {r.stage.name().to_upper()}", 60, 180, 14, white(0.8))
            var kline = ""
            for i in 0..KIND_COUNT:
                if r.kills_by_kind[i] == 0: continue
                let part = f"{kind_at(i).name()} {commas(r.kills_by_kind[i])}"
                kline = if kline.len() == 0: part else: kline ++ "  ·  " ++ part
            label(kline, 60, 204, 12, white(0.55))
            // The build, as icons with levels.
            var x = 60.0
            for slot in 0..SLOT_COUNT:
                let s: WeaponSlot = r.build.weapons[slot]
                if s.level == 0: continue
                draw_weapon_icon(s.weapon, V2 { x: x + 14.0, y: 252.0 }, 11.0, clock, 1.0)
                label(f"{s.weapon.name()} {roman(s.level)}", (x + 32.0) as i32, 246, 12, weapon_tint(s.weapon))
                x += 40.0 + MeasureText(f"{s.weapon.name()} {roman(s.level)}", 12) as f64
            x = 60.0
            for slot in 0..SLOT_COUNT:
                let s: PassiveSlot = r.build.passives[slot]
                if s.level == 0: continue
                draw_passive_icon(s.passive, V2 { x: x + 14.0, y: 284.0 }, 9.0, 1.0)
                label(f"{s.passive.name()} {roman(s.level)}", (x + 32.0) as i32, 278, 12, lime(0.9))
                x += 40.0 + MeasureText(f"{s.passive.name()} {roman(s.level)}", 12) as f64
        // The open loops slide in last.
        if t > 0.6:
            var y = 340
            match &r.next_unlock:
                Some(u) => {
                    neon(f"NEXT UNLOCK   {u.name}", 60, y, 18, white(1.0))
                    label(u.condition.describe(), 60, y + 24, 14, white(0.7))
                    DrawRectangle(600, y + 6, 300, 8, white(0.15))
                    DrawRectangle(600, y + 6, (300.0 * u.fraction) as i32, 8, gold(0.9))
                    label(f"{(u.fraction * 100.0) as i32}%", 910, y + 4, 12, gold(0.9))
                }
                None => neon("EVERY UNLOCK IS OPEN", 60, y, 18, gold(1.0))
            y += 60
            match r.next_rank:
                Some(n) => {
                    neon(f"NEXT RANK   {n.item.name()} {n.rank} for {commas(n.price)} credits", 60, y, 18, white(1.0))
                    label(n.item.effect(n.rank), 60, y + 24, 14, white(0.7))
                    let f = limit(r.bank as f64 / n.price as f64, 0.0, 1.0)
                    DrawRectangle(600, y + 6, 300, 8, white(0.15))
                    DrawRectangle(600, y + 6, (300.0 * f) as i32, 8, if f >= 1.0: lime(0.9) else: gold(0.9))
                    label(if f >= 1.0: "AFFORDABLE" else: f"{(f * 100.0) as i32}%", 910, y + 4, 12, if f >= 1.0: lime(0.9) else: gold(0.9))
                }
                None => neon("THE SHOP IS COMPLETE", 60, y, 18, gold(1.0))
            y += 60
            label(f"The level-up bar was {(r.bar * 100.0) as i32}% full", 60, y, 16, lime(0.85))
            y += 30
            if let Some((w, d)) = r.merge:
                let away = if d == 1: "one level" else: f"{d} levels"
                label(f"{w.name()} was {away} away", 60, y, 16, gold(0.95))
                y += 30
            if r.unlocks.len() > 0:
                var text = "UNLOCKED  "
                for u in r.unlocks: text = text ++ u ++ "   "
                neon(text, 60, y + 6, 18, lime(1.0))
                y += 36
            if r.new_ships.len() > 0:
                let ship = r.new_ships[0]
                panel(760, 560, 460, 90, gold(1.0))
                draw_ship(ship, V2 { x: 810.0, y: 605.0 }, V2 { x: 0.0, y: -1.0 }, 1.0, 1.8)
                neon(f"NEW SHIP: {ship.name().to_upper()}", 860, 576, 22, gold(1.0))
                label("[RB / TAB]  RETRY AS IT", 860, 610, 14, white(0.8))
        centered("[A] RETRY     [B] SHIP SELECT     [X] SHOP     [Y] COLLECTION", 730, 16, white(0.75))

    fn draw_shop(self: &Self, clock: f64):
        neon("SHOP", 40, 24, 30, gold(1.0))
        self.credits_corner()
        label(if self.shop_by_price: "SORTED BY PRICE" else: "SORTED BY CATEGORY", 40, 66, 10, white(0.5))
        for row in 0..SHOP_COUNT:
            let item = self.shop_row(row)
            let rank = self.save.ranks[item.index()]
            let y = 110 + row * 30
            let selected = row == self.shop_cursor
            if selected:
                DrawRectangle(80, y - 2, 780, 28, white(0.06 + self.shop_flash * 0.3))
                neon(">", 60, y, 18, white(1.0))
            label(item.name(), 90, y + 2, 18, if selected: white(1.0) else: white(0.75))
            for pip in 0..item.max_rank():
                let px = 290 + pip * 16
                if pip < rank: DrawCircle(px, y + 11, 5.0, gold(1.0))
                else: DrawCircleLines(px, y + 11, 5.0, white(0.35))
            if rank >= item.max_rank():
                label("MAX", 400, y + 4, 14, lime(0.8))
                continue
            let price = item.price(rank)
            label(f"rank {rank + 1}", 400, y + 4, 14, white(0.6))
            neon_right(commas(price), 620, y + 2, 18, gold(1.0))
            if price <= self.save.credits: label("AFFORDABLE", 640, y + 5, 12, lime(0.9))
            else:
                let f = limit(self.save.credits as f64 / price as f64, 0.0, 1.0)
                DrawRectangle(640, y + 9, 140, 6, white(0.12))
                DrawRectangle(640, y + 9, (140.0 * f) as i32, 6, gold(0.8))
                label(f"{(f * 100.0) as i32}%", 790, y + 5, 12, gold(0.8))
        let item = self.shop_row(self.shop_cursor)
        let rank = self.save.ranks[item.index()]
        panel(900, 110, 340, 200, gold(1.0))
        neon(item.name(), 920, 126, 24, white(1.0))
        if rank < item.max_rank():
            label(f"Rank {rank + 1}:", 920, 170, 14, white(0.6))
            label(item.effect(rank + 1), 920, 190, 14, lime(1.0))
            label("Now:", 920, 222, 14, white(0.6))
            label(if rank == 0: "nothing" else: item.effect(rank), 920, 242, 14, white(0.8))
        else: label(item.effect(rank), 920, 170, 14, lime(1.0))
        let refund = if self.confirm_refund: f"[Y] CONFIRM REFUND OF {commas(self.save.spent)}" else: f"[Y] REFUND ALL ({commas(self.save.spent)})"
        centered(f"[A] BUY     [B] BACK     {refund}     [LB / RB] SORT", 720, 14, if self.confirm_refund: magenta(1.0) else: white(0.7))
        let _ = clock

    fn draw_collection(self: &Self, clock: f64):
        neon("COLLECTION", 40, 24, 30, lime(1.0))
        self.credits_corner()
        for t in 0..TAB_COUNT:
            let tab = tab_at(t)
            let (have, total) = self.tab_counts(tab)
            let text = f"{tab.name()} {have}/{total}"
            let selected = tab == self.tab
            neon(text.clone(), 60 + t * 130, 74, 12, if selected: white(1.0) else: white(0.4))
            if selected: DrawRectangle(60 + t * 130, 92, MeasureText(text, 12), 2, lime(1.0))
        let count = self.tab.count()
        for i in 0..count:
            let (x, y) = collection_card_origin(i)
            let selected = i == self.collection_cursor
            let open = self.entry_open(self.tab, i)
            DrawRectangle(x, y, 140, 104, ink(0.9))
            DrawRectangleLinesEx(Rectangle { x: x as f32, y: y as f32, width: 140.0, height: 104.0 }, if selected: 3.0 else: 1.0, if selected: white(1.0) else: lime(0.3))
            let center = V2 { x: (x + 70) as f64, y: (y + 42) as f64 }
            let alpha = if open: 1.0 else: 0.18
            match self.tab:
                .Ships => draw_ship(ship_at(i), center, V2 { x: 0.0, y: -1.0 }, alpha, 1.6)
                .Weapons => draw_weapon_icon(weapon_at(i), center, 18.0, clock, alpha)
                .Passives => draw_passive_icon(passive_at(i), center, 16.0, alpha)
                .Merges => {
                    if open: draw_weapon_icon(recipes()[i].result, center, 18.0, clock, 1.0)
                    else: centered_at("? + ?", x + 70, y + 34, 18, white(0.3))
                }
                .Registry => draw_enemy(kind_at(i), center, 18.0, clock, 0.0, V2 { x: 0.0, y: -1.0 }, paint(kind_at(i).tint(), alpha), 0.85)
                .Stages => {
                    let rules = stage_at(i).rules()
                    let w = 100.0 * limit(rules.arena_width / 3600.0, 0.2, 1.0)
                    let h = 60.0 * limit(rules.arena_height / 2600.0, 0.2, 1.0)
                    DrawRectangleLines((center.x - w / 2.0) as i32, (center.y - h / 2.0) as i32, w as i32, h as i32, if open: cyan(1.0) else: white(0.2))
                }
            centered_at(if open: self.entry_name(self.tab, i) else: "LOCKED", x + 70, y + 80, 12, if open: white(0.9) else: white(0.3))
        // Detail panel.
        panel(880, 120, 360, 520, lime(1.0))
        let i = self.collection_cursor
        let open = self.entry_open(self.tab, i)
        neon(if open: self.entry_name(self.tab, i) else: "LOCKED", 900, 138, 24, white(1.0))
        var y = 184
        for line_text in self.entry_detail(self.tab, i):
            label(line_text.clone(), 900, y, 14, white(0.8))
            y += 22
        centered("[LB / RB] TAB     [B] BACK", 720, 14, white(0.7))

    fn tab_counts(self: &Self, tab: Tab) -> (i32, i32):
        var have = 0
        for i in 0..tab.count():
            if self.entry_open(tab, i): have += 1
        (have, tab.count())

    fn entry_open(self: &Self, tab: Tab, i: i32) -> bool:
        match tab:
            .Ships => ship_unlocked(ship_at(i), &self.save)
            .Weapons => met(weapon_condition(weapon_at(i)), &self.save)
            .Passives => met(passive_condition(passive_at(i)), &self.save)
            .Merges => self.save.taken_weapons[recipes()[i].result.index()]
            .Registry => self.save.registry_kills[i] > 0
            .Stages => stage_unlocked(stage_at(i), &self.save)

    fn entry_name(self: &Self, tab: Tab, i: i32) -> str:
        match tab:
            .Ships => ship_at(i).name()
            .Weapons => weapon_at(i).name()
            .Passives => passive_at(i).name()
            .Merges => recipes()[i].result.name()
            .Registry => kind_at(i).name()
            .Stages => stage_at(i).name()

    fn entry_detail(self: &Self, tab: Tab, i: i32) -> Vec[str]:
        var out: Vec[str] = Vec.new()
        let open = self.entry_open(tab, i)
        match tab:
            .Ships => {
                let ship = ship_at(i)
                if open:
                    out.push(f"Base weapon: {ship.base_weapon().name()}")
                    out.push(ship.strength())
                    out.push(ship.growth())
                    out.push(f"Weakness: {ship.weakness()}")
                    out.push(f"Best: {stamp(self.save.best_time[i])}")
                else:
                    out.push(ship.condition().describe())
                    out.push(f"Progress {(fraction(ship.condition(), &self.save) * 100.0) as i32}%")
            }
            .Weapons => {
                let w = weapon_at(i)
                out.push(w.describe())
                if open: out.push(f"Longest held: {stamp(self.save.held[i])}")
                else:
                    out.push(weapon_condition(w).describe())
                    out.push(f"Progress {(fraction(weapon_condition(w), &self.save) * 100.0) as i32}%")
            }
            .Passives => {
                let p = passive_at(i)
                out.push(f"Per level: {p.describe()}")
                if not open:
                    out.push(passive_condition(p).describe())
                    out.push(f"Progress {(fraction(passive_condition(p), &self.save) * 100.0) as i32}%")
            }
            .Merges => {
                let r = recipes()[i]
                if open:
                    out.push(r.result.describe())
                    let second = match r.second:
                        Some(s) => f" and {s.name()}"
                        None => ""
                    out.push(f"{r.first.name()}{second} at VIII")
                    out.push(f"Key: {r.key.name()} at any level")
                else:
                    out.push("Undiscovered recipe.")
                    out.push("Max a weapon and hold its key.")
            }
            .Registry => {
                let k = kind_at(i)
                if open:
                    out.push(f"Lifetime kills: {commas(self.save.registry_kills[i])}")
                    let first = self.save.registry_first[i]
                    out.push(f"First killed at minute {first as i32}")
                else: out.push("Not yet destroyed.")
                let _ = k
            }
            .Stages => {
                let s = stage_at(i)
                out.push(s.describe())
                if not open:
                    out.push(stage_condition(s).describe())
                    out.push(f"Progress {(fraction(stage_condition(s), &self.save) * 100.0) as i32}%")
            }
        out

fn gap_text(seconds: f64) -> str:
    let s = seconds as i32
    if s < 60: f"{s} SECONDS" else: stamp(seconds)

fn select_card_origin(i: i32) -> (i32, i32):
    (60 + i * 130, 110)

fn collection_card_origin(i: i32) -> (i32, i32):
    (40 + (i % 5) * 160, 120 + (i / 5) * 116)

pub fn boost_card_rect(i: i32, count: i32) -> (i32, i32, i32, i32):
    let card_w = 220
    let gap = 24
    let total = count * card_w + (count - 1) * gap
    let x0 = (WIDTH - total) / 2
    (x0 + i * (card_w + gap), 230, card_w, 300)
