use c_import("raylib.h")
use game
use loadout
use ships
use tuning
use shaders

// ----- palette and text ---------------------------------------------------

pub fn rgba(r: i32, g: i32, b: i32, a: f64) -> Color:
    Fade(Color { r: r as u8, g: g as u8, b: b as u8, a: 255 }, limit(a, 0.0, 1.0) as f32)
pub fn cyan(a: f64) -> Color: rgba(87, 237, 255, a)
pub fn magenta(a: f64) -> Color: rgba(255, 74, 220, a)
pub fn lime(a: f64) -> Color: rgba(105, 255, 56, a)
pub fn blue(a: f64) -> Color: rgba(118, 150, 255, a)
pub fn gold(a: f64) -> Color: rgba(255, 214, 92, a)
pub fn white(a: f64) -> Color: rgba(227, 248, 245, a)
pub fn red(a: f64) -> Color: rgba(255, 70, 70, a)
pub fn violet(a: f64) -> Color: rgba(176, 96, 255, a)
pub fn ink(a: f64) -> Color: rgba(3, 4, 14, a)
pub fn hud_lime(a: f64) -> Color: rgba(150, 255, 60, a)
pub fn dim(a: f64) -> Color: rgba(120, 140, 160, a)
pub fn paint(tint: Tint, alpha: f64) -> Color:
    match tint:
        .Cyan => cyan(alpha)
        .Magenta => magenta(alpha)
        .Gold => gold(alpha)
        .White => white(alpha)
        .Lime => lime(alpha)
        .Blue => blue(alpha)
        .Red => red(alpha)
        .Violet => violet(alpha)
pub fn rv(p: V2) -> Vector2: Vector2 { x: p.x as f32, y: p.y as f32 }
pub fn line(a: V2, b: V2, width: f64, color: Color):
    DrawLineEx(rv(a), rv(b), width as f32, color)
pub fn glow_line(a: V2, b: V2, color: Color):
    line(a, b, 6.0, Fade(color, 0.10))
    line(a, b, 3.0, Fade(color, 0.35))
    line(a, b, 1.6, color)
pub fn circle(p: V2, radius: f64, color: Color):
    DrawCircleV(rv(p), radius as f32, color)
pub fn ring(p: V2, radius: f64, color: Color):
    DrawCircleLinesV(rv(p), radius as f32, color)
pub fn label(text: str, x: i32, y: i32, size: i32, color: Color):
    DrawText(text, x, y, size, color)
// Bright text gets a soft duplicate underneath so bloom lifts it like the vectors.
pub fn neon(text: str, x: i32, y: i32, size: i32, color: Color):
    DrawText(text, x - 1, y, size, Fade(color, 0.28))
    DrawText(text, x + 1, y, size, Fade(color, 0.28))
    DrawText(text, x, y - 1, size, Fade(color, 0.22))
    DrawText(text, x, y + 1, size, Fade(color, 0.22))
    DrawText(text, x, y, size, color)
pub fn neon_right(text: str, right: i32, y: i32, size: i32, color: Color):
    neon(text, right - MeasureText(text, size), y, size, color)
pub fn centered(text: str, y: i32, size: i32, color: Color):
    neon(text, (WIDTH - MeasureText(text, size)) / 2, y, size, color)
pub fn centered_at(text: str, cx: i32, y: i32, size: i32, color: Color):
    neon(text, cx - MeasureText(text, size) / 2, y, size, color)
pub fn text_width(text: str, size: i32) -> i32: MeasureText(text, size)
pub fn stamp(seconds: f64) -> str:
    let total = seconds as i32
    let minutes = total / 60
    let secs = total % 60
    if secs < 10: f"{minutes}:0{secs}" else: f"{minutes}:{secs}"
pub fn commas(value: i32) -> str:
    if value < 0: "-" ++ commas(-value)
    else if value < 1000: f"{value}"
    else:
        let rest = value % 1000
        let head = commas(value / 1000)
        if rest < 10: f"{head},00{rest}" else if rest < 100: f"{head},0{rest}" else: f"{head},{rest}"
pub fn roman(level: i32) -> str:
    match level:
        1 => "I"
        2 => "II"
        3 => "III"
        4 => "IV"
        5 => "V"
        6 => "VI"
        7 => "VII"
        8 => "VIII"
        _ => f"{level}"
pub fn panel(x: i32, y: i32, w: i32, h: i32, accent: Color):
    DrawRectangle(x, y, w, h, ink(0.92))
    DrawRectangleLines(x, y, w, h, Fade(accent, 0.35))
    DrawRectangle(x, y, w, 2, accent)
pub fn mouse() -> V2:
    let m = GetMousePosition()
    V2 { x: m.x as f64, y: m.y as f64 }
pub fn inside(p: V2, x: i32, y: i32, w: i32, h: i32) -> bool:
    p.x >= x as f64 and p.x <= (x + w) as f64 and p.y >= y as f64 and p.y <= (y + h) as f64

// Polygon outline with a halo; bloom does the heavy lifting afterwards.
pub fn outline(pos: V2, sides: i32, radius: f64, angle: f64, color: Color, core: f64):
    DrawPolyLinesEx(rv(pos), sides, radius as f32, angle as f32, 5.0, Fade(color, 0.16))
    DrawPolyLinesEx(rv(pos), sides, radius as f32, angle as f32, core as f32, color)

// ----- silhouettes ---------------------------------------------------------

// Every ship is an open, asymmetric shape built from the claw's language.
pub fn draw_ship(ship: Ship, pos: V2, aim: V2, alpha: f64, scale_by: f64):
    let side = V2 { x: -aim.y, y: aim.x }
    let at = (f: f64, s: f64) => add(pos, add(scale(aim, f * scale_by), scale(side, s * scale_by)))
    let tint = white(alpha)
    // A locked ship is a greyed silhouette: no accent color.
    let accent = if alpha < 0.5: white(alpha * 0.7) else: match ship:
        .Claw => cyan(alpha * 0.8)
        .Dart => blue(alpha * 0.9)
        .Hull => lime(alpha * 0.8)
        .Prism => magenta(alpha * 0.8)
        .Halo => gold(alpha * 0.8)
        .Needle => red(alpha * 0.8)
        .Sapper => gold(alpha * 0.9)
        .Phase => violet(alpha * 0.9)
        .Null => white(alpha * 0.5)
    match ship:
        .Dart => {
            glow_line(at(-10.0, 9.0), at(18.0, 0.0), tint)
            glow_line(at(18.0, 0.0), at(-10.0, -9.0), tint)
            glow_line(at(-10.0, 9.0), at(-16.0, 4.0), accent)
            glow_line(at(-10.0, -9.0), at(-16.0, -4.0), accent)
            glow_line(at(-4.0, 0.0), at(-14.0, 0.0), accent)
        }
        .Hull => {
            glow_line(at(-10.0, 14.0), at(12.0, 8.0), tint)
            glow_line(at(12.0, 8.0), at(16.0, 0.0), tint)
            glow_line(at(16.0, 0.0), at(12.0, -8.0), tint)
            glow_line(at(12.0, -8.0), at(-10.0, -14.0), tint)
            glow_line(at(-10.0, 14.0), at(-14.0, 0.0), accent)
            glow_line(at(-14.0, 0.0), at(-10.0, -14.0), accent)
            glow_line(at(-4.0, 6.0), at(4.0, 0.0), accent)
            glow_line(at(4.0, 0.0), at(-4.0, -6.0), accent)
        }
        .Prism => {
            glow_line(at(16.0, 0.0), at(-8.0, 12.0), tint)
            glow_line(at(-8.0, 12.0), at(-12.0, 0.0), accent)
            glow_line(at(-12.0, 0.0), at(-8.0, -12.0), accent)
            glow_line(at(-8.0, -12.0), at(16.0, 0.0), tint)
            glow_line(at(-12.0, 0.0), at(4.0, 0.0), accent)
        }
        .Halo => {
            glow_line(at(14.0, 0.0), at(-6.0, 10.0), tint)
            glow_line(at(14.0, 0.0), at(-6.0, -10.0), tint)
            DrawCircleLinesV(rv(pos), (13.0 * scale_by) as f32, accent)
            glow_line(at(-6.0, 10.0), at(-12.0, 0.0), accent)
            glow_line(at(-6.0, -10.0), at(-12.0, 0.0), accent)
        }
        .Needle => {
            glow_line(at(22.0, 0.0), at(-12.0, 4.0), tint)
            glow_line(at(22.0, 0.0), at(-12.0, -4.0), tint)
            glow_line(at(-12.0, 4.0), at(-16.0, 9.0), accent)
            glow_line(at(-12.0, -4.0), at(-16.0, -9.0), accent)
        }
        .Sapper => {
            glow_line(at(12.0, 0.0), at(-8.0, 12.0), tint)
            glow_line(at(12.0, 0.0), at(-8.0, -12.0), tint)
            glow_line(at(-8.0, 12.0), at(-14.0, 12.0), accent)
            glow_line(at(-8.0, -12.0), at(-14.0, -12.0), accent)
            glow_line(at(-14.0, 12.0), at(-10.0, 0.0), accent)
            glow_line(at(-14.0, -12.0), at(-10.0, 0.0), accent)
        }
        .Phase => {
            glow_line(at(15.0, 0.0), at(-7.0, 13.0), tint)
            glow_line(at(15.0, 0.0), at(-7.0, -13.0), tint)
            glow_line(at(-2.0, 6.0), at(-12.0, 0.0), accent)
            glow_line(at(-12.0, 0.0), at(-2.0, -6.0), accent)
        }
        .Null => {
            glow_line(at(15.0, 0.0), at(-7.0, 13.0), tint)
            glow_line(at(-7.0, 13.0), at(-7.0, -13.0), accent)
            glow_line(at(-7.0, -13.0), at(15.0, 0.0), tint)
            glow_line(at(-2.0, 0.0), at(-14.0, 0.0), accent)
        }
        .Claw => {
            let nose = at(15.0, 0.0)
            let left = at(-7.0, 13.0)
            let right = at(-7.0, -13.0)
            let left_tail = at(-14.0, 6.0)
            let right_tail = at(-14.0, -6.0)
            let notch = at(-3.0, 0.0)
            let left_inner = at(-9.0, 7.0)
            let right_inner = at(-9.0, -7.0)
            glow_line(left, nose, tint)
            glow_line(nose, right, tint)
            glow_line(left, left_tail, tint)
            glow_line(right, right_tail, tint)
            glow_line(left_inner, notch, white(alpha * 0.9))
            glow_line(notch, right_inner, white(alpha * 0.9))
            glow_line(left_inner, left_tail, accent)
            glow_line(right_inner, right_tail, accent)
        }

pub fn draw_enemy(kind: Kind, pos: V2, radius: f64, clock: f64, speed: f64, toward: V2, color: Color, dim_by: f64):
    match kind:
        .Spinner => {
            // Spinner: a fast diamond with a cross through it.
            let angle = clock * 150.0 + speed * 3.0
            outline(pos, 4, radius, angle, color, 2.0)
            let rad = angle * 0.0174533
            let a = V2 { x: cos(rad), y: sin(rad) }
            let b = V2 { x: -a.y, y: a.x }
            line(sub(pos, scale(a, radius)), add(pos, scale(a, radius)), 1.3, Fade(color, dim_by))
            line(sub(pos, scale(b, radius)), add(pos, scale(b, radius)), 1.3, Fade(color, dim_by))
        }
        .Dart => {
            // Dart: an arrowhead that faces its target.
            let heading = atan2(toward.y, toward.x) * 57.2958
            outline(pos, 3, radius, heading, color, 2.4)
            let back = sub(pos, scale(toward, radius * 0.5))
            let side = V2 { x: -toward.y, y: toward.x }
            line(add(back, scale(side, radius * 0.45)), sub(back, scale(side, radius * 0.45)), 1.3, Fade(color, dim_by))
        }
        .Weaver => {
            // Weaver: nested squares turning against each other.
            let angle = clock * 40.0 + speed
            outline(pos, 4, radius, angle, color, 2.0)
            DrawPolyLinesEx(rv(pos), 4, (radius * 0.62) as f32, (-angle * 1.5) as f32, 1.4, Fade(color, dim_by))
            DrawPolyLinesEx(rv(pos), 4, (radius * 0.3) as f32, angle as f32, 1.0, Fade(color, dim_by))
        }
        .Skimmer => {
            // Skimmer: a thin chevron that always faces its target.
            let side = V2 { x: -toward.y, y: toward.x }
            let nose = add(pos, scale(toward, radius))
            let l = add(sub(pos, scale(toward, radius * 0.7)), scale(side, radius))
            let r = sub(sub(pos, scale(toward, radius * 0.7)), scale(side, radius))
            glow_line(l, nose, color)
            glow_line(nose, r, color)
            line(l, sub(pos, scale(toward, radius * 0.2)), 1.2, Fade(color, dim_by))
            line(r, sub(pos, scale(toward, radius * 0.2)), 1.2, Fade(color, dim_by))
        }
        .Well => {
            // Well: concentric rings turning inward, a dark center.
            for i in 0..3:
                let r = radius * (1.0 - i as f64 * 0.28)
                DrawPolyLinesEx(rv(pos), 8, r as f32, (clock * (40.0 + i as f64 * 30.0) * (if i % 2 == 0: 1.0 else: -1.0)) as f32, 1.4, Fade(color, 0.9 - i as f64 * 0.2))
            circle(pos, radius * 0.22, ink(1.0))
            ring(pos, radius * 1.6 + sin(clock * 3.0) * 4.0, Fade(color, 0.18))
        }
        .Boss => {
            // Boss: a heavy hexagon with a rotating inner triangle and spokes.
            let angle = clock * 20.0
            DrawPolyLinesEx(rv(pos), 6, radius as f32, angle as f32, 9.0, Fade(color, 0.16))
            DrawPolyLinesEx(rv(pos), 6, radius as f32, angle as f32, 3.0, color)
            DrawPolyLinesEx(rv(pos), 3, (radius * 0.6) as f32, (-angle * 2.0) as f32, 2.0, Fade(color, dim_by))
            for i in 0..6:
                let a = (angle + i as f64 * 60.0) * 0.0174533
                line(pos, add(pos, V2 { x: cos(a) * radius, y: sin(a) * radius }), 1.2, Fade(color, dim_by * 0.6))
        }
        .Null => {
            // The Null: an absence. A ring of nothing with a white edge.
            circle(pos, radius, ink(1.0))
            DrawCircleLinesV(rv(pos), (radius + 4.0) as f32, Fade(color, 0.2))
            DrawCircleLinesV(rv(pos), radius as f32, color)
            for i in 0..12:
                let a = clock * 1.4 + i as f64 * 0.5236
                let r0 = radius * 1.05
                let r1 = radius * (1.25 + 0.15 * sin(clock * 5.0 + i as f64))
                line(add(pos, V2 { x: cos(a) * r0, y: sin(a) * r0 }), add(pos, V2 { x: cos(a) * r1, y: sin(a) * r1 }), 1.5, Fade(color, 0.7))
        }
        .Block => {
            // Block: a square framing a slowly counter-rotating diamond.
            let angle = clock * 27.0 + speed * 4.0
            outline(pos, 4, radius, angle, color, 2.0)
            DrawPolyLinesEx(rv(pos), 4, (radius * 0.66) as f32, (-angle + 45.0) as f32, 1.4, Fade(color, dim_by))
        }

// Small glyphs for weapons and passives: the same vector language at HUD size.
pub fn weapon_tint(weapon: Weapon) -> Color:
    match weapon.family():
        .Aimed => gold(1.0)
        .Orbiting => cyan(1.0)
        .Ring => cyan(1.0)
        .Homing => blue(1.0)
        .Beam => red(1.0)
        .Dropped => gold(1.0)
        .Chain => violet(1.0)
        .Bouncing => magenta(1.0)
pub fn draw_weapon_icon(weapon: Weapon, pos: V2, size: f64, clock: f64, alpha: f64):
    let color = Fade(weapon_tint(weapon), alpha as f32)
    let merged = weapon.is_merged()
    match weapon.family():
        .Aimed => {
            line(add(pos, V2 { x: -size, y: 0.0 }), add(pos, V2 { x: size, y: 0.0 }), 2.0, color)
            circle(add(pos, V2 { x: size * 0.6 }), size * 0.25, white(alpha))
            if merged: line(add(pos, V2 { x: -size, y: -size * 0.4 }), add(pos, V2 { x: size, y: -size * 0.4 }), 1.0, color)
        }
        .Orbiting => {
            ring(pos, size * 0.8, color)
            for i in 0..(if merged: 4 else: 2):
                let a = clock * 2.0 + i as f64 * 3.14159 / (if merged: 2.0 else: 1.0)
                circle(add(pos, V2 { x: cos(a) * size * 0.8, y: sin(a) * size * 0.8 }), size * 0.2, white(alpha))
        }
        .Ring => {
            ring(pos, size * (0.5 + 0.4 * ((clock * 1.5) % 1.0)), color)
            ring(pos, size * 0.3, color)
            if merged: ring(pos, size * 1.05, Fade(color, 0.5))
        }
        .Homing => {
            let a = clock * 3.0
            let tip = add(pos, V2 { x: cos(a) * size * 0.8, y: sin(a) * size * 0.8 })
            line(pos, tip, 2.0, color)
            circle(tip, size * 0.25, white(alpha))
            if merged: line(pos, add(pos, V2 { x: cos(a + 2.1) * size * 0.8, y: sin(a + 2.1) * size * 0.8 }), 1.5, color)
        }
        .Beam => {
            line(add(pos, V2 { x: -size, y: 0.0 }), add(pos, V2 { x: size, y: 0.0 }), if merged: 5.0 else: 3.0, Fade(color, 0.5))
            line(add(pos, V2 { x: -size, y: 0.0 }), add(pos, V2 { x: size, y: 0.0 }), 1.5, white(alpha))
        }
        .Dropped => {
            DrawPolyLinesEx(rv(pos), 3, (size * 0.8) as f32, -90.0, 2.0, color)
            circle(pos, size * 0.2, white(alpha))
            if merged: DrawPolyLinesEx(rv(pos), 3, (size * 1.1) as f32, -90.0, 1.0, Fade(color, 0.5))
        }
        .Chain => {
            let a = add(pos, V2 { x: -size, y: -size * 0.6 })
            let b = add(pos, V2 { x: -size * 0.2, y: size * 0.3 })
            let c = add(pos, V2 { x: size * 0.3, y: -size * 0.3 })
            let d = add(pos, V2 { x: size, y: size * 0.6 })
            line(a, b, 2.0, color)
            line(b, c, 2.0, color)
            line(c, d, 2.0, color)
            if merged: line(a, d, 1.0, Fade(color, 0.5))
        }
        .Bouncing => {
            let a = add(pos, V2 { x: -size, y: size * 0.7 })
            let b = add(pos, V2 { x: -size * 0.3, y: -size * 0.7 })
            let c = add(pos, V2 { x: size * 0.4, y: size * 0.7 })
            let d = add(pos, V2 { x: size, y: -size * 0.4 })
            line(a, b, 2.0, color)
            line(b, c, 2.0, color)
            line(c, d, 2.0, color)
            if merged: circle(d, size * 0.25, white(alpha))
        }
pub fn draw_passive_icon(passive: Passive, pos: V2, size: f64, alpha: f64):
    let color = lime(alpha)
    match passive:
        .Damage => { DrawPolyLinesEx(rv(pos), 3, size as f32, -90.0, 2.0, color) }
        .FireRate => {
            for i in 0..3: line(add(pos, V2 { x: -size + i as f64 * size * 0.7, y: size * 0.5 }), add(pos, V2 { x: -size * 0.5 + i as f64 * size * 0.7, y: -size * 0.5 }), 1.8, color)
        }
        .Count => {
            for i in 0..3: circle(add(pos, V2 { x: (i as f64 - 1.0) * size * 0.7 }), size * 0.22, color)
        }
        .Area => { ring(pos, size, color); ring(pos, size * 0.5, color) }
        .ProjSpeed => {
            line(add(pos, V2 { x: -size }), add(pos, V2 { x: size }), 2.0, color)
            line(add(pos, V2 { x: size * 0.3, y: -size * 0.5 }), add(pos, V2 { x: size }), 2.0, color)
            line(add(pos, V2 { x: size * 0.3, y: size * 0.5 }), add(pos, V2 { x: size }), 2.0, color)
        }
        .Magnet => {
            ring(pos, size * 0.9, Fade(color, 0.4))
            ring(pos, size * 0.5, color)
            circle(pos, size * 0.15, color)
        }
        .Speed => {
            for i in 0..3: line(add(pos, V2 { x: -size, y: (i as f64 - 1.0) * size * 0.5 }), add(pos, V2 { x: size * (0.2 + i as f64 * 0.3), y: (i as f64 - 1.0) * size * 0.5 }), 1.8, color)
        }
        .Health => { DrawPolyLinesEx(rv(pos), 6, size as f32, 0.0, 2.0, color) }
        .Cooldown => {
            ring(pos, size, color)
            line(pos, add(pos, V2 { y: -size * 0.8 }), 1.8, color)
            line(pos, add(pos, V2 { x: size * 0.5 }), 1.8, color)
        }
        .Armor => { DrawPolyLinesEx(rv(pos), 4, size as f32, 45.0, 2.4, color); DrawPolyLinesEx(rv(pos), 4, (size * 0.5) as f32, 45.0, 1.2, color) }
        .Luck => { DrawPolyLinesEx(rv(pos), 5, size as f32, -90.0, 2.0, gold(alpha)) }
        .Credit => { ring(pos, size * 0.9, gold(alpha)); label("c", (pos.x - 3.0) as i32, (pos.y - 6.0) as i32, 12, gold(alpha)) }
        .Rebound => {
            line(add(pos, V2 { x: -size, y: size * 0.6 }), add(pos, V2 { x: 0.0, y: -size * 0.6 }), 2.0, color)
            line(add(pos, V2 { x: 0.0, y: -size * 0.6 }), add(pos, V2 { x: size, y: size * 0.6 }), 2.0, color)
            line(add(pos, V2 { x: -size * 1.1, y: -size * 0.6 }), add(pos, V2 { x: size * 1.1, y: -size * 0.6 }), 1.0, Fade(color, 0.6))
        }
        .Overclock => {
            DrawPolyLinesEx(rv(pos), 3, size as f32, 90.0, 2.0, red(alpha))
            line(add(pos, V2 { y: -size * 0.4 }), add(pos, V2 { y: size * 0.3 }), 1.6, red(alpha))
        }

pub fn draw_pick_icon(pick: Pick, pos: V2, size: f64, clock: f64, alpha: f64):
    match pick:
        .NewWeapon(w) => draw_weapon_icon(w, pos, size, clock, alpha)
        .UpgradeWeapon(w) => draw_weapon_icon(w, pos, size, clock, alpha)
        .Merge(w) => draw_weapon_icon(w, pos, size, clock, alpha)
        .NewPassive(p) => draw_passive_icon(p, pos, size, alpha)
        .UpgradePassive(p) => draw_passive_icon(p, pos, size, alpha)

// ----- the world -------------------------------------------------------------

// Screen-space camera for one frame: world origin plus shake.
pub type Camera { origin: V2 = V2 {}, shake: V2 = V2 {} }
impl Copy for Camera
pub fn to_screen(cam: Camera, p: V2) -> V2: add(sub(p, cam.origin), cam.shake)

fn render_world(g: &Game, cam: Camera, clock: f64) -> Unit:
    let arena_origin = to_screen(cam, V2 {})
    let arena = Rectangle { x: arena_origin.x as f32, y: arena_origin.y as f32, width: g.rules.arena_width as f32, height: g.rules.arena_height as f32 }
    // The containment edge: a glowing geometric boundary, never terrain.
    DrawRectangleLinesEx(arena, 9.0, cyan(0.08))
    DrawRectangleLinesEx(arena, 3.0, cyan(0.55 + 0.1 * sin(clock * 2.0)))
    DrawRectangleLinesEx(arena, 1.0, white(0.6))
    if g.rules.void_radius > 0.0:
        let void_center = to_screen(cam, g.center())
        circle(void_center, g.rules.void_radius, ink(0.9))
        ring(void_center, g.rules.void_radius + 4.0, cyan(0.08))
        DrawCircleLinesV(rv(void_center), g.rules.void_radius as f32, cyan(0.55 + 0.1 * sin(clock * 2.0)))
        ring(void_center, g.rules.void_radius - 2.0, white(0.5))
    // Decorative effects render underneath all solid gameplay silhouettes.
    for i in 0..g.pulse_count:
        let p: Pulse = g.pulses[i]
        let remaining = p.life / p.total
        let pos = to_screen(cam, p.pos)
        let radius = 6.0 + (1.0 - remaining) * p.radius
        DrawCircleLinesV(rv(pos), radius as f32, paint(p.tint, remaining * 0.5))
        // A rapidly shrinking remnant gives an enemy's death a visible scale-out.
        if let Some(kind) = p.remnant:
            let size = 15.0 * remaining * remaining
            draw_enemy(kind, pos, size, clock, 0.0, V2 { x: 1.0, y: 0.0 }, paint(p.tint, remaining), 0.6)
    for i in 0..g.wave_count:
        let w: Shockwave = g.waves[i]
        let pos = to_screen(cam, w.pos)
        let remaining = w.life / w.total
        DrawCircleLinesV(rv(pos), w.radius as f32, cyan(0.2 + remaining * 0.6))
        DrawCircleLinesV(rv(pos), (w.radius - 4.0) as f32, white(remaining * 0.5))
        ring(pos, w.radius + 6.0, cyan(remaining * 0.15))
    for i in 0..g.particle_count:
        let p: Particle = g.particles[i]
        if not g.on_screen(p.pos, 20.0): continue
        let remaining = p.life / p.total
        let pos = to_screen(cam, p.pos)
        // Sparks are streaks whose length follows their speed, settling to dots.
        let speed = sqrt(length2(p.vel))
        let heading = if speed > 1.0: scale(p.vel, 1.0 / speed) else: V2 { x: cos(p.rotation), y: sin(p.rotation) }
        let tail = sub(pos, scale(heading, 3.0 + speed * 0.055))
        let color = paint(p.tint, remaining)
        line(pos, tail, p.size + 2.6, Fade(color, remaining * 0.18))
        line(pos, tail, p.size, color)
        if remaining > 0.7: line(pos, sub(pos, scale(heading, 2.0 + speed * 0.012)), p.size * 0.7, white((remaining - 0.7) * 2.5))
    // Cores: small cyan diamonds, larger when merged.
    for i in 0..g.core_count:
        let c: Core = g.cores[i]
        if not g.on_screen(c.pos, 20.0): continue
        let pos = to_screen(cam, c.pos)
        let size = 4.0 + limit((c.value as f64), 1.0, 40.0) * 0.35
        let pulse = 0.75 + 0.25 * sin(clock * 6.0 + c.pos.x * 0.05)
        DrawPolyLinesEx(rv(pos), 4, size as f32, (clock * 90.0) as f32, 1.6, cyan(pulse))
        circle(pos, size * 0.3, white(pulse * 0.8))
    // Beacons: gold hexagons, the reason to cross the arena.
    for i in 0..g.beacon_count:
        let b: Beacon = g.beacons[i]
        if not b.alive: continue
        let pos = to_screen(cam, b.pos)
        let spin = clock * 30.0
        DrawPolyLinesEx(rv(pos), 6, 18.0, spin as f32, 6.0, gold(0.14))
        DrawPolyLinesEx(rv(pos), 6, 18.0, spin as f32, 2.0, gold(0.9))
        DrawPolyLinesEx(rv(pos), 6, 9.0, (-spin) as f32, 1.4, white(0.7 + 0.3 * sin(clock * 5.0)))
        ring(pos, 26.0 + 4.0 * sin(clock * 3.0), gold(0.25))
    // Pickups: brighter than cores, labeled.
    for i in 0..g.pickup_count:
        let p: Pickup = g.pickups[i]
        let pos = to_screen(cam, p.pos)
        let color = match p.kind:
            .Cache => gold(1.0)
            .Credits => gold(1.0)
            .Bundle => gold(1.0)
            .Repair => lime(1.0)
            .Freeze => blue(1.0)
            .Clear => white(1.0)
            .Tractor => cyan(1.0)
        let bob = sin(clock * 4.0 + p.pos.y) * 3.0
        let at = add(pos, V2 { y: bob })
        match p.kind:
            .Cache => {
                DrawPolyLinesEx(rv(at), 4, 16.0, 45.0, 6.0, Fade(color, 0.18))
                DrawPolyLinesEx(rv(at), 4, 16.0, 45.0, 2.2, color)
                DrawPolyLinesEx(rv(at), 4, 8.0, (clock * 120.0) as f32, 1.4, white(1.0))
            }
            _ => {
                ring(at, 12.0, Fade(color, 0.25))
                DrawPolyLinesEx(rv(at), 6, 11.0, (clock * 50.0) as f32, 2.0, color)
                circle(at, 3.0, white(1.0))
            }
        centered_at(p.kind.name(), at.x as i32, (at.y - 30.0) as i32, 10, Fade(color, 0.8))
    // Mines.
    for i in 0..g.mine_count:
        let m: Mine = g.mines[i]
        let pos = to_screen(cam, m.pos)
        let armed = 0.6 + 0.4 * sin(clock * 8.0 + m.age)
        DrawPolyLinesEx(rv(pos), 3, 10.0, (clock * 60.0) as f32, 2.0, gold(armed))
        circle(pos, 2.5, red(armed))
        ring(pos, m.radius, gold(0.05))
    // Beams.
    for i in 0..g.beam_count:
        let b: Beam = g.beams[i]
        let remaining = b.life / b.total
        let a = to_screen(cam, b.a)
        let e = to_screen(cam, b.b)
        line(a, e, b.width * remaining * 2.0, red(0.12 * remaining))
        line(a, e, b.width * remaining, red(0.6 * remaining))
        line(a, e, 2.0, white(remaining))
    // Arcs: jagged lightning.
    for i in 0..g.arc_count:
        let bolt: ArcBolt = g.arcs[i]
        let remaining = bolt.life / bolt.total
        let a = to_screen(cam, bolt.a)
        let e = to_screen(cam, bolt.b)
        let delta = sub(e, a)
        let side = perpendicular(direction(delta))
        var last = a
        for k in 1..6:
            let t = k as f64 / 6.0
            let jag = sin(clock * 60.0 + k as f64 * 2.3 + bolt.a.x) * 9.0 * (1.0 - remaining * 0.5)
            let next = if k == 6: e else: add(add(a, scale(delta, t)), scale(side, jag))
            line(last, next, 5.0, violet(0.15 * remaining))
            line(last, next, 1.8, violet(0.9 * remaining))
            line(last, next, 0.9, white(remaining))
            last = next
        line(last, e, 1.8, violet(0.9 * remaining))
    // Orbit blades are positions on a ring around the ship.
    for slot in 0..SLOT_COUNT:
        let s: WeaponSlot = g.build.weapons[slot]
        if s.level == 0 or s.weapon.family() != .Orbiting: continue
        let stats = weapon_stats(s.weapon, s.level, g.mods)
        let ship = to_screen(cam, g.player)
        ring(ship, stats.radius, cyan(0.10))
        for b in 0..stats.count:
            let angle = s.phase + (b as f64) * 6.283185307 / stats.count as f64
            let blade = add(ship, V2 { x: cos(angle) * stats.radius, y: sin(angle) * stats.radius })
            let tangent = V2 { x: -sin(angle), y: cos(angle) }
            glow_line(sub(blade, scale(tangent, 10.0)), add(blade, scale(tangent, 10.0)), cyan(1.0))
            circle(blade, 3.0, white(1.0))
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        if not g.on_screen(e.pos, 120.0): continue
        let pos = to_screen(cam, e.pos)
        let growth = limit(e.age / 0.18, 0.0, 1.0)
        let radius = e.kind.radius() * e.size * growth + if e.flash > 0.0: 2.5 else: 0.0
        let color = if e.flash > 0.0: white(1.0) else: paint(e.kind.tint(), 1.0)
        let toward = direction(sub(g.player, e.pos))
        draw_enemy(e.kind, pos, radius, clock, e.speed, toward, color, 0.85)
        if e.elite:
            // Elites carry a slow outer ring and a brighter core.
            DrawPolyLinesEx(rv(pos), 8, (radius + 9.0) as f32, (clock * -30.0) as f32, 1.4, Fade(color, 0.6))
            circle(pos, 3.0, white(1.0))
        if e.age < 0.25:
            DrawCircleLinesV(rv(pos), (30.0 - growth * 12.0) as f32, Fade(color, (1.0 - growth) * 0.7))
        // Spinners and bosses telegraph their charge with a line to the ship.
        if (e.kind == .Spinner or e.kind == .Boss) and e.state == 1:
            let reach = if e.kind == .Boss: 500.0 else: 220.0
            line(pos, add(pos, scale(toward, reach)), 1.2, Fade(color, 0.25 + 0.2 * sin(clock * 40.0)))
    for i in 0..g.bullet_count:
        let b: Bullet = g.bullets[i]
        if not g.on_screen(b.pos, 40.0): continue
        let pos = to_screen(cam, b.pos)
        let heading = direction(b.vel)
        let side = perpendicular(heading)
        if b.hostile:
            // Weaver bolts: slow, red, unmistakable.
            ring(pos, 7.0, red(0.9))
            circle(pos, 3.0, red(1.0))
            ring(pos, 11.0 + 2.0 * sin(clock * 10.0), red(0.25))
            continue
        let color = weapon_tint(b.weapon)
        match b.weapon.family():
            .Bouncing => {
                DrawPolyLinesEx(rv(pos), 3, 7.0, (clock * 400.0 + b.pos.x) as f32, 1.8, color)
                line(sub(pos, scale(heading, 14.0)), pos, 3.0, Fade(color, 0.3))
            }
            .Homing => {
                line(sub(pos, scale(heading, 18.0)), pos, 4.0, Fade(color, 0.25))
                line(sub(pos, scale(heading, 18.0)), pos, 1.6, color)
                circle(pos, 2.6, white(1.0))
            }
            _ => {
                // Twin streaks with a white-hot head.
                let lanes = if b.pierce > 10: 3 else: 2
                for lane in 0..lanes:
                    let shift = scale(side, (lane as f64 - (lanes as f64 - 1.0) / 2.0) * 4.4)
                    let head = add(pos, shift)
                    let tail = sub(head, scale(heading, 26.0))
                    line(tail, head, 5.0, Fade(color, 0.14))
                    line(tail, head, 1.6, Fade(color, 0.9))
                    line(sub(head, scale(heading, 9.0)), head, 1.8, white(1.0))
                circle(pos, 2.2, white(1.0))
            }
    if g.health > 0:
        let pos = to_screen(cam, g.player)
        let flicker = if g.invulnerable > 0.0 and (clock * 22.0) as i32 % 2 == 0: 0.3 else: 1.0
        draw_ship(g.launch.ship, pos, g.aim, flicker, 1.0)
        if g.muzzle > 0.0:
            let front = add(pos, scale(g.aim, 30.0))
            let side = perpendicular(g.aim)
            circle(front, 10.0 * g.muzzle / 0.055, gold(0.16))
            line(add(front, scale(side, -5.0)), add(front, scale(side, 5.0)), 2.0, white(1.0))
            line(front, add(front, scale(g.aim, 12.0)), 3.0, white(1.0))
        // Health as a bar under the ship.
        let width = 34.0
        let fraction = limit(g.health as f64 / g.max_health as f64, 0.0, 1.0)
        let bar = add(pos, V2 { x: -width / 2.0, y: 24.0 })
        DrawRectangle(bar.x as i32, bar.y as i32, width as i32, 3, ink(0.7))
        DrawRectangle(bar.x as i32, bar.y as i32, (width * fraction) as i32, 3, if fraction > 0.5: lime(0.9) else if fraction > 0.25: gold(0.9) else: red(1.0))
        // Magnet radius, faint.
        ring(pos, g.rules.magnet_radius * g.mods.magnet, cyan(0.05))
    for i in 0..g.popup_count:
        let p: Popup = g.popups[i]
        let remaining = p.life / p.total
        let pos = to_screen(cam, p.pos)
        let alpha = limit(remaining * 1.6, 0.0, 1.0)
        match p.kind:
            .Credits(v) => centered_at(f"+{v} CREDIT", pos.x as i32, pos.y as i32 - 8, 14, gold(alpha))
            .Level(l) => centered_at(f"LEVEL {l}", pos.x as i32, pos.y as i32 - 30, 22, lime(alpha))
            .Pickup(k) => centered_at(k.name(), pos.x as i32, pos.y as i32 - 8, 14, white(alpha))
            .Xp(v) => centered_at(f"{v}", pos.x as i32, pos.y as i32 - 8, 12, cyan(alpha))
    // Event telegraph: a glow on the side the formation arrives from.
    if g.event_telegraph > 0.0:
        let strength = 0.35 + 0.35 * sin(clock * 18.0)
        let thick = 22
        match g.event_side:
            0 => DrawRectangleGradientH(0, 0, thick * 3, HEIGHT, magenta(strength), magenta(0.0))
            1 => DrawRectangleGradientH(WIDTH - thick * 3, 0, thick * 3, HEIGHT, magenta(0.0), magenta(strength))
            2 => DrawRectangleGradientV(0, 0, WIDTH, thick * 3, magenta(strength), magenta(0.0))
            _ => DrawRectangleGradientV(0, HEIGHT - thick * 3, WIDTH, thick * 3, magenta(0.0), magenta(strength))
    if g.flash > 0.0:
        DrawRectangle(0, 0, WIDTH, HEIGHT, white(g.flash * 0.10))
        DrawRectangle(0, 0, WIDTH, 9, magenta(g.flash))
        DrawRectangle(0, HEIGHT - 9, WIDTH, 9, magenta(g.flash))
        DrawRectangle(0, 0, 9, HEIGHT, magenta(g.flash))
        DrawRectangle(WIDTH - 9, 0, 9, HEIGHT, magenta(g.flash))
    if g.enemies_frozen > 0.0:
        DrawRectangle(0, 0, WIDTH, HEIGHT, blue(0.06))

// An indicator at the screen edge pointing at an off-screen world position.
fn edge_indicator(g: &Game, cam: Camera, target: V2, color: Color, size: f64, clock: f64):
    if g.on_screen(target, -10.0): return
    let center = V2 { x: WIDTH as f64 / 2.0, y: HEIGHT as f64 / 2.0 }
    let screen = to_screen(cam, target)
    let delta = sub(screen, center)
    let heading = direction(delta)
    // Clamp the direction to the screen rectangle with a margin.
    let margin = 30.0
    let sx = if heading.x > 0.0001: (WIDTH as f64 - margin - center.x) / heading.x else if heading.x < -0.0001: (margin - center.x) / heading.x else: 1.0e9
    let sy = if heading.y > 0.0001: (HEIGHT as f64 - 80.0 - center.y) / heading.y else if heading.y < -0.0001: (60.0 - center.y) / heading.y else: 1.0e9
    let t = if sx < sy: sx else: sy
    let at = add(center, scale(heading, t))
    let side = perpendicular(heading)
    let tip = add(at, scale(heading, size))
    let l = add(sub(at, scale(heading, size * 0.5)), scale(side, size * 0.7))
    let r = sub(sub(at, scale(heading, size * 0.5)), scale(side, size * 0.7))
    let pulse = 0.6 + 0.4 * sin(clock * 6.0)
    line(l, tip, 2.0, Fade(color, pulse))
    line(tip, r, 2.0, Fade(color, pulse))
    line(l, r, 1.0, Fade(color, pulse * 0.5))

fn render_indicators(g: &Game, cam: Camera, clock: f64):
    for i in 0..g.pickup_count:
        let p: Pickup = g.pickups[i]
        let color = if p.kind == .Cache: gold(1.0) else: white(0.8)
        edge_indicator(g, cam, p.pos, color, if p.kind == .Cache: 14.0 else: 9.0, clock)
    for i in 0..g.beacon_count:
        let b: Beacon = g.beacons[i]
        if b.alive: edge_indicator(g, cam, b.pos, gold(0.6), 9.0, clock)
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        if e.kind == .Boss or e.kind == .Null: edge_indicator(g, cam, e.pos, paint(e.kind.tint(), 1.0), 18.0, clock)
        else if e.elite: edge_indicator(g, cam, e.pos, paint(e.kind.tint(), 0.8), 11.0, clock)

// ----- HUD ---------------------------------------------------------------------

// What the account layer knows and the HUD shows.
pub type Hud { best_time: f64 = 0.0, bank: i32 = 0, show_hints: bool = true }
impl Copy for Hud

fn render_hud(g: &Game, hud: Hud, clock: f64) -> Unit:
    // Top: the level-up bar with the level number, combo, timer, credits.
    DrawRectangle(0, 0, WIDTH, 8, ink(0.8))
    let fraction = limit(g.xp as f64 / g.xp_next as f64, 0.0, 1.0)
    DrawRectangle(0, 0, (WIDTH as f64 * fraction) as i32, 8, lime(0.85))
    DrawRectangle((WIDTH as f64 * fraction) as i32 - 3, 0, 3, 8, white(1.0))
    neon(f"LV {g.level}", 22, 16, 28, hud_lime(1.0))
    if g.combo > 1:
        let size = if g.combo >= 50: 34 else if g.combo >= 20: 30 else: 26
        neon(f"x{g.combo}", 130, 16, size, if g.combo >= 50: gold(1.0) else: cyan(1.0))
        let fade = limit(g.combo_timer / g.rules.combo_window, 0.0, 1.0)
        DrawRectangle(130, 48, (60.0 * fade) as i32, 3, cyan(0.8))
    // Timer with the best-time marker.
    let timer_color = if g.best_crossed: gold(1.0) else: white(1.0)
    let time_text = if g.best_flare > 0.0 and (clock * 4.0) as i32 % 2 == 0: "NEW BEST" else: stamp(g.elapsed)
    centered(time_text, 14, 34, timer_color)
    if hud.best_time > 0.0 and not g.best_crossed:
        // A thin track under the timer; the marker sits at the best and the
        // run fills toward it.
        let track_w = 240
        let x0 = (WIDTH - track_w) / 2
        DrawRectangle(x0, 52, track_w, 2, white(0.2))
        let progress = limit(g.elapsed / hud.best_time, 0.0, 1.0)
        DrawRectangle(x0, 52, (track_w as f64 * progress) as i32, 2, white(0.7))
        DrawRectangle(x0 + track_w - 1, 46, 2, 14, gold(0.9))
        label(f"BEST {stamp(hud.best_time)}", x0 + track_w + 8, 46, 10, gold(0.7))
    else if g.best_crossed:
        centered(f"BEST {stamp(g.launch.best_time)}", 52, 10, gold(0.6))
    neon_right(f"{commas(g.credits)}", 1254, 16, 28, gold(1.0))
    label("CREDITS", 1254 - MeasureText("CREDITS", 10), 48, 10, gold(0.6))
    // Boss bar.
    if let Some((hp, max_hp)) = g.boss_health():
        let w = 500
        let x0 = (WIDTH - w) / 2
        DrawRectangle(x0, 66, w, 8, ink(0.8))
        DrawRectangle(x0, 66, (w as f64 * limit(hp as f64 / max_hp as f64, 0.0, 1.0)) as i32, 8, red(0.95))
        DrawRectangleLines(x0, 66, w, 8, red(0.5))
    // Bottom: weapon and passive icons with level pips.
    DrawRectangle(0, HEIGHT - 52, WIDTH, 52, ink(0.75))
    var x = 30.0
    for slot in 0..SLOT_COUNT:
        let s: WeaponSlot = g.build.weapons[slot]
        let pos = V2 { x, y: HEIGHT as f64 - 30.0 }
        if slot < g.build.weapon_slots:
            DrawRectangleLines((x - 18.0) as i32, HEIGHT - 48, 36, 36, if s.level > 0: white(0.3) else: white(0.08))
        if s.level > 0:
            draw_weapon_icon(s.weapon, pos, 10.0, clock, 1.0)
            for pip in 0..MAX_WEAPON_LEVEL:
                let px = (x - 16.0 + pip as f64 * 4.5) as i32
                DrawRectangle(px, HEIGHT - 10, 3, 3, if pip < s.level: white(0.9) else: white(0.12))
        x += 46.0
    x = WIDTH as f64 - 30.0
    for slot in 0..SLOT_COUNT:
        let s: PassiveSlot = g.build.passives[slot]
        let pos = V2 { x, y: HEIGHT as f64 - 30.0 }
        DrawRectangleLines((x - 18.0) as i32, HEIGHT - 48, 36, 36, if s.level > 0: lime(0.3) else: white(0.08))
        if s.level > 0:
            draw_passive_icon(s.passive, pos, 9.0, 1.0)
            for pip in 0..MAX_PASSIVE_LEVEL:
                let px = (x - 12.0 + pip as f64 * 5.5) as i32
                DrawRectangle(px, HEIGHT - 10, 4, 3, if pip < s.level: lime(0.9) else: white(0.12))
        x -= 46.0
    // Center bottom: counts of reroll, skip, banish, reboot, and kills.
    let counts = f"KILLS {commas(g.kills)}     REROLL {g.rerolls}   SKIP {g.skips}   BANISH {g.banishes}   REBOOT {g.reboots}"
    label(counts, (WIDTH - MeasureText(counts, 10)) / 2, HEIGHT - 32, 10, white(0.5))
    if hud.show_hints and g.elapsed < 8.0:
        let hint = "MOVE  WASD / LEFT STICK     AIM  MOUSE / RIGHT STICK     AUTO-FIRE     ESC  PAUSE"
        label(hint, (WIDTH - MeasureText(hint, 10)) / 2, HEIGHT - 16, 10, white(0.4 * limit(8.0 - g.elapsed, 0.0, 1.0)))
    // Banner.
    if g.banner.life > 0.0:
        let remaining = limit(g.banner.life / g.banner.total, 0.0, 1.0)
        let alpha = limit(remaining * 3.0, 0.0, 1.0)
        match g.banner.kind:
            .Merge(w) => {
                centered("MERGE", 270, 16, white(alpha))
                centered(w.name(), 292, 48, gold(alpha))
                centered(w.describe(), 346, 14, white(alpha * 0.8))
            }
            .Boss => {
                DrawRectangle(0, 0, WIDTH, HEIGHT, red(0.08 * alpha * (0.5 + 0.5 * sin(clock * 20.0))))
                centered("WARNING", 300, 44, red(alpha))
                centered("A BOSS HAS ENTERED THE ARENA", 350, 14, white(alpha * 0.8))
            }
            .BossDown => centered("BOSS DOWN", 300, 44, gold(alpha))
            .Event(f) => {
                let name = match f:
                    .Sweep => "SWEEP"
                    .Ring => "RING"
                    .Spiral => "SPIRAL"
                    .Lattice => "LATTICE"
                centered(f"INCOMING  {name}", 90, 18, magenta(alpha))
            }
            .NewBest => centered("NEW BEST", 300, 44, gold(alpha))
            .Null => {
                DrawRectangle(0, 0, WIDTH, HEIGHT, white(0.05 * alpha))
                centered("THE NULL", 290, 52, white(alpha))
                centered("THE RUN IS CLEARED. NOTHING ORDINARY SURVIVES IT.", 350, 14, white(alpha * 0.8))
            }
            .Cleared => centered("THE NULL IS DOWN", 300, 44, white(alpha))
            .Reboot => centered("REBOOT", 300, 44, cyan(alpha))
            .Endless(c) => centered(f"LOOP {c}", 300, 44, magenta(alpha))

// The boost overlay: three or four cards over the frozen world.
fn render_boost(g: &Game, cursor: i32, clock: f64):
    DrawRectangle(0, 0, WIDTH, HEIGHT, ink(0.62))
    let title = match g.boost_source:
        .LevelUp => f"LEVEL {g.level - g.pending_levels}"
        .Cache => "CACHE"
    centered(title, 150, 30, if g.boost_source == .Cache: gold(1.0) else: lime(1.0))
    if g.cache_reveal > 0.0:
        // The ceremony: icons spin through a window and slow into the reveal.
        let speed = g.cache_reveal * g.cache_reveal * 40.0
        let index = ((clock * speed) as i32) % (BASE_WEAPON_COUNT + PASSIVE_COUNT)
        let pos = V2 { x: WIDTH as f64 / 2.0, y: 400.0 }
        panel(WIDTH / 2 - 80, 320, 160, 160, gold(1.0))
        if index < BASE_WEAPON_COUNT: draw_weapon_icon(weapon_at(index), pos, 34.0, clock, 1.0)
        else: draw_passive_icon(passive_at(index - BASE_WEAPON_COUNT), pos, 30.0, 1.0)
        centered("OPENING", 500, 14, gold(0.8))
        return
    let count = g.offer_count
    let card_w = 220
    let gap = 24
    let total = count * card_w + (count - 1) * gap
    let x0 = (WIDTH - total) / 2
    for i in 0..count:
        let o: Offer = g.offers[i]
        let x = x0 + i * (card_w + gap)
        let y = 230
        let selected = i == cursor
        let accent = if o.pick.is_merge(): gold(1.0) else if selected: white(1.0) else: cyan(0.6)
        DrawRectangle(x, y, card_w, 300, ink(if selected: 0.96 else: 0.9))
        DrawRectangleLinesEx(Rectangle { x: x as f32, y: y as f32, width: card_w as f32, height: 300.0 }, if selected: 3.0 else: 1.0, Fade(accent, if selected: 1.0 else: 0.5))
        if selected: DrawRectangleLinesEx(Rectangle { x: (x - 6) as f32, y: (y - 6) as f32, width: (card_w + 12) as f32, height: 312.0 }, 1.0, Fade(accent, 0.3 + 0.2 * sin(clock * 6.0)))
        let cx = x + card_w / 2
        if o.pick.is_merge(): centered_at("MERGE", cx, y + 14, 14, gold(1.0))
        else if o.unseen: centered_at("UNSEEN", cx, y + 14, 12, magenta(0.9))
        draw_pick_icon(o.pick, V2 { x: cx as f64, y: (y + 90) as f64 }, 30.0, clock, 1.0)
        centered_at(o.pick.title(), cx, y + 150, 24, white(1.0))
        let sub_text = match o.pick:
            .NewWeapon(_) => "NEW"
            .NewPassive(_) => "NEW"
            .UpgradeWeapon(w) => f"{roman(g.build.weapon_level(w))} > {roman(g.build.weapon_level(w) + 1)}"
            .UpgradePassive(p) => f"{roman(g.build.passive_level(p))} > {roman(g.build.passive_level(p) + 1)}"
            .Merge(w) => match recipe_for(w):
                Some(r) => match r.second:
                    Some(s) => f"{r.first.name()} + {s.name()}"
                    None => f"{r.first.name()} + {r.key.name()}"
                None => ""
        centered_at(sub_text, cx, y + 182, 16, if o.pick.is_merge(): gold(0.9) else: cyan(0.9))
        let detail = match o.pick:
            .NewWeapon(w) => w.describe()
            .UpgradeWeapon(w) => w.describe()
            .Merge(w) => w.describe()
            .NewPassive(p) => p.describe()
            .UpgradePassive(p) => p.describe()
        // Wrap the detail line at the card width.
        var line_text = ""
        var line_y = y + 214
        for word in detail.split(" "):
            let trial = if line_text.len() == 0: word.clone() else: line_text ++ " " ++ word
            if MeasureText(trial, 12) > card_w - 24 and line_text.len() > 0:
                centered_at(line_text, cx, line_y, 12, white(0.7))
                line_y += 16
                line_text = word.clone()
            else: line_text = trial
        if line_text.len() > 0: centered_at(line_text, cx, line_y, 12, white(0.7))
        centered_at(f"{i + 1}", cx, y + 276, 12, white(0.4))
    let controls = f"[A / SPACE] TAKE     [X / R] REROLL x{g.rerolls}     [Y / S] SKIP x{g.skips}     [LB / N] BANISH x{g.banishes}"
    label(controls, (WIDTH - MeasureText(controls, 12)) / 2, 580, 12, white(0.6))

// ----- debug ------------------------------------------------------------------------

pub type DebugInfo { frame_ms: f64 = 16.67, save_path: str = "", metrics: Vec[str] }

fn render_debug(g: &Game, info: &DebugInfo, cam: Camera):
    let h = 330 + info.metrics.len() as i32 * 18
    DrawRectangle(40, 96, 340, h, ink(0.94))
    DrawRectangle(40, 96, 3, h, cyan(0.85))
    label("PERFORMANCE / F1", 55, 110, 14, cyan(1.0))
    label(f"FPS             {GetFPS()}", 55, 139, 14, white(1.0))
    let tenths = (info.frame_ms * 10.0) as i32
    label(f"FRAME           {tenths / 10}.{tenths % 10} ms", 55, 160, 14, white(0.8))
    label(f"ENEMIES         {g.enemy_count}", 55, 181, 14, magenta(1.0))
    label(f"BULLETS         {g.bullet_count}", 55, 202, 14, white(0.8))
    label(f"PARTICLES       {g.particle_count}", 55, 223, 14, white(0.8))
    label(f"CORES           {g.core_count}", 55, 244, 14, cyan(0.8))
    let active = g.enemy_count + g.bullet_count + g.particle_count + g.pulse_count + g.core_count + 1
    label(f"TOTAL           {active}", 55, 265, 14, cyan(1.0))
    let minute_tenths = (g.table_minute() * 10.0) as i32
    let rate_tenths = (g.rules.spawn_rate(g.table_minute()) * 10.0) as i32
    label(f"MINUTE {minute_tenths / 10}.{minute_tenths % 10}   SPAWN {rate_tenths / 10}.{rate_tenths % 10}/s   RUN {stamp(g.elapsed)}", 55, 292, 12, white(0.55))
    label(f"CAMERA {cam.origin.x as i32},{cam.origin.y as i32}   ARENA {g.rules.arena_width as i32}x{g.rules.arena_height as i32}", 55, 310, 12, white(0.55))
    label(f"SAVE {info.save_path}", 55, 328, 10, white(0.45))
    var y = 350
    for m in info.metrics:
        label(m.clone(), 55, y, 12, lime(0.8))
        y += 18

// ----- renderer ----------------------------------------------------------------------

// Full-resolution scene plus two bloom tiers: a quarter-resolution tight
// glow and an eighth-resolution wide halo. The composite keeps sharp vector
// cores while the halos overlap into genuine neon.
pub type Renderer {
    scene: RenderTexture2D, bloom_a: RenderTexture2D, bloom_b: RenderTexture2D,
    wide_a: RenderTexture2D, wide_b: RenderTexture2D,
    grid: Effect, bright: Effect, blur: Effect, composite: Effect,
    ship_location: i32, camera_location: i32, visible_location: i32, stage_location: i32, count_location: i32, impulse_locations: Vec[i32],
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
        ship_location: grid.location("ship"), camera_location: grid.location("camera"),
        visible_location: grid.location("shipVisible"), stage_location: grid.location("stage"), count_location: grid.location("impulseCount"),
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

// The camera for this frame: the simulation's view plus presentation shake.
pub fn camera_for(g: &Game, clock: f64) -> Camera:
    let shake = g.trauma * g.trauma * 8.0
    Camera { origin: g.view_origin(), shake: V2 { x: sin(clock * 83.0) * shake, y: cos(clock * 109.0) * shake } }

extend Renderer:
    pub fn valid(self: &Self) -> bool:
        // Missing uniforms catch raylib's default-shader fallback as well as
        // actual allocation failure, so broken effects cannot pass silently.
        for target in [self.scene, self.bloom_a, self.bloom_b, self.wide_a, self.wide_b]:
            if not IsRenderTextureValid(target): return false
        let uniforms = [
            self.ship_location, self.camera_location, self.visible_location, self.stage_location, self.count_location, self.bullet_count_location,
            self.threshold_location, self.direction_location, self.bloom_location,
            self.wide_location, self.impulse_locations[0], self.bullet_locations[0],
        ]
        for location in uniforms:
            if location < 0: return false
        true

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

    // Open the scene and draw the lattice and the world. Callers draw the HUD
    // or a menu on top, then call `present`. `brightness` dims attract mode.
    pub fn begin_world(self: &Self, g: &Game, clock: f64, brightness: f64) -> Camera:
        let cam = camera_for(g, clock)
        let zoom = g.zoom()
        let center = V2 { x: WIDTH as f64 / 2.0, y: HEIGHT as f64 / 2.0 }
        // Shader inputs are where things land on screen after the zoom.
        let zoomed = (p: V2) => add(center, scale(sub(p, center), zoom))
        let ship = zoomed(to_screen(cam, g.player))
        self.grid.vector2(self.stage_location, g.rules.void_radius as f32, zoom as f32)
        self.grid.vector4(self.ship_location, ship.x as f32, ship.y as f32, clock as f32, g.trauma as f32)
        self.grid.vector4(self.camera_location, cam.origin.x as f32, cam.origin.y as f32, g.rules.arena_width as f32, g.rules.arena_height as f32)
        self.grid.scalar(self.visible_location, if g.health > 0: 1.0 else: 0.0)
        let count = if g.pulse_count < 16: g.pulse_count else: 16
        self.grid.scalar(self.count_location, count as f32)
        for i in 0..count:
            let p: Pulse = g.pulses[i]
            let pos = zoomed(to_screen(cam, p.pos))
            self.grid.vector4(self.impulse_locations[i], pos.x as f32, pos.y as f32, (1.0 - p.life / p.total) as f32, (p.radius * zoom) as f32)
        var shots = 0
        for i in 0..g.bullet_count:
            if shots >= 24: break
            let b: Bullet = g.bullets[i]
            if b.hostile or not g.on_screen(b.pos, 0.0): continue
            let pos = zoomed(to_screen(cam, b.pos))
            let heading = direction(b.vel)
            self.grid.vector4(self.bullet_locations[shots], pos.x as f32, pos.y as f32, heading.x as f32, heading.y as f32)
            shots += 1
        self.grid.scalar(self.bullet_count_location, shots as f32)
        BeginTextureMode(self.scene)
        ClearBackground(ink(1.0))
        self.grid.begin()
        DrawRectangle(0, 0, WIDTH, HEIGHT, WHITE)
        EndShaderMode()
        let view = Camera2D { offset: rv(center), target: rv(center), rotation: 0.0, zoom: zoom as f32 }
        BeginMode2D(view)
        render_world(g, cam, clock)
        EndMode2D()
        if brightness < 1.0: DrawRectangle(0, 0, WIDTH, HEIGHT, ink(1.0 - brightness))
        cam

    // The in-run layers: indicators, HUD, boost overlay, debug.
    pub fn draw_run(self: &Self, g: &Game, cam: Camera, hud: Hud, cursor: i32, clock: f64, debug: Option[&DebugInfo]):
        render_indicators(g, cam, clock)
        render_hud(g, hud, clock)
        if g.phase == .Boost: render_boost(g, cursor, clock)
        if let Some(info) = debug: render_debug(g, info, cam)

    // Bloom and composite the scene to the window. Returns CPU submit ms.
    pub fn present(self: &Self) -> f64:
        let started = GetTime()
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
    assert(stamp(1120.0) == "18:40" and roman(4) == "IV")
