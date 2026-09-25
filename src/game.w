use tuning

// Pure simulation: no window, audio, or foreign calls; pools allocate at creation.
// Dense bounded pools use swap removal. At this scale bullet/enemy scans
// are bounded by 96 * 512, without a physics framework or spatial index.
pub const ENEMY_CAP: i32 = 512
pub const BULLET_CAP: i32 = 96
pub const PARTICLE_CAP: i32 = 2048
pub const WIDTH: i32 = 1280
pub const HEIGHT: i32 = 800

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
    let x = limit(pos.x / 40.0, 0.0, 31.0) as i32
    let y = limit(pos.y / 40.0, 0.0, 19.0) as i32
    y * 32 + x

pub fn segment_hit(a: V2, b: V2, p: V2, radius: f64) -> bool:
    let ab = sub(b, a)
    let ap = sub(p, a)
    let size = length2(ab)
    let t = if size > 0.0001: limit((ap.x * ab.x + ap.y * ab.y) / size, 0.0, 1.0) else: 0.0
    length2(sub(p, add(a, scale(ab, t)))) <= radius * radius

pub type Enemy {
    pos: V2 = V2 {},
    hp: i32 = 1,
    age: f64 = 0.0,
    flash: f64 = 0.0,
    speed: f64 = 95.0,
}
pub type Bullet { pos: V2 = V2 {}, vel: V2 = V2 {}, life: f64 = 0.0 }
pub type Particle {
    pos: V2 = V2 {}, vel: V2 = V2 {},
    life: f64 = 0.0, total: f64 = 1.0,
    size: f64 = 1.0, rotation: f64 = 0.0,
    // 0: cyan, 1: magenta, 2: gold, 3: player white
    tint: i32 = 0,
}
pub type Pulse {
    pos: V2 = V2 {}, life: f64 = 0.0,
    total: f64 = 0.35, radius: f64 = 30.0, tint: i32 = 1,
}
pub type Controls { motion: V2 = V2 {}, aim: V2 = V2 { x: 1.0, y: 0.0 } }

// Allocate and initialize each pool once. Restart resets active lengths only.
fn storage[T](value: T, capacity: i32) -> Vec[T]:
    var slots: Vec[T] = Vec.with_capacity(capacity)
    for _ in 0..capacity: slots.push(value)
    slots

pub type Game {
    rules: Rules = Rules {},
    player: V2 = V2 { x: 640.0, y: 400.0 },
    aim: V2 = V2 { x: 1.0, y: 0.0 },
    health: i32 = 3, kills: i32 = 0, elapsed: f64 = 0.0,
    invulnerable: f64 = 0.0, fire_timer: f64 = 0.0,
    spawn_timer: f64 = 0.7, muzzle: f64 = 0.0,
    trauma: f64 = 0.0, flash: f64 = 0.0, freeze: f64 = 0.0,
    kill_energy: f64 = 0.0,
    enemy_count: i32 = 0, bullet_count: i32 = 0, particle_count: i32 = 0,
    pulse_count: i32 = 0,
    enemies: Vec[Enemy],
    cell_heads: Vec[i32],
    cell_next: Vec[i32],
    bullets: Vec[Bullet],
    particles: Vec[Particle],
    pulses: Vec[Pulse],
    rng: u32 = 1234567,
    shot_event: bool = false, hit_event: bool = false,
    kill_event: bool = false, hurt_event: bool = false, death_event: bool = false,
}

pub fn Game.new(rules: Rules = Rules {}) -> Game:
    let health = rules.max_health
    Game {
        rules, health,
        enemies: storage(Enemy {}, ENEMY_CAP),
        cell_heads: storage(-1, 640),
        cell_next: storage(-1, ENEMY_CAP),
        bullets: storage(Bullet {}, BULLET_CAP),
        particles: storage(Particle {}, PARTICLE_CAP),
        pulses: storage(Pulse {}, 64),
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

    pub fn burst(mut self: Self, pos: V2, impact: V2, count: i32, tint: i32, power: f64):
        for _ in 0..count:
            if self.particle_count >= PARTICLE_CAP: break
            let angle = self.random() * 6.283185307
            let speed = (35.0 + self.random() * 150.0) * power
            let life = 0.28 + self.random() * 0.38
            let size = 1.5 + self.random() * 3.0
            self.emit(Particle {
                pos, vel: add(V2 { x: cos(angle) * speed, y: sin(angle) * speed }, scale(impact, 80.0)),
                life, total: life, size, rotation: angle, tint,
            })

    pub fn pulse(mut self: Self, pos: V2, radius: f64, tint: i32):
        if self.pulse_count >= 64: return
        self.pulses[self.pulse_count] = Pulse { pos, life: 0.35, total: 0.35, radius, tint }
        self.pulse_count += 1

    pub fn spawn_enemy(mut self: Self):
        if self.enemy_count >= ENEMY_CAP: return
        let edge = (self.random() * 3.999) as i32
        let along = self.random()
        let speed = self.rules.enemy_speed + self.random() * self.rules.enemy_speed_variation + limit(self.elapsed * self.rules.enemy_acceleration, 0.0, 32.0)
        let pos = match edge:
            0 => V2 { x: 32.0, y: 100.0 + along * 640.0 }
            1 => V2 { x: 1248.0, y: 100.0 + along * 640.0 }
            2 => V2 { x: 40.0 + along * 1200.0, y: 84.0 }
            _ => V2 { x: 40.0 + along * 1200.0, y: 764.0 }
        if length2(sub(pos, self.player)) < 100.0 * 100.0: return
        self.enemies[self.enemy_count] = Enemy { pos, speed }
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
            self.enemies[self.enemy_count] = Enemy { pos, age: 0.2, speed }
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
            p.vel = scale(p.vel, 1.0 / (1.0 + dt * 4.5))
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

    pub fn hurt(mut self: Self):
        if self.health <= 0 or self.invulnerable > 0.0: return
        self.health -= 1
        self.invulnerable = self.rules.invulnerability
        self.trauma = 0.7
        self.flash = 0.55
        self.freeze = self.rules.damage_stop
        self.hurt_event = true
        self.burst(self.player, V2 {}, 28, 3, 1.2)
        if self.health <= 0:
            self.trauma = 1.0
            self.flash = 0.9
            self.freeze = self.rules.death_stop
            self.death_event = true
            self.burst(self.player, V2 {}, 110, 0, 2.0)
            self.burst(self.player, V2 {}, 40, 3, 2.4)
            self.pulse(self.player, 180.0, 0)
            self.pulse(self.player, 100.0, 3)

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
        self.player.x = limit(self.player.x, 36.0, WIDTH - 36.0)
        self.player.y = limit(self.player.y, 90.0, HEIGHT - 44.0)
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
        for cell in 0..640: self.cell_heads[cell] = -1
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
                let cx = cell % 32
                let cy = cell / 32
                for dy in -1..2:
                    for dx in -1..2:
                        let x = cx + dx
                        let y = cy + dy
                        if x < 0 or x >= 32 or y < 0 or y >= 20: continue
                        var other: i32 = self.cell_heads[y * 32 + x]
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
            self.emit(Particle {
                pos: previous, vel: scale(bullet.vel, -0.025), life: 0.12, total: 0.12,
                size: 1.8, tint: 2,
            })
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
                    self.burst(bullet.pos, impact, 4, 2, 0.65)
                    self.hit_event = true
                    if self.enemies[e].hp <= 0:
                        self.enemy_count -= 1
                        self.enemies[e] = self.enemies[self.enemy_count]
                        self.kills += 1
                        self.kill_event = true
                        self.kill_energy = limit(self.kill_energy + 1.0, 0.0, 5.0)
                        self.burst(pos, impact, 14, 1, 1.65 + self.kill_energy * 0.13)
                        self.burst(pos, impact, 6, 2, 1.9)
                        self.pulse(pos, 42.0 + self.kill_energy * 4.0, 1)
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
impl Copy for Controls
