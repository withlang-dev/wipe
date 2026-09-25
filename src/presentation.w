use c_import("raylib.h")
use game
use shaders

fn rgba(r: i32, g: i32, b: i32, a: f64) -> Color:
    Fade(Color { r: r as u8, g: g as u8, b: b as u8, a: 255 }, limit(a, 0.0, 1.0) as f32)
fn cyan(a: f64) -> Color: rgba(87, 237, 255, a)
fn magenta(a: f64) -> Color: rgba(255, 74, 220, a)
fn lime(a: f64) -> Color: rgba(105, 255, 56, a)
fn blue(a: f64) -> Color: rgba(118, 150, 255, a)
fn gold(a: f64) -> Color: rgba(255, 214, 92, a)
fn white(a: f64) -> Color: rgba(227, 248, 245, a)
fn ink(a: f64) -> Color: rgba(3, 4, 14, a)
fn tint(kind: i32, alpha: f64) -> Color:
    match kind:
        0 => cyan(alpha)
        1 => magenta(alpha)
        2 => gold(alpha)
        4 => lime(alpha)
        5 => blue(alpha)
        _ => white(alpha)
fn rv(p: V2) -> Vector2: Vector2 { x: p.x as f32, y: p.y as f32 }
fn line(a: V2, b: V2, width: f64, color: Color):
    DrawLineEx(rv(a), rv(b), width as f32, color)
fn glow_line(a: V2, b: V2, color: Color):
    line(a, b, 6.0, Fade(color, 0.10))
    line(a, b, 3.0, Fade(color, 0.35))
    line(a, b, 1.6, color)
fn circle(p: V2, radius: f64, color: Color):
    DrawCircleV(rv(p), radius as f32, color)
fn label(text: str, x: i32, y: i32, size: i32, color: Color):
    DrawText(text, x, y, size, color)
// Bright text gets a soft duplicate underneath so bloom lifts it like the vectors.
fn neon(text: str, x: i32, y: i32, size: i32, color: Color):
    DrawText(text, x - 1, y, size, Fade(color, 0.28))
    DrawText(text, x + 1, y, size, Fade(color, 0.28))
    DrawText(text, x, y - 1, size, Fade(color, 0.22))
    DrawText(text, x, y + 1, size, Fade(color, 0.22))
    DrawText(text, x, y, size, color)
fn neon_right(text: str, right: i32, y: i32, size: i32, color: Color):
    neon(text, right - MeasureText(text, size), y, size, color)
fn centered(text: str, y: i32, size: i32, color: Color):
    neon(text, (1280 - MeasureText(text, size)) / 2, y, size, color)
fn stamp(seconds: f64) -> str:
    let total = seconds as i32
    let minutes = total / 60
    let secs = total % 60
    if secs < 10: f"{minutes}:0{secs}" else: f"{minutes}:{secs}"
fn commas(value: i32) -> str:
    if value < 1000: f"{value}"
    else:
        let rest = value % 1000
        let head = commas(value / 1000)
        if rest < 10: f"{head},00{rest}" else if rest < 100: f"{head},0{rest}" else: f"{head},{rest}"

// Polygon outline with a halo; bloom does the heavy lifting afterwards.
fn outline(pos: V2, sides: i32, radius: f64, angle: f64, color: Color, core: f64):
    DrawPolyLinesEx(rv(pos), sides, radius as f32, angle as f32, 5.0, Fade(color, 0.16))
    DrawPolyLinesEx(rv(pos), sides, radius as f32, angle as f32, core as f32, color)

// The open claw is the only asymmetric, unclosed silhouette on the field.
fn draw_ship(pos: V2, aim: V2, alpha: f64, scale_by: f64):
    let side = V2 { x: -aim.y, y: aim.x }
    let at = (f: f64, s: f64) => add(pos, add(scale(aim, f * scale_by), scale(side, s * scale_by)))
    let nose = at(15.0, 0.0)
    let left = at(-7.0, 13.0)
    let right = at(-7.0, -13.0)
    let left_tail = at(-14.0, 6.0)
    let right_tail = at(-14.0, -6.0)
    let notch = at(-3.0, 0.0)
    let left_inner = at(-9.0, 7.0)
    let right_inner = at(-9.0, -7.0)
    glow_line(left, nose, white(alpha))
    glow_line(nose, right, white(alpha))
    glow_line(left, left_tail, white(alpha))
    glow_line(right, right_tail, white(alpha))
    glow_line(left_inner, notch, white(alpha * 0.9))
    glow_line(notch, right_inner, white(alpha * 0.9))
    glow_line(left_inner, left_tail, cyan(alpha * 0.8))
    glow_line(right_inner, right_tail, cyan(alpha * 0.8))

fn draw_enemy(kind: i32, pos: V2, radius: f64, clock: f64, speed: f64, toward: V2, color: Color, dim: f64):
    match kind:
        1 => {
            // Spinner: a fast diamond with a cross through it.
            let angle = clock * 150.0 + speed * 3.0
            outline(pos, 4, radius, angle, color, 2.0)
            let rad = angle * 0.0174533
            let a = V2 { x: cos(rad), y: sin(rad) }
            let b = V2 { x: -a.y, y: a.x }
            line(sub(pos, scale(a, radius)), add(pos, scale(a, radius)), 1.3, Fade(color, dim))
            line(sub(pos, scale(b, radius)), add(pos, scale(b, radius)), 1.3, Fade(color, dim))
        }
        2 => {
            // Dart: an arrowhead that faces its target.
            let heading = atan2(toward.y, toward.x) * 57.2958
            outline(pos, 3, radius, heading, color, 2.4)
            let back = sub(pos, scale(toward, radius * 0.5))
            let side = V2 { x: -toward.y, y: toward.x }
            line(add(back, scale(side, radius * 0.45)), sub(back, scale(side, radius * 0.45)), 1.3, Fade(color, dim))
        }
        3 => {
            // Weaver: nested squares turning against each other.
            let angle = clock * 40.0 + speed
            outline(pos, 4, radius, angle, color, 2.0)
            DrawPolyLinesEx(rv(pos), 4, (radius * 0.62) as f32, (-angle * 1.5) as f32, 1.4, Fade(color, dim))
            DrawPolyLinesEx(rv(pos), 4, (radius * 0.3) as f32, angle as f32, 1.0, Fade(color, dim))
        }
        _ => {
            // Block: a square framing a slowly counter-rotating diamond.
            let angle = clock * 27.0 + speed * 4.0
            outline(pos, 4, radius, angle, color, 2.0)
            DrawPolyLinesEx(rv(pos), 4, (radius * 0.66) as f32, (-angle + 45.0) as f32, 1.4, Fade(color, dim))
        }

fn render_world(g: &Game, offset: V2, clock: f64) -> Unit:
    DrawRectangleLinesEx(Rectangle { x: 24.0, y: 76.0, width: 1232.0, height: 696.0 }, 7.0, cyan(0.10))
    DrawRectangleLinesEx(Rectangle { x: 24.0, y: 76.0, width: 1232.0, height: 696.0 }, 2.0, cyan(0.9))
    // Decorative effects render underneath all solid gameplay silhouettes.
    for i in 0..g.pulse_count:
        let p: Pulse = g.pulses[i]
        let remaining = p.life / p.total
        let pos = add(p.pos, offset)
        let radius = 6.0 + (1.0 - remaining) * p.radius
        DrawCircleLinesV(rv(pos), radius as f32, tint(p.tint, remaining * 0.5))
        // A rapidly shrinking remnant gives an enemy's death a visible scale-out.
        if p.kind >= 0:
            let size = 15.0 * remaining * remaining
            draw_enemy(p.kind, pos, size, clock, 0.0, V2 { x: 1.0, y: 0.0 }, tint(p.tint, remaining), 0.6)
    for i in 0..g.particle_count:
        let p: Particle = g.particles[i]
        let remaining = p.life / p.total
        let pos = add(p.pos, offset)
        // Sparks are streaks whose length follows their speed, settling to dots.
        let speed = sqrt(length2(p.vel))
        let heading = if speed > 1.0: scale(p.vel, 1.0 / speed) else: V2 { x: cos(p.rotation), y: sin(p.rotation) }
        let tail = sub(pos, scale(heading, 3.0 + speed * 0.055))
        let color = tint(p.tint, remaining)
        line(pos, tail, p.size + 2.6, Fade(color, remaining * 0.18))
        line(pos, tail, p.size, color)
        if remaining > 0.7: line(pos, sub(pos, scale(heading, 2.0 + speed * 0.012)), p.size * 0.7, white((remaining - 0.7) * 2.5))
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        let pos = add(e.pos, offset)
        let growth = limit(e.age / 0.18, 0.0, 1.0)
        let base = if e.kind == 2: 14.0 else if e.kind == 1: 14.0 else: 15.0
        let radius = base * growth + if e.flash > 0.0: 2.5 else: 0.0
        let color = if e.flash > 0.0: white(1.0) else: tint(enemy_tint(e.kind), 1.0)
        let toward = direction(sub(g.player, e.pos))
        draw_enemy(e.kind, pos, radius, clock, e.speed, toward, color, 0.85)
        if e.age < 0.25:
            DrawCircleLinesV(rv(pos), (30.0 - growth * 12.0) as f32, Fade(color, (1.0 - growth) * 0.7))
    for i in 0..g.bullet_count:
        let b: Bullet = g.bullets[i]
        let pos = add(b.pos, offset)
        let heading = direction(b.vel)
        let side = V2 { x: -heading.y, y: heading.x }
        // Twin streaks with a white-hot head.
        for lane in 0..2:
            let shift = scale(side, if lane == 0: 2.2 else: -2.2)
            let head = add(pos, shift)
            let tail = sub(head, scale(heading, 26.0))
            line(tail, head, 5.0, gold(0.14))
            line(tail, head, 1.6, gold(0.9))
            line(sub(head, scale(heading, 9.0)), head, 1.8, white(1.0))
        circle(pos, 2.2, white(1.0))
    if g.health > 0:
        let pos = add(g.player, offset)
        let flicker = if g.invulnerable > 0.0 and (clock * 22.0) as i32 % 2 == 0: 0.3 else: 1.0
        draw_ship(pos, g.aim, flicker, 1.0)
        if g.muzzle > 0.0:
            let front = add(pos, scale(g.aim, 30.0))
            let side = V2 { x: -g.aim.y, y: g.aim.x }
            circle(front, 10.0 * g.muzzle / 0.055, gold(0.16))
            line(add(front, scale(side, -5.0)), add(front, scale(side, 5.0)), 2.0, white(1.0))
            line(front, add(front, scale(g.aim, 12.0)), 3.0, white(1.0))
    for i in 0..g.popup_count:
        let p: Popup = g.popups[i]
        let remaining = p.life / p.total
        let text = f"{p.value}"
        let size = if p.value >= 300: 18 else: 14
        neon(text, (p.pos.x + offset.x) as i32 - MeasureText(text, size) / 2, (p.pos.y + offset.y) as i32 - 8, size, gold(limit(remaining * 1.6, 0.0, 1.0)))
    if g.flash > 0.0:
        DrawRectangle(0, 0, 1280, 800, white(g.flash * 0.10))
        DrawRectangle(0, 0, 1280, 9, magenta(g.flash))
        DrawRectangle(0, 791, 1280, 9, magenta(g.flash))
        DrawRectangle(0, 0, 9, 800, magenta(g.flash))
        DrawRectangle(1271, 0, 9, 800, magenta(g.flash))

fn render_hud(g: &Game, debug: bool, frame_ms: f64, best_time: f64, best_score: i32) -> Unit:
    DrawRectangle(0, 0, 1280, 66, ink(1.0))
    let hud = rgba(150, 255, 60, 1.0)
    neon("SCORE", 26, 6, 20, hud)
    neon(commas(g.score), 26, 28, 34, hud)
    neon_right("BEST", 1254, 6, 20, hud)
    neon_right(commas(if g.score > best_score: g.score else: best_score), 1254, 28, 34, hud)
    // Remaining lives are little claws; spent ones are hollow rings.
    let total = g.rules.max_health
    for i in 0..total:
        let x = 640.0 + (i as f64 - (total as f64 - 1.0) / 2.0) * 34.0
        if i < g.health: draw_ship(V2 { x, y: 36.0 }, V2 { x: 0.0, y: -1.0 }, 1.0, 0.62)
        else: DrawCircleLinesV(Vector2 { x: x as f32, y: 34.0 }, 7.0, lime(0.35))
    DrawRectangle(0, 778, 1280, 22, ink(1.0))
    label("MOVE  WASD / LEFT STICK     AIM  MOUSE / RIGHT STICK     AUTO-FIRE", 26, 784, 10, white(0.4))
    let status = f"TIME  {stamp(g.elapsed)}     KILLS  {g.kills}"
    label(status, (1280 - MeasureText(status, 10)) / 2, 784, 10, lime(0.7))
    label("WITH + RAYLIB     F1 STATS   F3 STRESS   ESC QUIT", 924, 784, 10, cyan(0.55))
    if debug:
        DrawRectangle(40, 96, 240, 204, ink(0.94))
        DrawRectangle(40, 96, 3, 204, cyan(0.85))
        label("PERFORMANCE / F1", 55, 110, 14, cyan(1.0))
        label(f"FPS             {GetFPS()}", 55, 139, 14, white(1.0))
        let tenths = (frame_ms * 10.0) as i32
        label(f"FRAME           {tenths / 10}.{tenths % 10} ms", 55, 160, 14, white(0.8))
        label(f"ENEMIES         {g.enemy_count}", 55, 181, 14, magenta(1.0))
        label(f"BULLETS         {g.bullet_count}", 55, 202, 14, white(0.8))
        label(f"PARTICLES       {g.particle_count}", 55, 223, 14, white(0.8))
        let active = g.enemy_count + g.bullet_count + g.particle_count + g.pulse_count + 1
        label(f"TOTAL           {active}", 55, 244, 14, cyan(1.0))
        label(f"RUN             {stamp(g.elapsed)}", 55, 275, 12, white(0.55))
    if g.health <= 0:
        DrawRectangle(0, 66, 1280, 712, ink(if g.freeze > 0.0: 0.25 else: 0.72))
        DrawRectangle(428, 268, 424, 274, ink(0.92))
        DrawRectangle(428, 268, 424, 2, magenta(1.0))
        centered("SIGNAL LOST", 290, 12, magenta(1.0))
        centered("YOU DIED", 322, 46, white(1.0))
        centered(f"SCORE  {commas(g.score)}", 388, 24, hud)
        centered(f"TIME  {stamp(g.elapsed)}     KILLS  {g.kills}", 422, 16, white(0.8))
        centered("[ SPACE / A ]  RETRY", 470, 20, cyan(1.0))
        centered(f"SESSION BEST  {commas(best_score)}  /  {stamp(best_time)}", 510, 10, white(0.45))


// Full-resolution scene plus two bloom tiers: a quarter-resolution tight
// glow and an eighth-resolution wide halo. The composite keeps sharp vector
// cores while the halos overlap into genuine neon.
pub type Renderer {
    scene: RenderTexture2D, bloom_a: RenderTexture2D, bloom_b: RenderTexture2D,
    wide_a: RenderTexture2D, wide_b: RenderTexture2D,
    grid: Effect, bright: Effect, blur: Effect, composite: Effect,
    ship_location: i32, count_location: i32, impulse_locations: Vec[i32],
    bullet_count_location: i32, bullet_locations: Vec[i32],
    threshold_location: i32, direction_location: i32, bloom_location: i32, wide_location: i32,
}
fn surface(width: i32, height: i32) -> RenderTexture2D:
    let target = LoadRenderTexture(width, height)
    SetTextureFilter(target.texture, TEXTURE_FILTER_BILINEAR)
    SetTextureWrap(target.texture, TEXTURE_WRAP_CLAMP)
    target

pub fn Renderer.open() -> Renderer:
    let grid = Effect.open("grid.fs")
    let bright = Effect.open("bright.fs")
    let blur = Effect.open("blur.fs")
    let composite = Effect.open("composite.fs")
    var locations: Vec[i32] = Vec.with_capacity(16)
    for i in 0..16: locations.push(grid.location(f"impulses[{i}]"))
    var bullets: Vec[i32] = Vec.with_capacity(24)
    for i in 0..24: bullets.push(grid.location(f"bullets[{i}]"))
    Renderer {
        scene: surface(WIDTH, HEIGHT), bloom_a: surface(320, 200), bloom_b: surface(320, 200),
        wide_a: surface(160, 100), wide_b: surface(160, 100),
        ship_location: grid.location("ship"), count_location: grid.location("impulseCount"),
        bullet_count_location: grid.location("bulletCount"), bullet_locations: bullets,
        threshold_location: bright.location("threshold"), direction_location: blur.location("direction"),
        bloom_location: composite.location("bloom"), wide_location: composite.location("wide"),
        impulse_locations: locations,
        grid, bright, blur, composite,
    }
impl Drop for Renderer:
    move fn drop():
        UnloadRenderTexture(self.wide_b)
        UnloadRenderTexture(self.wide_a)
        UnloadRenderTexture(self.bloom_b)
        UnloadRenderTexture(self.bloom_a)
        UnloadRenderTexture(self.scene)

fn blit(texture: Texture2D, width: f64, height: f64):
    DrawTexturePro(texture,
        Rectangle { x: 0.0, y: 0.0, width: texture.width as f32, height: -texture.height as f32 },
        Rectangle { x: 0.0, y: 0.0, width: width as f32, height: height as f32 },
        Vector2 { x: 0.0, y: 0.0 }, 0.0, WHITE)

extend Renderer:
    pub fn valid(self: &Self) -> bool:
        // Missing uniforms catch raylib's default-shader fallback as well as
        // actual allocation failure, so broken effects cannot pass silently.
        IsRenderTextureValid(self.scene) and IsRenderTextureValid(self.bloom_a) and IsRenderTextureValid(self.bloom_b) and IsRenderTextureValid(self.wide_a) and IsRenderTextureValid(self.wide_b) and self.ship_location >= 0 and self.count_location >= 0 and self.bullet_count_location >= 0 and self.threshold_location >= 0 and self.direction_location >= 0 and self.bloom_location >= 0 and self.wide_location >= 0 and self.impulse_locations[0] >= 0 and self.bullet_locations[0] >= 0

    // One horizontal and one vertical blur pass between two equal surfaces.
    fn blur_pair(self: &Self, a: RenderTexture2D, b: RenderTexture2D, width: f64, height: f64):
        BeginTextureMode(b)
        ClearBackground(BLACK)
        self.blur.vector2(self.direction_location, (1.0 / width) as f32, 0.0)
        self.blur.begin()
        blit(a.texture, width, height)
        EndShaderMode()
        EndTextureMode()
        BeginTextureMode(a)
        ClearBackground(BLACK)
        self.blur.vector2(self.direction_location, 0.0, (1.0 / height) as f32)
        self.blur.begin()
        blit(b.texture, width, height)
        EndShaderMode()
        EndTextureMode()

    pub fn draw(self: &Self, g: &Game, clock: f64, debug: bool, frame_ms: f64, best_time: f64, best_score: i32) -> f64:
        let started = GetTime()
        let shake = g.trauma * g.trauma * 8.0
        let offset = V2 { x: sin(clock * 83.0) * shake, y: cos(clock * 109.0) * shake }
        self.grid.vector4(self.ship_location, (g.player.x + offset.x) as f32, (g.player.y + offset.y) as f32, clock as f32, g.trauma as f32)
        let count = if g.pulse_count < 16: g.pulse_count else: 16
        self.grid.scalar(self.count_location, count as f32)
        for i in 0..count:
            let p: Pulse = g.pulses[i]
            self.grid.vector4(self.impulse_locations[i], (p.pos.x + offset.x) as f32, (p.pos.y + offset.y) as f32, (1.0 - p.life / p.total) as f32, p.radius as f32)
        let shots = if g.bullet_count < 24: g.bullet_count else: 24
        self.grid.scalar(self.bullet_count_location, shots as f32)
        for i in 0..shots:
            let b: Bullet = g.bullets[i]
            let heading = direction(b.vel)
            self.grid.vector4(self.bullet_locations[i], (b.pos.x + offset.x) as f32, (b.pos.y + offset.y) as f32, heading.x as f32, heading.y as f32)
        BeginTextureMode(self.scene)
        ClearBackground(ink(1.0))
        self.grid.begin()
        DrawRectangle(0, 0, WIDTH, HEIGHT, WHITE)
        EndShaderMode()
        render_world(g, offset, clock)
        // The HUD lives in the scene so its lime text blooms with the field.
        render_hud(g, debug, frame_ms, best_time, best_score)
        EndTextureMode()
        BeginTextureMode(self.bloom_a)
        ClearBackground(BLACK)
        self.bright.scalar(self.threshold_location, 0.36)
        self.bright.begin()
        blit(self.scene.texture, 320.0, 200.0)
        EndShaderMode()
        EndTextureMode()
        self.blur_pair(self.bloom_a, self.bloom_b, 320.0, 200.0)
        BeginTextureMode(self.wide_a)
        ClearBackground(BLACK)
        blit(self.bloom_a.texture, 160.0, 100.0)
        EndTextureMode()
        self.blur_pair(self.wide_a, self.wide_b, 160.0, 100.0)
        self.blur_pair(self.wide_a, self.wide_b, 160.0, 100.0)
        BeginDrawing()
        ClearBackground(ink(1.0))
        self.composite.begin()
        self.composite.texture(self.bloom_location, self.bloom_a.texture)
        self.composite.texture(self.wide_location, self.wide_a.texture)
        blit(self.scene.texture, WIDTH as f64, HEIGHT as f64)
        EndShaderMode()
        let cpu_ms = (GetTime() - started) * 1000.0
        EndDrawing()
        cpu_ms

pub fn verify_colors() -> Unit:
    let bg: Color = ink(1.0)
    let fg: Color = white(1.0)
    let enemy: Color = magenta(0.5)

    assert(bg.r == 3 and bg.g == 4 and bg.b == 14 and bg.a == 255)
    assert(fg.r == 227 and fg.g == 248 and fg.b == 245)
    assert(enemy.r == 255 and enemy.g == 74 and enemy.b == 220 and enemy.a == 127)
    assert(commas(0) == "0" and commas(999) == "999" and commas(1000) == "1,000")
    assert(commas(248775) == "248,775" and commas(1000005) == "1,000,005")
