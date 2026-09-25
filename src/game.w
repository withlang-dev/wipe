use tuning

// Pure simulation: no window, audio, or foreign calls; pools allocate at creation.
// Dense bounded pools use swap removal. At this scale bullet/enemy scans
// are bounded by 96 * 512, without a physics framework or spatial index.
pub const ENEMY_CAP: i32 = 512
pub const BULLET_CAP: i32 = 96
pub const PARTICLE_CAP: i32 = 2048
pub const PULSE_CAP: i32 = 64
pub const POPUP_CAP: i32 = 48
pub const WIDTH: i32 = 1280
pub const HEIGHT: i32 = 800
// The playfield rectangle. grid.fs repeats these bounds and must agree.
pub const ARENA_LEFT: i32 = 24
pub const ARENA_TOP: i32 = 76
pub const ARENA_RIGHT: i32 = 1256
pub const ARENA_BOTTOM: i32 = 772
// Separation runs on a coarse uniform grid rebuilt every tick.
const CELL_SIZE: i32 = 40
const CELL_COLS: i32 = 32
const CELL_ROWS: i32 = 20
const CELL_COUNT: i32 = CELL_COLS * CELL_ROWS

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
pub enum Tint { | Cyan | Magenta | Gold | White | Lime | Blue }
impl Copy for Tint

// Every kind chases the same way; kinds differ in silhouette and pace.
pub enum Kind { | Block | Spinner | Dart | Weaver }
impl Copy for Kind
extend Kind:
    pub fn tint(self: &Self) -> Tint:
        match self:
            .Block => .Lime
            .Spinner => .Magenta
            .Dart => .Blue
            .Weaver => .Cyan
    // Darts rush, weavers lag.
    fn speed_bonus(self: &Self) -> f64:
        match self:
            .Block => 0.0
            .Spinner => 12.0
            .Dart => 34.0
            .Weaver => -16.0
fn kind_at(index: i32) -> Kind:
    match index:
        0 => .Block
        1 => .Spinner
        2 => .Dart
        _ => .Weaver

pub type Enemy {
    pos: V2 = V2 {},
    hp: i32 = 1,
    age: f64 = 0.0,
    flash: f64 = 0.0,
    speed: f64 = 95.0,
    kind: Kind = .Block,
}
pub type Bullet { pos: V2 = V2 {}, vel: V2 = V2 {}, life: f64 = 0.0, steps: i32 = 0 }
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
// Floating score text spawned by kills.
pub type Popup { pos: V2 = V2 {}, life: f64 = 0.0, total: f64 = 0.9, value: i32 = 0 }
pub type Controls { motion: V2 = V2 {}, aim: V2 = V2 { x: 1.0, y: 0.0 } }

// Records that outlive a single run and survive restarts.
pub type Session { best_time: f64 = 0.0, best_score: i32 = 0 }
extend Session:
    pub fn observe(mut self: Self, g: &Game):
        if g.elapsed > self.best_time: self.best_time = g.elapsed
        if g.score > self.best_score: self.best_score = g.score

// Allocate and initialize each pool once. Restart resets active lengths only.
fn storage[T](value: T, capacity: i32) -> Vec[T]:
    var slots: Vec[T] = Vec.with_capacity(capacity)
    for _ in 0..capacity: slots.push(value)
    slots

pub type Game {
    rules: Rules = Rules {},
    player: V2 = V2 { x: 640.0, y: 400.0 },
    aim: V2 = V2 { x: 1.0, y: 0.0 },
    health: i32 = 3, kills: i32 = 0, score: i32 = 0, elapsed: f64 = 0.0,
    invulnerable: f64 = 0.0, fire_timer: f64 = 0.0,
    spawn_timer: f64 = 0.7, muzzle: f64 = 0.0,
    trauma: f64 = 0.0, flash: f64 = 0.0, freeze: f64 = 0.0,
    kill_energy: f64 = 0.0,
    enemy_count: i32 = 0, bullet_count: i32 = 0, particle_count: i32 = 0,
    pulse_count: i32 = 0, popup_count: i32 = 0,
    enemies: Vec[Enemy],
    cell_heads: Vec[i32],
    cell_next: Vec[i32],
    bullets: Vec[Bullet],
    particles: Vec[Particle],
    pulses: Vec[Pulse],
    popups: Vec[Popup],
    rng: u32 = 1234567,
    shot_event: bool = false, hit_event: bool = false,
    kill_event: bool = false, hurt_event: bool = false, death_event: bool = false,
}

pub fn Game.new(rules: Rules = Rules {}) -> Game:
    let health = rules.max_health
    Game {
        rules, health,
        enemies: storage(Enemy {}, ENEMY_CAP),
        cell_heads: storage(-1, CELL_COUNT),
        cell_next: storage(-1, ENEMY_CAP),
        bullets: storage(Bullet {}, BULLET_CAP),
        particles: storage(Particle {}, PARTICLE_CAP),
        pulses: storage(Pulse {}, PULSE_CAP),
        popups: storage(Popup {}, POPUP_CAP),
    }

extend Game:
    pub fn random(mut self: Self) -> f64:
        self.rng = self.rng *% 1664525 +% 1013904223
        (self.rng % 65536) as f64 / 65535.0

    pub fn reset(mut self: Self):
        self.player = V2 { x: 640.0, y: 400.0 }
        self.aim = V2 { x: 1.0, y: 0.0 }
        self.health = self.rules.max_health
        self.kills = 0
        self.score = 0
        self.elapsed = 0.0
        self.invulnerable = 0.0
        self.fire_timer = 0.0
        self.spawn_timer = 0.7
        self.muzzle = 0.0
        self.trauma = 0.0
        self.flash = 0.0
        self.freeze = 0.0
        self.kill_energy = 0.0
        self.enemy_count = 0
        self.bullet_count = 0
        self.particle_count = 0
        self.pulse_count = 0
        self.popup_count = 0
        self.clear_events()

    pub fn clear_events(mut self: Self):
        self.shot_event = false
        self.hit_event = false
        self.kill_event = false
        self.hurt_event = false
        self.death_event = false

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

    pub fn popup(mut self: Self, pos: V2, value: i32):
        if self.popup_count >= POPUP_CAP: return
        self.popups[self.popup_count] = Popup { pos, life: 0.9, total: 0.9, value }
        self.popup_count += 1

    // Kind mix shifts from blocks and darts toward spinners and weavers.
    fn pick_kind(mut self: Self) -> Kind:
        let roll = self.random()
        let late = limit(self.elapsed / 25.0, 0.0, 1.0)
        if roll < 0.55 - late * 0.2: .Block
        else if roll < 0.85 - late * 0.15: .Dart
        else if roll < 0.95: .Spinner
        else: .Weaver

    pub fn spawn_enemy(mut self: Self):
        if self.enemy_count >= ENEMY_CAP: return
        let edge = (self.random() * 3.999) as i32
        let along = self.random()
        let speed = self.rules.enemy_speed + self.random() * self.rules.enemy_speed_variation + limit(self.elapsed * self.rules.enemy_acceleration, 0.0, 32.0)
        // Spawns hug the arena edge, inset just enough to render whole.
        let pos = match edge:
            0 => V2 { x: ARENA_LEFT as f64 + 8.0, y: 100.0 + along * 640.0 }
            1 => V2 { x: ARENA_RIGHT as f64 - 8.0, y: 100.0 + along * 640.0 }
            2 => V2 { x: 40.0 + along * 1200.0, y: ARENA_TOP as f64 + 8.0 }
            _ => V2 { x: 40.0 + along * 1200.0, y: ARENA_BOTTOM as f64 - 8.0 }
        if length2(sub(pos, self.player)) < 100.0 * 100.0: return
        let kind = self.pick_kind()
        self.enemies[self.enemy_count] = Enemy { pos, speed: speed + kind.speed_bonus(), kind }
        self.enemy_count += 1

    pub fn stress(mut self: Self, target: i32 = 350):
        // Populate the arena, preserving a safe circle around the player.
        let count = if target > ENEMY_CAP: ENEMY_CAP else: target
        while self.enemy_count < count:
            let x = 45.0 + self.random() * 1190.0
            let y = 100.0 + self.random() * 600.0
            let pos = V2 { x, y }
            if length2(sub(pos, self.player)) < 180.0 * 180.0: continue
            let speed = self.rules.enemy_speed + self.random() * self.rules.enemy_speed_variation
            let kind = kind_at((self.random() * 3.999) as i32)
            self.enemies[self.enemy_count] = Enemy { pos, age: 0.2, speed: speed + kind.speed_bonus(), kind }
            self.enemy_count += 1

    pub fn effects(mut self: Self, dt: f64):
        self.trauma = limit(self.trauma - dt * 1.8, 0.0, 1.0)
        self.flash = limit(self.flash - dt * 2.8, 0.0, 1.0)
        self.muzzle = limit(self.muzzle - dt, 0.0, 1.0)
        self.kill_energy = limit(self.kill_energy - dt * 3.0, 0.0, 5.0)
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

    pub fn hurt(mut self: Self):
        if self.health <= 0 or self.invulnerable > 0.0: return
        self.health -= 1
        self.invulnerable = self.rules.invulnerability
        self.trauma = 0.7
        self.flash = 0.55
        self.freeze = self.rules.damage_stop
        self.hurt_event = true
        self.burst(self.player, V2 {}, 28, .White, 1.2)
        if self.health <= 0:
            self.trauma = 1.0
            self.flash = 0.9
            self.freeze = self.rules.death_stop
            self.death_event = true
            self.burst(self.player, V2 {}, 110, .Cyan, 2.0)
            self.burst(self.player, V2 {}, 40, .White, 2.4)
            self.pulse(self.player, 180.0, .Cyan)
            self.pulse(self.player, 100.0, .White)

    pub fn tick(mut self: Self, input: Controls, dt: f64):
        self.effects(dt)
        // Aim is sampled even during hit-stop; simulation time alone pauses.
        if length2(input.aim) > 0.01: self.aim = direction(input.aim)
        if self.freeze > 0.0:
            self.freeze = limit(self.freeze - dt, 0.0, 1.0)
            return
        if self.health <= 0: return
        self.elapsed += dt
        self.invulnerable = limit(self.invulnerable - dt, 0.0, 1.0)
        self.player = add(self.player, scale(movement(input.motion), self.rules.player_speed * dt))
        self.player.x = limit(self.player.x, ARENA_LEFT as f64 + 12.0, ARENA_RIGHT as f64 - 12.0)
        self.player.y = limit(self.player.y, ARENA_TOP as f64 + 14.0, ARENA_BOTTOM as f64 - 16.0)
        self.fire_timer -= dt
        if self.fire_timer <= 0.0:
            self.fire_timer += self.rules.fire_interval
            if self.bullet_count < BULLET_CAP:
                let pos = add(self.player, scale(self.aim, 26.0))
                self.bullets[self.bullet_count] = Bullet { pos, vel: scale(self.aim, self.rules.bullet_speed), life: self.rules.bullet_lifetime }
                self.bullet_count += 1
                self.muzzle = 0.055
                self.shot_event = true
        self.spawn_timer -= dt
        if self.spawn_timer <= 0.0:
            self.spawn_timer += 1.0 / limit(self.rules.spawn_base + self.elapsed * self.rules.spawn_growth, self.rules.spawn_base, self.rules.spawn_max)
            self.spawn_enemy()
        // A 40px uniform grid makes local separation scale with nearby
        // neighbors. It is rebuilt in preallocated storage, not allocated.
        for cell in 0..CELL_COUNT: self.cell_heads[cell] = -1
        for e in 0..self.enemy_count:
            let cell = cell_index(self.enemies[e].pos)
            self.cell_next[e] = self.cell_heads[cell]
            self.cell_heads[cell] = e
        for e in 0..self.enemy_count:
            var enemy: Enemy = self.enemies[e]
            enemy.age += dt
            enemy.flash = limit(enemy.flash - dt, 0.0, 1.0)
            if enemy.age >= self.rules.spawn_grace:
                var separation = V2 {}
                let cell = cell_index(enemy.pos)
                let cx = cell % CELL_COLS
                let cy = cell / CELL_COLS
                for dy in -1..2:
                    for dx in -1..2:
                        let x = cx + dx
                        let y = cy + dy
                        if x < 0 or x >= CELL_COLS or y < 0 or y >= CELL_ROWS: continue
                        var other: i32 = self.cell_heads[y * CELL_COLS + x]
                        while other >= 0:
                            if other != e:
                                let delta = sub(enemy.pos, self.enemies[other].pos)
                                let distance = sqrt(length2(delta))
                                if distance > 0.01 and distance < 30.0:
                                    separation = add(separation, scale(delta, (30.0 - distance) / (30.0 * distance)))
                            other = self.cell_next[other]
                let chase = scale(direction(sub(self.player, enemy.pos)), enemy.speed)
                let velocity = add(chase, scale(movement(separation), 85.0))
                enemy.pos = add(enemy.pos, scale(velocity, dt))
            self.enemies[e] = enemy
        var b = 0
        while b < self.bullet_count:
            var bullet: Bullet = self.bullets[b]
            let previous = bullet.pos
            // A sparse wake: one sparkle every third step keeps the muzzle clear.
            if bullet.steps % 3 == 0:
                let side = V2 { x: -bullet.vel.y, y: bullet.vel.x }
                let scatter = (self.random() - 0.5) * 0.10
                self.emit(Particle {
                    pos: previous, vel: add(scale(bullet.vel, -0.03), scale(side, scatter)),
                    life: 0.3, total: 0.3, size: 1.2, tint: .Gold,
                })
            bullet.steps += 1
            bullet.pos = add(bullet.pos, scale(bullet.vel, dt))
            bullet.life -= dt
            var hit = false
            for e in 0..self.enemy_count:
                let pos: V2 = self.enemies[e].pos
                if segment_hit(previous, bullet.pos, pos, self.rules.bullet_hit_radius):
                    hit = true
                    self.enemies[e].hp -= 1
                    self.enemies[e].flash = 0.05
                    let impact = direction(bullet.vel)
                    self.enemies[e].pos = add(pos, scale(impact, 4.0))
                    self.burst(bullet.pos, impact, 4, .Gold, 0.65)
                    self.hit_event = true
                    if self.enemies[e].hp <= 0:
                        let kind: Kind = self.enemies[e].kind
                        self.enemy_count -= 1
                        self.enemies[e] = self.enemies[self.enemy_count]
                        self.kills += 1
                        self.kill_event = true
                        // Rapid kills build a multiplier that decays between them.
                        let multiplier = 1 + (limit(self.kill_energy, 0.0, 4.0) as i32)
                        let value = 100 * multiplier
                        self.score += value
                        self.popup(pos, value)
                        self.kill_energy = limit(self.kill_energy + 1.0, 0.0, 5.0)
                        self.burst(pos, impact, 26, kind.tint(), 1.35 + self.kill_energy * 0.12)
                        self.burst(pos, impact, 5, .White, 1.1)
                        self.pulse(pos, 46.0 + self.kill_energy * 5.0, kind.tint(), Some(kind))
                        self.trauma = limit(self.trauma + 0.045, 0.0, 0.3)
                    break
            if hit or bullet.life <= 0.0 or bullet.pos.x < -30.0 or bullet.pos.x > WIDTH + 30.0 or bullet.pos.y < -30.0 or bullet.pos.y > HEIGHT + 30.0:
                self.bullet_count -= 1
                self.bullets[b] = self.bullets[self.bullet_count]
                continue
            self.bullets[b] = bullet
            b += 1
        for e in 0..self.enemy_count:
            if self.enemies[e].age >= self.rules.spawn_grace and length2(sub(self.enemies[e].pos, self.player)) < self.rules.contact_radius * self.rules.contact_radius:
                self.hurt()
                break

impl Copy for V2
impl Copy for Enemy
impl Copy for Bullet
impl Copy for Particle
impl Copy for Pulse
impl Copy for Popup
impl Copy for Controls
impl Copy for Session
