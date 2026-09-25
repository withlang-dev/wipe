use c_import("raylib.h")
use game
use shaders

fn rgba(r: i32, g: i32, b: i32, a: f64) -> Color:
    Fade(Color { r: r as u8, g: g as u8, b: b as u8, a: 255 }, limit(a, 0.0, 1.0) as f32)
fn cyan(a: f64) -> Color: rgba(87, 237, 255, a)
fn magenta(a: f64) -> Color: rgba(255, 74, 220, a)
fn lime(a: f64) -> Color: rgba(105, 255, 56, a)
fn white(a: f64) -> Color: rgba(227, 248, 245, a)
fn ink(a: f64) -> Color: rgba(3, 4, 14, a)
fn tint(kind: i32, alpha: f64) -> Color:
    match kind:
        0 => cyan(alpha)
        1 => magenta(alpha)
        2 => rgba(255, 211, 84, alpha)
        _ => white(alpha)
fn rv(p: V2) -> Vector2: Vector2 { x: p.x as f32, y: p.y as f32 }
fn line(a: V2, b: V2, width: f64, color: Color):
    DrawLineEx(rv(a), rv(b), width as f32, color)
fn glow_line(a: V2, b: V2, color: Color):
    line(a, b, 8.0, Fade(color, 0.06))
    line(a, b, 4.0, Fade(color, 0.2))
    line(a, b, 1.7, color)
fn circle(p: V2, radius: f64, color: Color):
    DrawCircleV(rv(p), radius as f32, color)
fn label(text: str, x: i32, y: i32, size: i32, color: Color):
    DrawText(text, x, y, size, color)
fn centered(text: str, y: i32, size: i32, color: Color):
    let width = MeasureText(text, size)
    DrawText(text, (1280 - width) / 2, y, size, color)
fn stamp(seconds: f64) -> str:
    let total = seconds as i32
    let minutes = total / 60
    let secs = total % 60
    if secs < 10: f"{minutes}:0{secs}" else: f"{minutes}:{secs}"
fn render_world(g: &Game, offset: V2, clock: f64) -> Unit:
    DrawRectangleLinesEx(Rectangle { x: 24.0, y: 76.0, width: 1232.0, height: 696.0 }, 6.0, cyan(0.055))
    DrawRectangleLinesEx(Rectangle { x: 24.0, y: 76.0, width: 1232.0, height: 696.0 }, 1.0, cyan(0.6))
    // Decorative effects render underneath all solid gameplay silhouettes.
    for i in 0..g.pulse_count:
        let p: Pulse = g.pulses[i]
        let remaining = p.life / p.total
        let pos = add(p.pos, offset)
        let radius = 5.0 + (1.0 - remaining) * p.radius
        DrawCircleLinesV(rv(pos), radius as f32, tint(p.tint, remaining * 0.65))
        // A rapidly shrinking enemy remnant gives death a visible scale-out.
        if p.tint == 1:
            DrawPoly(rv(pos), 4, (12.0 * remaining * remaining) as f32, 45.0, magenta(remaining * 0.7))
    for i in 0..g.particle_count:
        let p: Particle = g.particles[i]
        let remaining = p.life / p.total
        let pos = add(p.pos, offset)
        let size = p.size * remaining
        let tail = sub(pos, scale(p.vel, 0.11))
        line(pos, tail, size + 3.0, tint(p.tint, remaining * 0.13))
        line(pos, tail, size, tint(p.tint, remaining))
        if remaining > 0.6: circle(pos, size * 0.45, white(remaining))
        DrawPoly(rv(pos), 4, size as f32, (p.rotation * 57.2958) as f32, tint(p.tint, remaining * 0.85))
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        let pos = add(e.pos, offset)
        let growth = limit(e.age / 0.15, 0.0, 1.0)
        let radius = 15.0 * growth + if e.flash > 0.0: 2.5 else: 0.0
        let angle = (clock * 27.0 + e.speed * 4.0) as f32
        let color = if e.flash > 0.0: white(1.0) else: lime(1.0)
        DrawPoly(rv(pos), 4, radius as f32, angle, ink(0.85))
        DrawPolyLinesEx(rv(pos), 4, radius as f32, angle, 8.0, lime(0.07))
        DrawPolyLinesEx(rv(pos), 4, radius as f32, angle, 3.5, lime(0.3))
        DrawPolyLinesEx(rv(pos), 4, radius as f32, angle, 2.0, color)
        DrawPolyLinesEx(rv(pos), 4, (radius * 0.69) as f32, -angle, 1.0, lime(0.8))
        circle(pos, 1.7, white(0.9))
        if e.age < 0.2:
            DrawCircleLinesV(rv(pos), (24.0 - growth * 7.0) as f32, lime((1.0 - growth) * 0.5))
    for i in 0..g.bullet_count:
        let b: Bullet = g.bullets[i]
        let pos = add(b.pos, offset)
        let tail = sub(pos, scale(b.vel, 0.065))
        line(tail, pos, 12.0, tint(2, 0.08))
        line(tail, pos, 5.0, tint(2, 0.55))
        line(sub(pos, scale(b.vel, 0.01)), pos, 2.0, white(1.0))
        circle(pos, 2.5, white(1.0))
    if g.health > 0:
        let pos = add(g.player, offset)
        let side = V2 { x: -g.aim.y, y: g.aim.x }
        let flicker = if g.invulnerable > 0.0 and (clock * 22.0) as i32 % 2 == 0: 0.3 else: 1.0
        // An open, double-chevron ship stays unique among closed enemies.
        let nose = add(pos, scale(g.aim, 15.0))
        let back = sub(pos, scale(g.aim, 10.0))
        let left = add(back, scale(side, 12.0))
        let right = sub(back, scale(side, 12.0))
        let notch = sub(pos, scale(g.aim, 2.0))
        glow_line(left, nose, white(flicker))
        glow_line(nose, right, white(flicker))
        glow_line(left, notch, cyan(flicker))
        glow_line(notch, right, cyan(flicker))
        let tip = add(pos, scale(g.aim, 24.0 - g.muzzle * 55.0))
        line(nose, tip, 2.0, white(flicker))
        if g.muzzle > 0.0:
            let front = add(pos, scale(g.aim, 31.0))
            circle(front, 12.0 * g.muzzle / 0.055, cyan(0.25))
            line(add(front, scale(side, -5.0)), add(front, scale(side, 5.0)), 2.0, white(1.0))
            line(front, add(front, scale(g.aim, 10.0)), 3.0, white(1.0))
        // A world-space aim marker stays consistent with the actual bullets.
        let reticle = add(pos, scale(g.aim, 85.0))
        DrawCircleLinesV(rv(reticle), 5.0, cyan(0.55))
        circle(reticle, 1.0, cyan(0.9))
    if g.flash > 0.0:
        DrawRectangle(0, 0, 1280, 800, white(g.flash * 0.10))
        DrawRectangle(0, 0, 1280, 9, magenta(g.flash))
        DrawRectangle(0, 791, 1280, 9, magenta(g.flash))
        DrawRectangle(0, 0, 9, 800, magenta(g.flash))
        DrawRectangle(1271, 0, 9, 800, magenta(g.flash))

fn render_hud(g: &Game, debug: bool, frame_ms: f64, best: f64) -> Unit:
    DrawRectangle(0, 0, 1280, 66, ink(1.0))
    label("WIPE", 26, 18, 30, rgba(178, 255, 88, 1.0))
    label("S U R V I V A L", 113, 27, 12, cyan(0.85))
    label("TIME", 468, 13, 10, cyan(0.7))
    label(stamp(g.elapsed), 468, 29, 23, white(1.0))
    label("KILLS", 638, 13, 10, cyan(0.7))
    label(f"{g.kills}", 638, 29, 23, white(1.0))
    label("INTEGRITY", 1036, 13, 10, cyan(0.7))
    for i in 0..3:
        DrawRectangle(1036 + i * 67, 33, 58, 8, if i < g.health: cyan(1.0) else: rgba(40, 50, 64, 1.0))
    DrawRectangle(0, 778, 1280, 22, ink(1.0))
    label("MOVE  WASD / LEFT STICK     AIM  MOUSE / RIGHT STICK     AUTO-FIRE", 26, 784, 10, white(0.45))
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
        DrawRectangle(0, 66, 1280, 712, ink(if g.freeze > 0.0: 0.25 else: 0.76))
        DrawRectangle(428, 278, 424, 254, ink(0.92))
        DrawRectangle(428, 278, 424, 2, magenta(1.0))
        centered("SIGNAL LOST", 300, 12, magenta(1.0))
        centered("YOU DIED", 333, 46, white(1.0))
        centered(f"TIME  {stamp(g.elapsed)}     KILLS  {g.kills}", 401, 20, white(0.8))
        centered("[ SPACE / A ]  RETRY", 460, 20, cyan(1.0))
        centered(f"SESSION BEST  {stamp(best)}", 505, 10, white(0.45))


// Full-resolution scene + quarter-resolution bright/blur surfaces. The
// final composite preserves sharp vector cores while adding genuine bloom.
pub type Renderer {
    scene: RenderTexture2D, bloom_a: RenderTexture2D, bloom_b: RenderTexture2D,
    grid: Effect, bright: Effect, blur: Effect, composite: Effect,
    ship_location: i32, count_location: i32, impulse_locations: Vec[i32],
    threshold_location: i32, direction_location: i32, bloom_location: i32,
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
    Renderer {
        scene: surface(WIDTH, HEIGHT), bloom_a: surface(320, 200), bloom_b: surface(320, 200),
        ship_location: grid.location("ship"), count_location: grid.location("impulseCount"),
        threshold_location: bright.location("threshold"), direction_location: blur.location("direction"),
        bloom_location: composite.location("bloom"), impulse_locations: locations,
        grid, bright, blur, composite,
    }
impl Drop for Renderer:
    move fn drop():
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
        IsRenderTextureValid(self.scene) and IsRenderTextureValid(self.bloom_a) and IsRenderTextureValid(self.bloom_b) and self.ship_location >= 0 and self.count_location >= 0 and self.threshold_location >= 0 and self.direction_location >= 0 and self.bloom_location >= 0 and self.impulse_locations[0] >= 0

    pub fn draw(self: &Self, g: &Game, clock: f64, debug: bool, frame_ms: f64, best: f64) -> f64:
        let started = GetTime()
        let shake = g.trauma * g.trauma * 8.0
        let offset = V2 { x: sin(clock * 83.0) * shake, y: cos(clock * 109.0) * shake }
        self.grid.vector4(self.ship_location, (g.player.x + offset.x) as f32, (g.player.y + offset.y) as f32, clock as f32, g.trauma as f32)
        let count = if g.pulse_count < 16: g.pulse_count else: 16
        self.grid.scalar(self.count_location, count as f32)
        for i in 0..count:
            let p: Pulse = g.pulses[i]
            self.grid.vector4(self.impulse_locations[i], (p.pos.x + offset.x) as f32, (p.pos.y + offset.y) as f32, (1.0 - p.life / p.total) as f32, p.radius as f32)
        BeginTextureMode(self.scene)
        ClearBackground(ink(1.0))
        self.grid.begin()
        DrawRectangle(0, 0, WIDTH, HEIGHT, WHITE)
        EndShaderMode()
        render_world(g, offset, clock)
        EndTextureMode()
        BeginTextureMode(self.bloom_a)
        ClearBackground(BLACK)
        self.bright.scalar(self.threshold_location, 0.42)
        self.bright.begin()
        blit(self.scene.texture, 320.0, 200.0)
        EndShaderMode()
        EndTextureMode()
        BeginTextureMode(self.bloom_b)
        ClearBackground(BLACK)
        self.blur.vector2(self.direction_location, 1.0 / 320.0, 0.0)
        self.blur.begin()
        blit(self.bloom_a.texture, 320.0, 200.0)
        EndShaderMode()
        EndTextureMode()
        BeginTextureMode(self.bloom_a)
        ClearBackground(BLACK)
        self.blur.vector2(self.direction_location, 0.0, 1.0 / 200.0)
        self.blur.begin()
        blit(self.bloom_b.texture, 320.0, 200.0)
        EndShaderMode()
        EndTextureMode()
        BeginDrawing()
        ClearBackground(ink(1.0))
        self.composite.begin()
        self.composite.texture(self.bloom_location, self.bloom_a.texture)
        blit(self.scene.texture, WIDTH as f64, HEIGHT as f64)
        EndShaderMode()
        render_hud(g, debug, frame_ms, best)
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
