# WIPE: SURVIVAL — Implementation Notes

These notes describe how the game is built in With, using the prototype in
this tree as the baseline. Every sample below is current With: no safe
`&mut`, no `println`, C libraries reached through `c_import` and modeled
through `c facade` blocks, mutation through `mut self` receivers and index
places. Where the spec adds a system the tree does not have yet,
the sample shows the shape it should take, not code that exists.

---

# 1. Core Philosophy

## Hard constraints

1. All control flow is written in With.
2. All game state and logic live in With.
3. C libraries are used only for platform capabilities.
4. No platform-specific APIs are used directly.

## Architectural statement

> With is the game. C libraries are the machine.

The simulation never sees a foreign type or calls a foreign function. It is a
pure value with a `tick`; the platform layers feed it input and read its
state.

---

# 2. Dependencies

## raylib 6.0

Window, 2D primitives, render textures and GLSL shaders, sound and music
streaming, frame timing.

## SDL3 3.4.14

Native controller transport and mapping only: Xbox controllers and the Steam
Controller over its USB puck, without Steam Input or keyboard/mouse
emulation. SDL owns no window; raylib's window focus gates gameplay input.

## Steamworks SDK (milestone M4)

Achievements, stats, overlay, Steam Deck runtime integration. Not in the tree
yet. It is reached through the SDK's flat C API, which is what `c_import` can
translate; the C++ interfaces are not a C surface.

## Nothing else

No physics library, no additional audio or rendering libraries, no direct
Win32 or POSIX calls. Both native dependencies are pinned in `with.toml` and
fetched with `with get`.

---

# 3. FFI Model

Both libraries are imported directly:

```with
use c_import("raylib.h")
use c_import("SDL3/SDL.h")
```

A function imported through `c_import` is callable as a With function, and a
`str` argument is passed where the header takes `const char *`:

```with
InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | built with With")
```

Raw pointers stay explicit. A call that takes or returns a pointer needs
`unsafe`, and the game never writes that: each library's ownership surface is
modeled once in a `c facade`, and the program uses the presented methods. The
facade is the evidence the compiler needs; it never infers ownership from a
name.

## Design goal

> C functions feel like native With functions, and the unsafe surface is
> written exactly once, in the facade.

---

# 4. Responsibility Split

| Layer | Owns |
|---|---|
| raylib | window lifecycle, drawing, shaders, audio playback, frame timing |
| SDL3 | controller enumeration, mapping, axis and button state |
| Steamworks | achievements, stats, overlay, Deck runtime |
| With | game loop, world state, every gameplay system, spawning and difficulty, upgrades, presentation orchestration |

The split in the tree:

```text
src/game.w          pure simulation: no window, audio, or foreign calls
src/tuning.w        gameplay knobs as one Rules value
src/input.w         keyboard, mouse, and pad frames become one Controls value
src/gamepads.w      SDL controller lifecycle, discovery, polling
src/sdl.w           the SDL facade: Pad resource, borrowed error text
src/audio.w         the raylib sound facade: Clip and Track resources
src/shaders.w       the raylib shader facade: Program resource, uniforms
src/presentation.w  render passes, bloom, HUD, death overlay
src/main.w          the loop
```

---

# 5. Game Loop

The loop is With. Fixed-step simulation at 120 Hz, rendering at the display
rate, input sampled once per frame before the fixed steps:

```with
use c_import("raylib.h")
use game
use presentation
use input
use gamepads
use audio

fn main:
    SetConfigFlags(FLAG_MSAA_4X_HINT)
    InitWindow(WIDTH, HEIGHT, "WIPE: SURVIVAL | built with With")
    if not IsWindowReady():
        eprint("WIPE could not create a graphics context.")
        return 1
    defer: CloseWindow()
    var pads = match Gamepads.open():
        Ok(controllers) => controllers
        Err(message) => { eprint(f"WIPE could not initialize controllers: {message}"); return 1 }
    SetTargetFPS(60)
    InitAudioDevice()
    defer: CloseAudioDevice()
    let sound = if IsAudioDeviceReady(): Some(Audio.open()) else: None
    let renderer = Renderer.open()
    var game = Game.new()
    var input = Input {}
    var session = Session {}
    var accumulator = 0.0
    while not WindowShouldClose():
        let pad = pads.poll()
        if game.health <= 0 and IsWindowFocused() and (IsKeyPressed(KEY_SPACE) or pad.retry):
            game.reset()
            accumulator = 0.0
        let controls = input.sample(game.player, game.aim, pad)
        game.clear_events()
        // Bound catch-up after a stall; input is sampled before fixed steps.
        accumulator += limit(GetFrameTime() as f64, 0.0, 0.1)
        while accumulator >= 1.0 / 120.0:
            game.tick(controls, 1.0 / 120.0)
            accumulator -= 1.0 / 120.0
        session.observe(game)
        if let Some(bank) = &sound: bank.play(game, GetTime())
        let _ = renderer.draw(game, GetTime(), false, 16.67, session)
    0
```

Notes on the shape:

- `game` is a `var` and its methods take `mut self: Self`. Nothing passes a
  reference to the world around; callers hand the place to the method.
- `defer` releases the window and audio device on every exit path.
- The renderer and the audio bank are owned values with `Drop` impls; their
  raylib resources release when `main` returns.
- Restart is `game.reset()`: it resets counters and pool lengths only. Pools
  allocate once at creation and are never reallocated.

---

# 6. Input

Input becomes a With value immediately, and the arbitration between
keyboard, mouse, and pad is a pure function that the acceptance tests call
directly:

```with
pub type Controls { motion: V2 = V2 {}, aim: V2 = V2 { x: 1.0, y: 0.0 } }
pub type PadFrame {
    id: u32 = 0, motion: V2 = V2 {}, aim: V2 = V2 {},
    south: bool = false, retry: bool = false,
} with Copy

// Radial deadzone preserves analog magnitude without diagonal acceleration.
pub fn stick(x: f64, y: f64, deadzone: f64 = 0.2) -> V2:
    let v = V2 { x, y }
    let magnitude = sqrt(length2(v))
    if magnitude <= deadzone: V2 {} else: scale(direction(v), limit((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0))

pub type Input { pad_aim: bool = false, last_mouse: V2 = V2 {}, deadzone: f64 = 0.2 }
extend Input:
    pub fn sample(mut self: Self, player: V2, previous_aim: V2, pad: PadFrame) -> Controls:
        if not IsWindowFocused(): return Controls { aim: previous_aim }
        var motion = V2 {}
        if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP): motion.y -= 1.0
        if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN): motion.y += 1.0
        if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT): motion.x -= 1.0
        if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT): motion.x += 1.0
        let raw_mouse = GetMousePosition()
        self.resolve(motion, V2 { x: raw_mouse.x as f64, y: raw_mouse.y as f64 }, player, previous_aim, pad)
```

The controller side is an SDL facade. The resource owns one opened gamepad
and closes it on drop; the borrowed name and error text are views whose
origin the facade names:

```with
c facade controllers:
    resource Pad wraps *mut SDL_Gamepad
        from SDL_OpenGamepad
        drop SDL_CloseGamepad
    fn SDL_GamepadConnected
        of Pad
        rename connected
        lend
    fn SDL_GetGamepadAxis
        of Pad
        rename axis
        lend
    fn SDL_GetGamepadName
        of Pad
        rename name
        returns borrow CStr from param 0
    domain errors thread
    fn SDL_GetError
        returns borrow CStr from domain errors
```

## Rule

> Input is a With value by the end of `sample`. Nothing downstream knows
> which device produced it.

---

# 7. Gameplay Systems

The simulation is one value. Pools are `Vec`s allocated to capacity once;
active lengths are counters; removal is a swap with the last active slot.

```with
pub type Game {
    rules: Rules = Rules {},
    player: V2 = V2 { x: 640.0, y: 400.0 },
    aim: V2 = V2 { x: 1.0, y: 0.0 },
    health: i32 = 3, kills: i32 = 0, score: i32 = 0, elapsed: f64 = 0.0,
    enemy_count: i32 = 0, bullet_count: i32 = 0, particle_count: i32 = 0,
    enemies: Vec[Enemy],
    bullets: Vec[Bullet],
    particles: Vec[Particle],
    rng: u32 = 1234567,
}
```

## Player

Movement and aim are read from `Controls`; the player is a field of the
world, mutated through the world's own receiver:

```with
extend Game:
    pub fn tick(mut self: Self, input: Controls, dt: f64):
        if length2(input.aim) > 0.01: self.aim = direction(input.aim)
        self.player = add(self.player, scale(movement(input.motion), self.rules.player_speed * dt))
        self.player.x = limit(self.player.x, ARENA_LEFT as f64 + 12.0, ARENA_RIGHT as f64 - 12.0)
        self.fire_timer -= dt
        if self.fire_timer <= 0.0:
            self.fire_timer += self.rules.fire_interval
            self.fire()
```

## Enemies

Element access observes; a loop that mutates an element does so through the
index place, or copies the element out, changes it, and stores it back.
Neither takes a reference into the pool:

```with
        for e in 0..self.enemy_count:
            var enemy: Enemy = self.enemies[e]
            enemy.age += dt
            let chase = scale(direction(sub(self.player, enemy.pos)), enemy.speed)
            enemy.pos = add(enemy.pos, scale(chase, dt))
            self.enemies[e] = enemy
```

For a field update alone, the index place is enough:

```with
        self.enemies[e].hp -= 1
        self.enemies[e].flash = 0.05
```

Enemy kinds are an enum with methods, never an integer code:

```with
pub enum Kind { | Block | Spinner | Dart | Weaver }
impl Copy for Kind
extend Kind:
    pub fn tint(self: &Self) -> Tint:
        match self:
            .Block => .Lime
            .Spinner => .Magenta
            .Dart => .Blue
            .Weaver => .Cyan
```

## Collision

No physics engine. Bullets test a swept segment against each enemy; enemies
test contact against the player; separation uses a coarse uniform grid that
is rebuilt each tick in preallocated storage:

```with
pub fn segment_hit(a: V2, b: V2, p: V2, radius: f64) -> bool:
    let ab = sub(b, a)
    let ap = sub(p, a)
    let size = length2(ab)
    let t = if size > 0.0001: limit((ap.x * ab.x + ap.y * ab.y) / size, 0.0, 1.0) else: 0.0
    length2(sub(p, add(a, scale(ab, t)))) <= radius * radius
```

## Events

The simulation records what happened this tick as booleans (`shot_event`,
`kill_event`, `hurt_event`, `death_event`); the audio layer reads them after
the fixed steps and the loop clears them before the next frame. Presentation
never reaches into the simulation's RNG.

## Timeline, gems, level-ups, combo (milestone M1)

These are simulation state and belong in `Game`, with their knobs and data
tables in `Rules`. The pattern is the one the prototype already uses for the
kill multiplier: a scalar that builds on events and decays with `dt`, read
by presentation, never written by it. A level-up choice is a paused state of
the same value, not a second loop:

```with
pub enum Phase { | Running | Choosing | Over }
impl Copy for Phase

pub type Game {
    phase: Phase = .Running,
    minute: f64 = 0.0,
    combo: i32 = 0, combo_timer: f64 = 0.0,
    xp: i32 = 0, level: i32 = 1,
    weapons: [WeaponSlot; 6], passives: [PassiveSlot; 6],
    offered: [Offer; 4] = [Offer {}; 4],
    gems: Vec[Gem], gem_count: i32 = 0,
    ...
}
```

---

# 8. Rendering

Rendering decisions are With logic; drawing is delegated to raylib. The
renderer owns its render textures and shader programs as resources:

```with
c facade gpu:
    resource Program wraps Shader
        from LoadShader
        drop UnloadShader
    fn LoadShader
        of Program
        rename load
        param vsFileName fixed null

pub type Effect { program: Program }
extend Effect:
    pub fn location(self: &Self, name: &str) -> i32:
        GetShaderLocation(self.program.repr, name)
    pub fn begin(self: &Self) -> Unit: BeginShaderMode(self.program.repr)
```

Passing a uniform is the one raw boundary, written once:

```with
    pub fn vector4(self: &Self, location: i32, x: f32, y: f32, z: f32, w: f32) -> Unit:
        let data: [f32; 4] = [x, y, z, w]
        unsafe { SetShaderValue(self.program.repr, location, &raw const data[0], SHADER_UNIFORM_VEC4) }
```

The draw function reads the world by reference and never mutates it:

```with
fn render_world(g: &Game, offset: V2, clock: f64) -> Unit:
    for i in 0..g.enemy_count:
        let e: Enemy = g.enemies[i]
        let pos = add(e.pos, offset)
        draw_enemy(e.kind, pos, 15.0, clock, e.speed, direction(sub(g.player, e.pos)), paint(e.kind.tint(), 1.0), 0.85)
```

Game state holds `V2`, a With type. raylib's `Vector2` appears only at the
call that draws:

```with
fn rv(p: V2) -> Vector2: Vector2 { x: p.x as f32, y: p.y as f32 }
```

---

# 9. Audio

Every clip and stream is a resource; the facade names the loader and the
unloader once:

```with
c facade sounds:
    resource Track wraps Music
        from LoadMusicStream
        drop UnloadMusicStream
    resource Clip wraps Sound
        from LoadSound
        drop UnloadSound
    fn LoadSound
        of Clip
        rename load

pub type Audio {
    shot: Clip, hit: Clip, kill: Clip, hurt: Clip, death: Clip,
    music: Track,
}
```

Playback is event-driven from the simulation's flags. Pitch variation comes
from the presentation clock, never from the simulation's RNG, so the
simulation stays deterministic:

```with
    pub fn play(self: &Self, g: &Game, clock: f64) -> Unit:
        UpdateMusicStream(self.music.repr)
        if g.shot_event:
            SetSoundPitch(self.shot.repr, (0.96 + (sin(clock * 73.0) + 1.0) * 0.04) as f32)
            PlaySound(self.shot.repr)
        if g.death_event: PlaySound(self.death.repr)
```

Music runs through death and retry: `reset` touches the simulation only, so
the stream never restarts.

---

# 10. Steam Integration (milestone M4)

Steamworks is reached through its flat C API. Its state is process-wide
and has no owner on the With side, so it is a foreign-state domain; the
stats interface is a record view borrowed from that domain, and
initialization and shutdown are the operations that invalidate it:

```with
use c_import("steam/steam_api_flat.h", link: "steam_api")

c facade steam:
    domain runtime process
    fn SteamAPI_Init
        invalidates domain runtime
    fn SteamAPI_Shutdown
        invalidates domain runtime
    fn SteamAPI_RunCallbacks
        preserves domain runtime
    fn SteamAPI_SteamUserStats
        returns borrow ISteamUserStats from domain runtime
    fn SteamAPI_ISteamUserStats_SetAchievement
        of ISteamUserStats
        rename set_achievement
        lend
    fn SteamAPI_ISteamUserStats_StoreStats
        of ISteamUserStats
        rename store
        lend
```

Then achievements are one call at the event that earns them. The view is
taken where it is used, inside the run, so no borrow outlives a shutdown:

```with
fn unlock(name: &str):
    let stats = SteamAPI_SteamUserStats()
    stats.set_achievement(name)
    stats.store()

if game.kill_event and game.kills == 100: unlock("KILL_100")
```

`SteamAPI_RunCallbacks` is one line at the top of the loop, after the pad
poll. If Steam is not running, the game runs without it and says so once:

```with
    if not SteamAPI_Init(): eprint("Steam not running; achievements disabled")
```

The exact facade clauses depend on the SDK header the project pins; the
shape above is the target, and the facade must compile against the real
header before any achievement code is written, per the modeled-C ordering
rule.

---

# 11. What This Demonstrates About With

- **FFI without wrappers.** Every raylib and SDL function is called directly;
  the only wrapping is the facade, which is evidence, not glue.
- **One unsafe surface.** The uniform upload is the game's single `unsafe`
  block, and it is inside the shader facade.
- **Real-time control with no runtime.** The loop is a `while`; there is no
  framework, scheduler, or garbage collector between frames.
- **Data-oriented mutation without `&mut`.** Pools are `Vec`s of `Copy`
  values, mutated through index places and `mut self` receivers; the borrow
  rules cost nothing at runtime and no lifetime is ever written.
- **A pure simulation.** `Game` has no foreign calls, so the acceptance tests
  run it headless at 120 Hz and compare two instances for determinism.

---

# 12. Failure Signals

- **A foreign type in game state.** `Vector2`, `Sound`, or `SDL_Gamepad` in
  `Game` means the boundary leaked. The world holds `V2` and handles.
- **A reference stored in a struct.** With refuses it; the fix is a handle,
  an index, or an owned value, never `unsafe`.
- **An `unsafe` block outside a facade file.** The facade exists so that
  gameplay never writes one.
- **Logic that wants to move into C.** A critical failure for the language,
  not a workaround to take.
- **A second copy of a fact.** Tuning lives in `Rules`; a magic number in
  presentation that must match the simulation is a bug waiting to happen.

---

# 13. Summary

- raylib and SDL3 provide graphics, audio, and controllers; Steamworks
  provides platform integration in milestone M4.
- With owns the loop, the world, every system, and the presentation.
- The simulation is a pure, deterministic value; the platform layers are
  facades around owned resources.
- The prototype in this tree is the baseline: M1 adds the timeline, gems,
  level-ups, and weapons as simulation state; M2 adds the shop and unlocks;
  M3 adds enemy behaviors and evolutions; M4 adds Steam.
