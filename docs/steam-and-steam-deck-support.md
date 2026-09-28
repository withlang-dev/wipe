# Steam and Steam Deck Support

What it takes to ship WIPE: SURVIVAL on Steam and to earn Steam Deck
Verified, without making the game depend on either. This is the working
inventory for milestone M4 (spec §16). Spec §3 (controls and platform), §12
(performance), and §15 (Steam) remain the requirements. This document says
what is missing and how to add it.

Status as of 2026-09-27: nothing here is implemented. The tree runs on macOS
through raylib 6.0 and SDL3 and has no Linux build, options screen,
resolution handling, or Steamworks code.

---

## 1. Ground rules

**Steam is an addition, never a requirement.**

- At runtime, a missing Steam client does not stop the game. The game
  runs, says once that achievements will sync next time (spec §15), and
  goes on. Nothing quits because Steam is absent. The Steam build ships
  `libsteam_api` beside the executable and links it (§6.4).
- At build time, the default `with build` produces a game with no Steamworks
  code and no `libsteam_api` dependency. The Steam build is a separate
  target. A DRM-free build for itch.io, GOG, or a zip is the plain target
  with no changes.
- Every Steam feature has a platform-neutral owner in the game.
  Achievements are computed from the save and shown in the Collection.
  Settings live in WIPE's own options screen. Controllers go through SDL.
  Saves are plain files that Steam Cloud copies without the game knowing.
  Steam mirrors state the game already has. It never owns that state.
- Steam Deck is a set of defaults, not a mode. Detecting a Deck may choose
  fullscreen on first launch. It never hides an option or changes a rule.
- No Steam DRM wrapper. It adds nothing a DRM-free game wants.

**With only.** No C or C++ source, no shim library, no wrapper `.so`
compiled from C++. Steamworks is reached through its C-linkage flat API,
imported from `steam_api_flat.h` with `c_import` (§6). The two C files under `native/glfw/` are leftovers
from the GLFW Steam Controller experiment. The build does not reference
them, so delete them.

---

## 2. What already fits

| Fact | Where | Why it helps |
|---|---|---|
| The logical canvas is 1280×800 | `src/game.w:21-22` | This is the Deck's native panel. Handheld play is 1:1 with no scaling. |
| Rendering is OpenGL 3.3 core through raylib, all into one offscreen scene | `src/presentation.w:1377`, `:1487-1517` | Letterboxing and scaling only change the final blit. |
| The simulation runs fixed 120 Hz steps, and the frame delta is clamped to 0.1 s in a run | `src/app.w:391` | Frame rate, VSync, and suspend/resume do not change gameplay. |
| Controllers go through SDL3 | `src/gamepads.w` | Steam Input presents an Xbox-style virtual pad that SDL reads unchanged. |
| Losing focus pauses a run | `src/app.w:297-302` | Steam overlay pause reuses this path. |
| On Linux the save already lives in `$XDG_DATA_HOME/wipe` or `~/.local/share/wipe`, written atomically | `src/save.w:184-195` | This is the right place for Steam Cloud, with no code. |
| Every unlock is a `Condition` evaluated against the save, with progress | `src/account.w:148-206` | Achievements are a table over existing facts. |
| Bosses already have first-kill achievements in game | `src/save.w:36`, `src/game.w:1028` | These become the first three Steam achievements. |
| No text entry anywhere | — | No on-screen keyboard work. |

---

## 3. Options screen and settings file

There is no options screen. Volume and deadzone are two rows in the pause
menu (`src/app.w:448-493`, `:801-813`), and they are stored in `save.txt`
beside progress (`src/save.w:40-41`). The title screen is hotkeys only (A
launch, X shop, Y collection, hold B quit), so there is nowhere to put
display settings.

**Build:**

- A new `.Options` screen reachable from the title and from pause.
  - **On the title** it is a fourth entry beside launch, shop, and
    collection: the pad's Menu button (☰, Start on an Xbox pad), O on the
    keyboard, or a click on its label. Start does nothing on the title
    today. Escape still quits, so the pad button and the key must be read
    separately; `MenuInput.start` merges them (`src/input.w:88`).
  - **In pause**, an `OPTIONS` row replaces the inline volume and deadzone
    rows.
  - Inside Options, every row is navigable with the d-pad and stick,
    adjusted with left and right, and closed with B or Escape, like every
    other screen.
- This changes the spec in two places. The §11 title mockup gains
  `[☰] options`. The pause section's "This is the only place volume and
  deadzone live" becomes: volume and deadzone live in Options, reachable
  from the title and from pause.
- Rows, first pass:
  - **Display:** display mode (Windowed / Fullscreen), window size (only
    when windowed), VSync on/off, frame cap (60 / display refresh /
    unlimited).
  - **Audio:** master volume. Music and effects volumes are optional.
    `src/audio.w` already sets per-sound volumes.
  - **Controls:** stick deadzone, and button prompts (Automatic / Controller
    / Keyboard). Automatic is the default (§5).
  - **Optional accessibility:** screen shake and flash intensity. Trauma
    shake and full-screen flashes are both presentation-only.
- **A separate `settings.txt`** beside the save, in the same `key value`
  format with the same atomic write and backup. Settings are per machine
  and progress is per player: a Deck and a desktop sharing a Steam Cloud
  save must not trade window sizes. On first run, when `settings.txt` is
  missing, copy `volume` and `deadzone` from the save. The save keeps
  reading those keys and stops writing them. Unknown keys are already
  ignored, so `SAVE_VERSION` stays 1.
- **Read settings before `InitWindow`.** Window flags and size have to be
  known before the window exists. Today `App.open()` reads the save after
  the window is created (`src/main.w:12-34`). Settings load moves to the
  top of `main`. The save can stay where it is.
- The harnesses (`uat`, `tour`, `gallery`, `play`, `bosses`) never read
  `settings.txt`. They keep a fixed 1280×800 window so their PNGs and
  timings stay comparable.

**Done when:** every row round-trips through `settings.txt`
(`test/settings_contracts.w`), the tour has an Options PNG, and the screen
works with the pad alone.

---

## 4. Resolution and display

### 4.1 The canvas stays 1280×800

`WIDTH` and `HEIGHT` are simulation constants. The camera bounds
(`src/game.w:684-705`), culling (`on_screen`), and the view-edge spawn
positions (`src/game.w:715-725`, `:876-923`) all use them. Showing more
world on a wider screen would change where enemies appear and how early the
player sees them. That changes balance per display and breaks exact replay
of recordings. So the logical canvas stays 1280×800 (16:10) on every
display, and output resolution is only a presentation concern.

### 4.2 Step 1: letterbox and map the mouse (required)

- Composite the 1280×800 scene into the largest 16:10 rectangle that fits
  the framebuffer, centered, with `ink` bars. `blit` in `present()`
  (`src/presentation.w:1509`) already takes a destination size. It needs an
  offset and a size from one pure function,
  `letterbox(framebuffer_w, framebuffer_h) -> Rect`, which is unit tested.

  | Output | Image | Bars |
  |---|---|---|
  | 1280×800 (Deck handheld) | 1280×800 | none |
  | 1280×720 (Deck 16:9 setting) | 1152×720 | 64 px left and right |
  | 1920×1080 (docked TV) | 1728×1080 | 96 px left and right |
  | 1920×1200 | 1920×1200 | none |
  | 3840×2160 | 3456×2160 | 192 px left and right |

- `SetMouseScale` and `SetMouseOffset` convert window coordinates to canvas
  coordinates once, globally. Then the 13 `inside(m.mouse, …)` hit tests in
  `src/app.w` and mouse aiming work unchanged. Deck touchscreen taps arrive
  as mouse events and get the same mapping.
- Make the window resizable (`FLAG_WINDOW_RESIZABLE`) and recompute the
  letterbox when `IsWindowResized()` reports a change.
- Fullscreen means **borderless fullscreen at the monitor's current mode**
  (`FLAG_BORDERLESS_WINDOWED_MODE` / `ToggleBorderlessWindowed`). Do not
  switch the display mode with `ToggleFullscreen`. Mode switches are slow
  and fragile on desktops, and on the Deck gamescope owns the output
  anyway.
- Window sizes offered when windowed: 1280×800, 1280×720, 1440×900,
  1600×1000, 1920×1080, 1920×1200, 2560×1440, 2560×1600, 3840×2160.
  Filter to what fits the current monitor (`GetMonitorWidth/Height`).
- First-launch default: fullscreen when Steam reports Steam hardware, or
  when running under gamescope. The Steam build asks
  `ISteamUtils::GetSteamHardwareDefaultConfig()`, which is new in SDK 1.65.
  Valve's header describes it as the call for choosing default settings,
  and it can be retuned per device from the partner site without a new
  build. The plain build reads the environment instead:
  `XDG_CURRENT_DESKTOP=gamescope`, or `SteamDeck=1`, both set by SteamOS.
  Otherwise the default is a 1280×800 window. The player can change
  either.
- SDK 1.65 removed `IsRunningOnSteamDeck()`. `IsRunningOnSteamHardware()`
  exists, but Valve limits it to analytics and support, not functional
  decisions, so nothing in WIPE branches on "is this a Deck".

On the Deck, gamescope shows any window fullscreen. By default the game
sees a 1280×800 output. If the player sets Steam's per-game **Game
Resolution** (for example Native while docked to a 4K TV), gamescope
reports that size and the game must fill it. Step 1 is exactly what makes
that correct.

### 4.3 Step 2: render at output resolution (sharpness above 800p)

Step 1 upscales a 1280×800 image, which is soft at 1080p and blurry at 4K
or on a Retina Mac. Step 2 renders the scene at the letterboxed size
instead:

- Allocate `scene` at the letterbox size and recreate it on resize. Draw
  the world and HUD under one scale transform (`Camera2D.zoom` or
  `rlScalef`), so every call site keeps canvas coordinates.
- **`assets/shaders/grid.fs:41` hard-codes the surface height**
  (`800.0 - gl_FragCoord.y`). Replace it with a uniform, and scale the
  screen-space uniforms (ship, impulses, bullets) by the render scale.
- `DrawRectangleLines`, `DrawCircleLines`, and `DrawCircleLinesV` draw
  1-pixel GL lines that do not scale (14 call sites). Move them to the
  `…Ex` or thickness variants the rest of the renderer already uses.
- raylib's default font is a 10 px bitmap and gets blocky when scaled.
  Load a TTF with `LoadFontEx` at the render scale, or accept the look.
  This is an art decision.
- Bloom surfaces stay at 320×200 and 160×100. The glow looks the same at
  every output size.
- Set `FLAG_WINDOW_HIGHDPI` so macOS Retina windows get a full-density
  framebuffer. Use `GetRenderWidth` for surfaces and `GetScreenWidth` for
  mouse mapping.

In fullscreen, the options screen's "Resolution" row then means render
resolution (Native, 1920×1080, 1280×800, and so on). It is a performance
lever on a 4K TV and needs no display mode switch.

### 4.4 Frame pacing

`SetTargetFPS(60)` (`src/main.w:22`) is a sleep-based limiter without
VSync. The Deck LCD runs at 60 Hz and the Deck OLED at up to 90 Hz. Both
are fixed-refresh panels, not VRR, and Steam's own frame limiter can cap
further. Add a VSync option (`FLAG_VSYNC_HINT`, on by default) and a frame
cap option. The simulation is fixed-step, so any rate is safe.

Clamp the frame delta once in `main` rather than only in runs. The attract
simulation ticks with the raw delta (`src/app.w:336`), so the first frame
after the Deck resumes from sleep can be minutes long.

**Done when:** at 1280×800, 1280×720, 1920×1080, 2560×1600 HiDPI, and
3840×2160, the image is undistorted, every click lands on its target, and
the tour produces PNGs at each size. Deck handheld is pixel-exact.

---

## 5. Controls on the Deck

**How it works under Steam.** Steam Input owns the Deck's controls and
presents a virtual Xbox-style gamepad. SDL (2.0.8 and later, including
SDL3) honors Steam's instruction to hide the raw device, so the game sees
exactly one pad. WIPE's SDL path needs no Steam Input API to pass Verified.
In Steamworks, set the default controller configuration to the **Gamepad**
template, or publish a custom one: sticks as sticks, right trackpad as
mouse for menus. Opt in the Steam Deck and the Steam Controller.

**Changes in `src/gamepads.w`:**

- `SDL_JOYSTICK_HIDAPI_STEAM=1` (`:46`) and the lizard-mode report
  (`:136-150`) exist for bare Steam Controller use without Steam. Under
  Steam, Steam already manages lizard mode, and grabbing the physical
  device fights Steam Input. The Steam Virtual Gamepad also reports Valve's
  vendor ID, so `self.valve` (`:85`) is true for it today. Skip both when
  running under Steam (`SteamAppId` or `SteamGameId` set in the
  environment, or when Steamworks initialized).
- Keep everything else. SDL's own Steam Deck HIDAPI driver still covers
  running outside Steam, for example from Desktop Mode or another store.

**Button prompts (a Verified requirement).** Valve's criteria: on-screen
glyphs must match the input in use, and keyboard or mouse glyphs must not
show when they are not the active input. Today prompts mix devices:
`[A / SPACE] LAUNCH` (`src/app.w:666`), `ESC / Q QUIT HOLD B ON A
CONTROLLER` (`:674`), `[B / START] RESUME [ESC / Q] TITLE` (`:813`), and
the equivalents in `src/presentation.w`.

- Track the last-used device, keyboard/mouse or pad. `Input.pad_aim`
  already does this for aiming. Render only that device's prompt, through
  one `prompt(action)` helper instead of literal strings.
- Xbox letters (A, B, X, Y, LB, RB) match the Deck's physical labels. Start
  is the Deck's ☰ Menu button. Say MENU, or draw the glyph, instead of
  START when the pad is a Deck or a Steam Virtual Gamepad.
- Optional: PlayStation and Switch labels through SDL3's
  `SDL_GetGamepadButtonLabel`. Also optional, as a later step: `ISteamInput`
  glyph lookup, which stays correct when a player remaps buttons in Steam.

**Other items:**

- Hide the OS cursor while the pad is active (`HideCursor`) and show it on
  mouse movement (`ShowCursor`). Nothing hides it today.
- The Steam button, and the overlay in general, must pause a run (§7.3).
  Under gamescope, opening the overlay does not necessarily take focus from
  the window, so the focus-loss pause alone is not enough.
- Quitting from the Steam menu ends the process. The save is written
  atomically on every change, so nothing is lost.

---

## 6. Steamworks from With

### 6.1 The ABI is C; the headers are not

`libsteam_api` exports a **flat API** with C linkage and the C calling
convention: `SteamAPI_InitFlat`, `SteamAPI_SteamUserStats_v013()`,
`SteamAPI_ISteamUserStats_SetAchievement(ISteamUserStats* self, const char*
name)`, and so on. Interfaces are opaque pointers passed as `self`. That
surface is exactly what With's FFI calls.

The headers that declare it are C++:

- `steam_api_flat.h` declares the flat functions, but its first lines
  `#include "steam/steam_api.h"` and the game-server headers.
- `steam_api.h` pulls in `steam_api_common.h`: `class CCallbackBase` with
  virtual methods, `template<class T, class P> class CCallResult`,
  `template<…> class CCallback`, and the `ISteam*` interface classes.

A C parser stops at the first `class` before it reaches any flat
declaration. The functions are callable. The header is the problem.

**What With's `c_import` does today** (paths in the compiler repo):

- `c_import` runs libclang in C mode, always: `-x c` is hard-coded at
  every parse site (`src/compiler/ClangBridge.w:1989`). There is no
  language option; the accepted options are `link`, `only`, `no_methods`,
  `strict`, `allow_untranslated`, and the ownership options
  (`src/Parser.w:2594-2813`).
- Any clang error fails the whole import. `use
  c_import("steam/steam_api.h")` and `use
  c_import("steam/steam_api_flat.h")` both fail at the first C++
  construct, and `only:` cannot help because filtering happens after
  parsing.
- `c facade` presents only declarations that came through `c_import`
  (`src/SemaFacade.w:3696`). Hand-declared functions get no facade
  rendering, so Steam's safe surface is ordinary With written by hand.

So `c_import` of the Steam headers is not possible with today's compiler.
The decision (§14) is to make it possible, minimally, and link the
library:

```with
use c_import("steam/steam_api_flat.h", lang: "c++", link: "steam_api")
```

- **The compiler work** is planned in
  `/Users/eric/with/docs/plans/c++_import.md`:
  - a `lang: "c++"` option that imports only the `extern "C"` surface;
  - a layout check that makes C++ classes opaque;
  - callback IDs named by their struct (`UserStatsStored_t_k_iCallback`);
  - an rpath setting, which the Linux build needs (§6.4).

  It was checked against SDK 1.65: the header parses as C++ with no
  errors. The 34 flat functions that take C++ references are skipped, and
  WIPE uses none of them.
- **Only `src/steam.w` imports the header,** and only the `wipe-steam`
  target builds `src/steam.w`.
- **Nothing derived from the headers is committed.** They stay local to
  each build machine (§10), and `c_import` reads them at build time.
- **Rejected:**
  - Declarations generated from `steam_api.json` and loaded with `dlopen`
    (the earlier plan). It works with today's compiler, but it needs a
    generator and a table of function pointers, and it gives up facades.
  - Inline C declarations in a `c_import` string. That is C source in a
    With file.

### 6.2 Callbacks: manual dispatch, no C++ objects

The C++ callback system (`CCallback`, `STEAM_CALLBACK`,
`SteamAPI_RunCallbacks`) delivers events by calling virtual methods on C++
objects. With has none to register. Valve's answer for other languages is
**manual dispatch**, and this is what WIPE uses:

```text
SteamAPI_InitFlat(&err)                         once, before InitWindow
SteamAPI_ManualDispatch_Init()                  once
pipe = SteamAPI_GetHSteamPipe()
every frame:
    SteamAPI_ManualDispatch_RunFrame(pipe)
    while SteamAPI_ManualDispatch_GetNextCallback(pipe, &msg):
        match msg.m_iCallback: overlay, stats stored, shutdown, …
        SteamAPI_ManualDispatch_FreeLastCallback(pipe)
SteamAPI_Shutdown()                             at exit
```

Callback payloads are plain structs identified by `k_iCallback`.
`GameOverlayActivated_t` and `UserStatsStored_t` are the ones WIPE needs
first. On Linux and macOS the SDK packs callback structs to 4 bytes
(`VALVE_CALLBACK_PACK_SMALL`); on Windows it packs them to 8. `c_import`
reads the header on each platform and honors `#pragma pack`, so every
target gets its own layout.

### 6.3 Initialization

- Call `SteamAPI_InitFlat` before `InitWindow`, so the overlay can hook the
  GL context it creates. Current SDKs define `SteamAPI_Init()` as an inline
  C++ wrapper. `SteamAPI_InitFlat` is the flat entry point.
- Handle the result instead of exiting. `k_ESteamAPIInitResult_OK` means
  Steam is available. Any other result (no client, version mismatch, generic
  failure) means the game continues without it and shows the §1 notice once.
- In the Steam build only, call `SteamAPI_RestartAppIfNecessary(app_id)`
  first. When it returns true, Steam is relaunching the game, so exit. It
  returns false while a `steam_appid.txt` sits beside the executable, which
  is the development setup. Never ship `steam_appid.txt` in a depot.
- Interface accessors carry a version suffix (`_v013`). The import and the
  shipped library come from the same SDK, so they always agree. The Steam
  client keeps adapters for every released interface version, so the
  pinned SDK keeps working with newer clients. Check each accessor's
  result for null.

### 6.4 Linking the library

- **Linking:** `wipe-steam` links `libsteam_api` through the import's
  `link: "steam_api"`. The library search path is the platform's directory
  under `vendor/steamworks/redistributable_bin/`, and `build.w` picks it,
  because `with.toml` has no per-platform library path. The build copies
  the same file into `out/bin/`, beside the executable. The plain `wipe`
  target never imports the header, so it never links the library.
- **Finding it at runtime:**
  - **Windows** searches the executable's directory.
  - **macOS:** the library's install name is
    `@loader_path/libsteam_api.dylib`.
  - **Linux** needs an `$ORIGIN` rpath in the executable. With's linker
    cannot write one today (no `rpath`, `$ORIGIN`, or `@executable_path`
    anywhere in the compiler). Section 5 of the compiler plan adds it.
- **Consequence:** the Steam build needs its library, and every Steam
  depot ships it. A missing Steam *client* is still handled at runtime
  (§6.3). The plain build has no dependency at all.

### 6.5 One seam: a `Platform` value

The game never calls Steam directly. `main` hands the app a platform
value, and the app calls it:

```with
trait Platform:
    fn frame(mut self: Self) -> PlatformEvents     // overlay opened/closed, shutdown requested
    fn sync_achievements(mut self: Self, earned: &Vec[str])
    fn default_config(self: &Self) -> HardwareDefault   // from GetSteamHardwareDefaultConfig, or the environment
    fn notice(self: &Self) -> Option[str]          // "Steam isn't running: achievements will sync next time."
```

- `src/platform.w`: the trait and `NoPlatform`, which does nothing. The
  plain `wipe` target uses it.
- `src/steam.w`: the flat declarations and `SteamPlatform`. It is only an
  input of the `wipe-steam` target.
- `src/main.w` and `src/main_steam.w` differ in one line: which platform
  they construct. Everything else moves into a shared `run(platform)`.

Two targets and two entry files keep Steam out of the plain build. With
has no top-level switch that could do it instead: `@[target]` selects by
architecture only, and `with.toml [features]` is not visible to source.
Separate entry files are the mechanism `std.build` supports. The harnesses
and tests use `NoPlatform`.

---

## 7. Steam features

### 7.1 Achievements

Spec §15: achievements mirror the unlock list one-to-one, plus milestones
(first clear, first merge, every boss, 10, 50, and 100 runs). They trigger
on the run fact, immediately.

- **`src/achievements.w`, platform-neutral:** a table of `{ api_name,
  condition }` over the existing `Condition` type, and `earned(save) ->
  Vec[str]`. This works whether or not Steam exists, and the Collection can
  show it.

  | Group | Count | Source |
  |---|---|---|
  | Ships | 8 | `Ship.condition()`, `src/ships.w:147-156` (Null is secret, so hidden on Steam) |
  | Weapons | 3 | `weapon_condition`: Lance, Mines, Shard |
  | Passives | 6 | `passive_condition`: Cooldown, Armor, Luck, Credit, Rebound, Overclock |
  | Maps | 4 | `stage_condition`: Corridor, Shaft, Ring, Cross |
  | Bosses | 3 | `boss_slain` |
  | Milestones | 5 | first clear, first merge, 10, 50, and 100 runs |

  That is about 29 achievements. API names are stable identifiers such as
  `SHIP_DART` and `BOSS_2`. Never rename one after release.
- **Sync, not events.** At startup, after stats are available, and after
  every `persist()`, Steam gets `SetAchievement` for each earned name it
  does not have yet, then one `StoreStats`. This is idempotent and
  retroactive: a player with a pre-Steam save gets their achievements on
  first launch. It is also offline-safe, because the Steam client queues
  the stores.
- **"Immediately."** Most conditions are only folded into the save at run
  end (`record_run`, `src/save.w:248`). During a run, evaluate
  `earned(record_run(save, &game).0)` once a second so that, for example,
  "survive five minutes" pops at 5:00 and not on the results screen.
  Run-count milestones only count finished runs.
- **Progress (optional):** `progress(c, s)` (`src/account.w:148`) already
  returns (have, need). Pass it to `IndicateAchievementProgress` at
  25/50/75%, or back the counters with Steam stats.
- **In Steamworks:** define each API name with a display name, description,
  achieved and unachieved icons, and the hidden flag (Null, and any spoiler
  map).

### 7.2 Steam Cloud: Auto-Cloud, zero code

Configure Auto-Cloud in Steamworks. There is no API use.

| OS | Root | Subdirectory | Pattern |
|---|---|---|---|
| Linux / Deck | `LinuxXdgDataHome` | `wipe` | `save.txt`, `save.bak` |
| macOS | `MacAppSupport` | `WIPE` | `save.txt`, `save.bak` |
| Windows | `WinAppDataRoaming` | `WIPE` | `save.txt`, `save.bak` |

- Add root overrides so one save follows the player across operating
  systems.
- Do **not** sync `settings.txt` (per machine), `runs/` (recordings can be
  large), `runs.tsv`, or the tuning files.
- A quota of 1 MB and 4 files is plenty.
- Steam syncs at launch and exit and asks the player on a conflict. The
  game's own backup file remains the second line of defense.

### 7.3 Overlay

- The overlay works in the Steam build with no code: Shift+Tab on desktop,
  the Steam button on the Deck. Steam injects it into the GL context.
- `GameOverlayActivated_t` with `m_bActive` set moves a running game to
  `.Pause`, through the same path as focus loss (`src/app.w:300`).

### 7.4 Optional, later

- **Rich presence:** "Minute 12 · Hull · Ring" through `SetRichPresence`
  and a localization tokens file uploaded to Steamworks.
- **Leaderboards:** the M4 stretch goals, a friend's best time as a marker
  and a daily-seed list.
- **Timeline markers:** boss arrivals and deaths in Steam's game recording.
- **Screenshots:** nothing to do. Steam's screenshot key (F12, or Steam+R1
  on the Deck) captures the frame.
- **Framerate reporting (SDK 1.65):** `ISteamApps::SetGameRenderResolution`
  and `SetGamePerformanceSetting` tell Steam the render resolution and
  preset in use. Valve attaches them to the anonymous framerate data of
  players who opted in. Call them whenever the Options screen changes
  either value.

---

## 8. Linux build (the Deck runs Linux)

SteamOS is x86_64 Linux, and the game runs there as a native Linux build.
That is decided (§14): no Proton build. There is no translation layer, and
it is the same binary a desktop Linux player runs.

**Build on Linux, not from the Mac.** With has `--target linux_x86_64`,
but it cannot cross-build this game today:

- `c_import` refuses to run under `--target`, because it would parse the
  host's headers (`src/CImport.w:588-592` in the compiler repo). raylib and
  SDL are both `c_import`ed.
- Conan package selection uses the host's OS and architecture, and
  `.with/deps/c/<name>/<version>` has no target key.
- No Linux sysroot is bundled. `WITH_LINUX_SYSROOT` must point at one.

So the Linux binary is built on Linux x86_64, with a With compiler built
for that host. That can be a VM, a CI runner, or, best, the `steamrt4` SDK
container, which builds against the same libraries the game runs with.
Native Linux links go through the system `cc` as the linker driver
(`src/compiler/Link.w:331-367`). That is a toolchain dependency, not C
source in the game.

**Runtime environment:**

- Valve recommends **Steam Linux Runtime 4.0** for new native games. Build
  against the `steamrt4` SDK, or make sure the binary's glibc and library
  symbol versions are no newer than the runtime's. Select the runtime in
  the app's Linux launch option in Steamworks.
- Native dependencies for Linux x86_64: raylib 6.0 with GLFW's X11 backend
  (gamescope runs X11 games through Xwayland), SDL3 3.4.14 built with udev
  and hidapi, and OpenGL from Mesa (the Deck's AMD GPU uses radeonsi).
  `with.toml` pins the versions, and the Conan packages have to exist for
  `linux-x86_64`.
- Ship `libsteam_api.so` beside the executable in the Steam depot only.
  The Steam target links it and needs an `$ORIGIN` rpath to find it there
  (§6.4). raylib and SDL come from static Conan packages, so the game has
  no other shared libraries of its own.
- Linux filesystems are case-sensitive. The asset names in `build.w` and on
  disk already match.
- The macOS-only framework list in `build.w` is already guarded by
  `os() == "Macos"`. Linux needs its own system libraries (X11, GL, udev,
  and pthread/dl).

**Try the Deck without Steam first:** copy the Linux build to the Deck,
run it from Desktop Mode, then add it as a non-Steam game in Game Mode.
This proves the non-exclusive path on the real hardware before Steamworks
is involved. The SteamOS Devkit Client can deploy builds to a Deck in
developer mode.

---

## 9. Steam Deck Verified checklist

| Criterion (Valve) | Today | Work |
|---|---|---|
| Default controller config reaches all content | Pass, with the Gamepad template; every screen is pad-navigable | Keep the new Options screen pad-navigable |
| Glyphs match the active input | Fail: prompts mix keyboard and pad | §5 prompts |
| No keyboard or mouse glyphs when they are not the active input | Fail | §5 prompts |
| Text input possible with a controller | Pass: no text entry | — |
| Runs at a Deck resolution (1280×800 preferred) | Pass: the canvas is 1280×800 | §4 so docked and other resolutions also work |
| Smallest character at least 9 px tall at 1280×800 | Unknown: many labels use size 10 of raylib's 10 px bitmap font, and capitals are shorter than the cell | Measure on captured frames. Raise the floor to 12 to 14, or use a TTF (§4.3) |
| No compatibility warnings or launcher | Pass | — |
| 30 fps at 800p on default settings | Unmeasured on the Deck. The spec target is 60 fps at 1,000 enemies | Run the `uat` bench and F3 stress on the device |
| Suspend and resume | Runs clamp the delta, but attract does not | §4.4 clamp. Test sleep mid-run, then resume |
| Speaker mix (spec §3) | Unchecked | Listen on the Deck speakers and record it in `docs/verification/report.md` |

Steam Machine is tested against the same input criteria and 30 fps at
1080p, without the display tests. Verified on Deck implies Verified on
Steam Machine, and §4 covers the TV case.

---

## 10. Steamworks configuration and depots

SDK 1.65 (2026-07-23). Its `redistributable_bin/`, which holds
`libsteam_api` for every platform, is committed at
`vendor/steamworks/redistributable_bin/`; the SDK terms permit
redistributing that directory and nothing else. Every machine that builds
`wipe-steam` (the Mac, the Linux host, the `steamrt4` container) extracts
the SDK's `public/steam/` headers into the ignored
`vendor/steamworks/public/` itself. `vendor/steamworks/README.md` has the
commands. The plain `wipe` build needs neither.

Not code, but release-blocking:

- The app ID. `steam_appid.txt` is for development only.
- Depots: Linux (`wipe`, `assets/`, `libsteam_api.so`); macOS (`wipe`,
  `assets/`, `libsteam_api.dylib`, signed and notarized); Windows only if a
  Windows build exists. Upload with SteamPipe.
- Launch options per OS. On Linux, select Steam Linux Runtime 4.0.
- Steam Input: default configuration, and opt in the Deck and the Steam
  Controller.
- Achievements: API names from §7.1, with icons and hidden flags.
- Auto-Cloud: roots from §7.2.
- Store page: Full Controller Support, the SteamOS/Linux and macOS
  platforms. Then request the Deck compatibility review.

---

## 11. Tests and acceptance

- **Contracts:** settings round-trip; `letterbox` for each §4.2 size;
  mouse mapping inverts the letterbox; `earned()` on the veteran fixture
  (`WIPE_PLAY_VETERAN`) returns every achievement, and on a fresh save
  returns none; API names are unique.
- **The plain build stays plain:** `wipe` has no `SteamAPI_` strings and no
  `libsteam_api` in its dynamic dependencies (`strings`, `otool -L`,
  `ldd`). `wipe-steam` resolves `libsteam_api` from its own directory: `ldd`
  shows it found through `$ORIGIN`, and `otool -L` through
  `@loader_path`.
- **Nothing from the SDK but the libraries is tracked:** `git ls-files
  vendor` lists only `redistributable_bin/` and the README.
- **Binding check without our app ID:** a `steam-uat` executable run with
  `steam_appid.txt` = 480 (Valve's Spacewar test app, which has test
  achievements). It checks init, the accessors, manual dispatch, setting
  and clearing an achievement, and the overlay callback. It also checks
  that the game continues when Steam is closed.
- **Tour:** screenshots at three output sizes, plus the Options screen.
- **Hardware, recorded in `docs/verification/report.md`:**
  - Deck handheld in Game Mode, docked at 1080p and 4K, and in Desktop
    Mode.
  - Sleep and resume mid-run.
  - Overlay pause; glyphs; text size on captured frames.
  - The F3 stress at 60 fps; battery draw; the speaker mix.
  - A non-Steam launch on the Deck.

---

## 12. Order of work

Each step leaves the game shippable without Steam.

1. **Options screen, `settings.txt`, letterbox, mouse mapping, borderless
   fullscreen, VSync, frame cap, delta clamp.** Every platform benefits,
   and it is all testable on the Mac today.
2. **Prompts by active device, cursor hiding, a text-size floor, and
   deleting `native/glfw/`.**
3. **Linux build** on a Linux host or the `steamrt4` SDK container (§8).
   Run it on desktop Linux and on the Deck without Steam.
4. **Render at output resolution (§4.3).** Can move after step 6 if
   docked sharpness can wait.
5. **The `Platform` seam, `src/steam.w` importing `steam_api_flat.h`,
   the `wipe-steam` target with linking and rpath, and the Spacewar
   harness.** This needs the compiler plan (`c++_import.md`, including its
   rpath section) to land first.
6. **Achievement table and sync, overlay pause, gating the lizard-mode
   code under Steam.**
7. **Steamworks configuration, depots, Deck hardware acceptance, and the
   Verified review.**

---

## 13. Advice that does not apply here

Common Steam Deck advice, checked against this tree:

| Advice | For WIPE |
|---|---|
| "Query the display with `SDL_GetCurrentDisplayMode`." | raylib and GLFW own the window. SDL is initialized only for gamepads. `GetMonitorWidth/Height` and `GetRenderWidth/Height` give the same answer. (That snippet is also SDL2; the tree uses SDL3.) |
| "Render to a virtual framebuffer and let gamescope letterbox." | The first half is already true: the 1280×800 scene. The game letterboxes itself (§4.2), because gamescope only exists on SteamOS and the game must be correct everywhere. |
| "Use OpenGL 3.3+ or Vulkan; use `SDL_Renderer` with VSync." | Already OpenGL 3.3 core through raylib. `SDL_Renderer` is not involved. VSync becomes an option (§4.4). The Deck's panels are fixed 60 or 90 Hz, not variable refresh. |
| "Steam has a C-compatible ABI you can call with that header." | The ABI half is right: the flat functions have C linkage and the C calling convention, and With calls them. The header half is not. The flat functions are declared in `steam_api_flat.h`, which includes the C++ `steam_api.h`, so neither header parses as C, and With's `c_import` is C-only (§6.1). |
| "`SteamAPI_Init()` and `SteamAPI_SteamUserStats_v012()`." | `SteamAPI_Init` is an inline C++ wrapper in current SDKs; the flat entry point is `SteamAPI_InitFlat`. Accessor suffixes change between SDK versions and must match the shipped SDK (§6.3). |
| "If `SteamAPI_Init` fails, print and exit." | That breaks rule 1. The game continues without Steam. |
| "Call `SteamAPI_RunCallbacks()` every frame." | That dispatches to C++ callback objects. From With, use manual dispatch (§6.2). |
| "Screenshots and chat need no code." | Correct. |
| "`gcc … -lsteam_api`." | No C compiler: `wipe-steam` links `libsteam_api` through `c_import`'s `link:`, and `build.w` supplies the search path (§6.4). |

---

## 14. Decisions

**Decided (2026-09-27):**

1. **Native Linux on the Deck.** No Proton build. The Linux binary is built
   on a Linux host (§8).
2. **Two targets.** `wipe` is plain; `wipe-steam` adds the Steam platform
   (§6.5).

3. **Import `steam_api_flat.h` with `c_import`, and link `libsteam_api`**
   (§6.1, §6.4). This replaces the earlier plan of declarations generated
   from `steam_api.json` plus `dlopen`.
   - **The compiler gains the minimum** to read the header (`lang: "c++"`
     and the C-linkage surface) plus an rpath setting. That plan is
     approved: `/Users/eric/with/docs/plans/c++_import.md`.
   - **The functions are called directly,** and facades apply. There is no
     generator and no table of function pointers.
   - **The Steam build ships and links its library;** the plain build
     never sees it.
4. **Keep the hotkey title and add OPTIONS on the Menu button** (§3).
   - **It fits the spec.** The spec's pillars require every screen within
     two presses and the same buttons doing the same things everywhere
     (spec §11). A vertical list would put Options four presses away, so
     it would need a direct button anyway.
   - **It keeps the instant launch.** "A launches" stays one press.
   - **The harnesses keep working.** The playtest driver and the tour
     drive the title through confirm, shop, and collection, which stay the
     same.
   - **A face-button prompt row is a normal console title.** The Deck
     Verified work on this screen is the same either way: prompts for the
     active device.

**Open:**

5. **Render at output resolution (§4.3) before release.** Recommended:
   yes. Deck handheld does not need it, but docked play, Steam Machine on
   a TV, and Retina Macs look soft without it. A TTF font is an art call
   that can wait.
6. **Depots.** Recommended: Linux and macOS, the two builds that exist.
   Add Windows only if a Windows build is made.
7. **`ISteamInput`.** Recommended: not for the first release. SDL plus
   Steam Input's gamepad emulation meets the Verified criteria.
