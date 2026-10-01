# Steam and Steam Deck Support

What it takes to ship WIPE: SURVIVAL on Steam and to earn Steam Deck
Verified, without making the game depend on either. This is the working
inventory for milestone M4 (spec §16). Spec §3 (controls and platform), §12
(performance), and §15 (Steam) remain the requirements. This document says
what is missing and how to add it.

Implementation, compiler validation and macOS/Linux game tests completed on
**2026-09-30**, from WIPE
`d93a416` on `steamworks-sdk-1.65` and With `40aaf6f9` (`v0.15.3.0`).
The compiler candidate is isolated in `/private/tmp/with-steam-integration`.
The current scope is local implementation and testing; publishing and partner
portal changes are deferred at Eric's request. No Steam or Deck acceptance
is implied by code being present.

| Area | Current state | Next acceptance |
|---|---|---|
| Display and settings | Output-resolution surfaces, VSync/frame caps and per-machine settings; tours pass at 800p, 720p, 1080p and Retina 2560×1600 | Physical Deck, docked display and suspend/resume checks |
| Platform seam | Resource owners enforce cleanup order; normal and early-exit tests pass; overlay opening, active and closing frames block input | Real overlay callbacks |
| Achievements | 29 stable IDs; local Collection Awards; final 16-file macOS/Linux suites and late-callback retry contracts pass | Real store callbacks |
| Steam-aware controllers | Raw Valve access gated by launch environment or successful Steam initialization | Real Steam Input and standalone controller checks |
| Steam module | Full macOS game builds; real Spacewar initialization/query/manual dispatch, SDK failure fallback and missing-stats cleanup pass | Store callbacks and real overlay cycle |
| Compiler | Isolated candidate `b35b6d04` (ABI 12); focused regressions, main gate and complete battery pass | No further compiler work required for this test phase |
| Steam build and harness | Separate targets; plain build without SDK, link separation and clean plain package verified | Steam release package remains gated by assigned App ID; account/hardware checks |
| Native Linux and Deck | Final SDK builds and 16-file suite pass; strict runtime graphics/audio, two direct stress runs and normal exit pass; both test archives verified locally | Physical Deck checks |
| Steamworks setup | Deferred until testing is complete | Assigned App ID, achievements, controller configuration, Cloud, depots and review |

**Baseline defect diagnosed:** an imported C `clock` declaration overwrote a
different module's With function signature. Debugger evidence established the
collision; the compiler candidate now passes the reduced cross-module runtime
regression. Darwin availability-runtime support needed by SDL is also fixed,
and the plain macOS game builds without a Steam dynamic dependency. The earlier
session's 11-file pass remains historical evidence until the new suite passes.

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
  Settings live in WIPE's pause menu. Controllers go through SDL.
  Saves are plain files that Steam Cloud copies without the game knowing.
  Steam mirrors state the game already has. It never owns that state.
- Steam Deck is a set of defaults, not a mode. Detecting a Deck may choose
  fullscreen on first launch. It never hides an option or changes a rule.
- No Steam DRM wrapper. It adds nothing a DRM-free game wants.

**With only.** No C or C++ source, no shim library, no wrapper `.so`
compiled from C++. Steamworks is reached through its C-linkage flat API,
imported from `steam_api_flat.h` with `c_import` (§6). The unused C files from
the earlier `native/glfw/` controller experiment have been removed.

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

## 3. Settings file (implemented and merged)

The 2026-09-29 decision supersedes the original resolution-picker and
separate Options-screen request: the view follows the display (§4).
There is no separate options screen.
Volume, deadzone and display mode stay in the pause menu, and F11 toggles
fullscreen anywhere.

- **They live in `settings.txt`**, beside the save, in the same `key value`
  format, written atomically (`src/settings.w`). Settings are per machine
  and progress is per player: a Deck and a desktop sharing a Steam Cloud
  save must not trade display modes.
- **Migration:** on first run, when `settings.txt` is missing, `volume` and
  `deadzone` come from the save. The save still reads those keys and no
  longer writes them. Unknown keys are already ignored, so `SAVE_VERSION`
  stays 1.
- **A first launch under gamescope starts fullscreen**, detected through
  `SteamDeck=1` or `XDG_CURRENT_DESKTOP=gamescope`, both set by SteamOS.
- **The harnesses** (`uat`, `tour`, `gallery`, `play`, `bosses`) never read
  `settings.txt`.
- **Tests:** `test/save_contracts.w` covers the round trip, clamping,
  unknown keys, and migration.

---

## 4. Resolution and display

### 4.1 The view takes the screen's aspect ratio (decided 2026-09-29)

At startup the view fills the screen without stretching, cropping or
letterboxing, and the player never picks a resolution. The Deck's 1280×800
is the smallest view. A screen of
another shape grows it in one dimension to match (`view_size`,
`src/game.w`):

| Screen | View |
|---|---|
| Steam Deck, 16:10 | 1280×800 |
| 16:9 | 1422×800 |
| 21:9 (3440×1440) | 1911×800 |
| 4:3 | 1280×960 |

- **The view is part of the run.** The camera bounds, culling, and the
  view-edge spawns use it, so a wider screen sees more of the arena
  sideways. Recordings store it (`view W H`), so replays stay exact. A
  recording made before this change replays at 1280×800.
- **The screen decides the view once, at startup.** The window opens
  hidden, reads the monitor, and shows the view 1:1. It is shrunk
  uniformly only if the screen cannot hold it. Borderless fullscreen then
  fills the monitor at one scale, because the aspect ratios match. Changing
  to a different aspect ratio during play preserves the recorded view and
  fits it uniformly; bars can appear until the next launch.
- **Menus, pause and the boost cards keep their 1280×800 layout** in a
  frame centered in the view (`begin_frame`), and the mouse is offset to
  match. The HUD and world overlays anchor to the view's edges.
- **Rendering:** the logical view controls projection; the scene and both
  bloom tiers follow output pixel density (§4.2). The grid shader takes the
  view as a uniform, replacing its hard-coded `800`.
- **On a Deck,** gamescope reports 1280×800, so the view is unchanged. If
  the player sets Steam's per-game Game Resolution while docked, gamescope
  reports that screen, and the view follows it.
- **Verified:** the tour at 1280×800, 1422×800 and 1280×960
  (`WIPE_TOUR_VIEW=WxH`).

### 4.2 Sharpness above 800 lines (implemented; visual acceptance pending)

The scene and bloom surfaces follow the physical framebuffer while drawing
uses the logical view's projection. Resizing allocates replacements first and
keeps the old surfaces if allocation fails. Minimized windows retain their
surfaces. Grid coordinates and bloom radius account for output density.
The tour exercises resize, reuse and minimize behavior before its captures.
The bitmap font has a centralized size-20 floor and consistent measurement.
Actual lowercase alpha bounds give 10 visible pixels at 800p and 9 at 720p;
the tour asserts those bounds. Captures at 800p, 720p and 1080p were reviewed.
The final Mac Retina tour also verifies a 2560×1600 framebuffer and full-frame
captures from a 1280×800 logical window. The capture helper reads actual
framebuffer pixels and checks the dimensions; raylib 6's `TakeScreenshot`
applies the DPI scale twice and is no longer used by this tour.

### 4.3 Frame pacing

- **Done:** the frame time is clamped to 0.1 s in `src/run.w`, so the first
  frame after the Deck wakes cannot jump the menus or the attract run.
- **Implemented:** VSync defaults on; the frame limiter follows the display
  refresh by default, with optional 30/40/45/60/90/120 caps in pause settings.
- **Fixed:** the 120 Hz simulation retains fractional steps between render
  frames. The previous local accumulator lost simulation time at 90 Hz.
  A regression checks 30, 40, 45, 60, 90, 120, 144 and 240 Hz plus wake spikes.

---

## 5. Controls on the Deck

**How it works under Steam.** Steam Input owns the Deck's controls and
presents a virtual Xbox-style gamepad. SDL (2.0.8 and later, including
SDL3) honors Steam's instruction to hide the raw device, so the game sees
exactly one pad. WIPE's SDL path needs no Steam Input API to pass Verified.
In Steamworks, start with the **Gamepad** template, which Valve's
[gamepad-emulation guide](https://partner.steamgames.com/doc/features/steam_controller/steam_input_gamepad_emulation_bestpractices)
recommends for twin-stick games. Opt in the Steam Deck and the Steam
Controller. A custom mouse-emulating trackpad configuration needs the
prompt checks below before it becomes the default.

**Implemented in `src/gamepads.w`:**

- `SDL_JOYSTICK_HIDAPI_STEAM=1` (`:46`) and the lizard-mode report
  (`:136-150`) exist for bare Steam Controller use without Steam. Under
  Steam, Steam already manages lizard mode, and grabbing the physical
  device fights Steam Input. The Steam Virtual Gamepad also reports Valve's
  vendor ID. Both operations are now skipped when `SteamAppId` or
  `SteamGameId` is set, or when successful Steam initialization is passed
  through the platform seam. This also covers a direct launch with
  `steam_appid.txt` and no launch environment variables.
- Keep everything else. SDL's own Steam Deck HIDAPI driver still covers
  running outside Steam, for example from Desktop Mode or another store.

**Button prompts (a Verified requirement).** Valve's criteria: on-screen
glyphs must match the input in use, and keyboard or mouse glyphs must not
show when they are not the active input. Prompts now use one action/device
mapping across menus and gameplay, with captured keyboard and pad variants.

- The last meaningful keyboard/mouse or pad input selects prompts. Passive
  device discovery does not change the active device.
- Test the shipped Steam Input configuration too: if its right trackpad
  emits mouse events, touching it must not inadvertently replace Deck
  button prompts with keyboard hints. Start with the Gamepad template;
  add mouse-emulating bindings only with a verified device-detection path.
- Xbox letters (A, B, X, Y, LB, RB) match the Deck's physical labels. Start
  is the Deck's ☰ Menu button. Say MENU, or draw the glyph, instead of
  START when the pad is a Deck or a Steam Virtual Gamepad.
- Optional: PlayStation and Switch labels through SDL3's
  `SDL_GetGamepadButtonLabel`. Also optional, as a later step: `ISteamInput`
  glyph lookup, which stays correct when a player remaps buttons in Steam.

**Other items:**

- The OS cursor hides while the pad is active and returns on mouse movement.
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

The headers that declare it are C++. Importing `steam_api_flat.h` also
imports the requested `steam_api.h` through its include chain; no C or
C++ source or shim is added to WIPE. Valve documents this as the
[flat interface for other languages](https://partner.steamgames.com/doc/sdk/api).

- `steam_api_flat.h` declares the flat functions, but its first lines
  `#include "steam/steam_api.h"` and the game-server headers.
- `steam_api.h` pulls in `steam_api_common.h`: `class CCallbackBase` with
  virtual methods, `template<class T, class P> class CCallResult`,
  `template<…> class CCallback`, and the `ISteam*` interface classes.

A C parser stops at the first `class` before it reaches any flat
declaration. The functions are callable. The header is the problem.

**Compiler baseline before this work** (paths in the compiler repo):

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

The isolated candidate now supports the approved (§14) C++ mode and links
the library directly:

```with
use c_import("steam/steam_api_flat.h", lang: "c++", link: "steam_api")
```

- **The compiler work** implements
  `/Users/eric/with/docs/plans/c++_import.md`:
  - a `lang: "c++"` option that imports only the `extern "C"` surface;
  - a layout check that makes C++ classes opaque;
  - callback IDs named by their struct (`UserStatsStored_t_k_iCallback`);
  - an rpath setting, which the Linux build needs (§6.4).

  It was checked against SDK 1.65: the header parses as C++ with no
  errors. The 34 flat functions that take C++ references are skipped, and
  WIPE uses none of them.
- **Only `src/steam.w` imports the header,** and only the `wipe-steam` and
  `steam-uat` targets build `src/steam.w`.
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
  - **Linux:** the candidate compiler's per-target `rpath` setting writes
    `$ORIGIN` into the executable. The SDK-built game resolves the library
    beside itself inside Steam Runtime 4. Search paths also participate in
    build caching, so changing one causes a relink.
- **Consequence:** the Steam build needs its library, and every Steam
  depot ships it. A missing Steam *client* is still handled at runtime
  (§6.3). The plain build has no dependency at all.

### 6.5 One seam: a `Platform` value

The game never calls Steam directly. `main` hands the app a platform
value, and the app calls it:

```with
trait Platform:
    fn frame(mut self: Self) -> PlatformFrame     // overlay opening/active/closing
    fn sync_achievements(mut self: Self, earned: &Vec[str])
    fn notice(self: &Self) -> str                 // empty when no notice is needed
    fn manages_controllers(self: &Self) -> bool
    fn shutdown(mut self: Self)
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

### 6.6 Adapter implementation and required acceptance

The adapter owns successful initialization separately from the stats pointer.
`run` declares the platform, window and audio owners before their dependent
resources. Reverse destruction releases those resources before closing their
devices, then shuts Steam down last, including on early returns. Shutdown is
idempotent. Manual dispatch checks callback size and payload,
frees every delivered message, and stops using interfaces after Steam shutdown.

`AchievementSync` remembers only successful queries/sets, keeps new unlocks
dirty during an in-flight store, retries failed stores and callbacks with a
2–60 second backoff, and recovers after a 15-second callback timeout.
Invalid-parameter results invalidate the observed cache. Accepted stores remain
counted through timeouts so a late response cannot confirm a newer retry. The
save remains the source of facts across launches. These retry contracts pass.
Real Spacewar initialization, query/manual dispatch and missing-stats cleanup
pass. The compiled `--store-unchanged` harness can test store callbacks without
unlock/reset calls; its account-data submission still requires approval.
The separate unlock/restore check also remains unapproved.

The pinned v013 interface synchronizes before process launch and has removed
`RequestCurrentStats`. The adapter uses its versioned accessors directly.
Overlay opening, active and closing frames suppress input, consume controller
edges, and clear per-frame sound events. Closing leaves gameplay paused.
Successful Steam initialization is passed to SDL's controller ownership gate.

`wipe-steam` and `steam-uat` have their own header/library paths and loader
search paths. The default remains `wipe`. Local packaging uses an explicit
allowlist, excludes development App ID files, and refuses App ID 0 or 480 for
a Steam release. The production ID is intentionally unset during this test
phase. A normal game launch under Spacewar keeps WIPE achievements local;
only `steam-uat` opts into the test achievement, verifies stores and restores
its original state.

These paths require downstream builds, real no-client/Spacewar checks, and
hardware acceptance before calling the integration complete.

---

## 7. Steam features

### 7.1 Achievements

Spec §15: achievements mirror the unlock list one-to-one, plus milestones
(first clear, first merge, every boss, 10, 50, and 100 runs). They trigger
on the run fact, immediately.

- **Implemented in `src/achievements.w`, platform-neutral:** an explicit
  `ACHIEVEMENT_IDS` table and `achievement_met` mapping reuse the existing
  unlock conditions, with `earned(save) -> Vec[str]`. This works whether
  or not Steam exists. A dedicated display of all achievement milestones
  in the Collection remains to be added if required; computing the table
  does not itself add that UI.

  | Group | Count | Source |
  |---|---|---|
  | Ships | 8 | `Ship.condition()`, `src/ships.w:147-156` (Null is secret, so hidden on Steam) |
  | Weapons | 3 | `weapon_condition`: Lance, Mines, Shard |
  | Passives | 6 | `passive_condition`: Cooldown, Armor, Luck, Credit, Rebound, Overclock |
  | Maps | 4 | `stage_condition`: Corridor, Shaft, Ring, Cross |
  | Bosses | 3 | `boss_slain` |
  | Milestones | 5 | first clear, first merge, 10, 50, and 100 runs |

  That is exactly 29 achievements. The committed API names include
  `SHIP_DART`, `BOSS_WARDEN`, `BOSS_LANCER`, and `BOSS_HIVE`.
  Use `ACHIEVEMENT_IDS` as the configuration source, and never rename an
  ID after release.
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
  This provisional evaluation and the one-second sync call are implemented
  in `App.achievements_now` and `run`; upload is implemented in `steam`. Verify
  first-clear, boss, merge and run-count boundaries, and synchronization
  after persisted changes and before normal exit.
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
  players who opted in. If adopted, report the actual render size at
  startup and whenever the renderer changes it.

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

- Valve recommends **Steam Linux Runtime 4.0** for new native games in its
  [Steam Runtime documentation](https://github.com/ValveSoftware/steam-runtime). Build
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

Valve's [current compatibility criteria](https://partner.steamgames.com/doc/steamhardware/compat)
are the release authority; the table below is a local readiness assessment,
not a Verified result. Suspend/resume and speaker checks are additional
WIPE acceptance work.

| Criterion (Valve) | Today | Work |
|---|---|---|
| Default controller config reaches all content | Pad navigation exists; shipped Steam Input configuration untested | Verify every screen, including pause settings, on the Deck |
| Glyphs match the active input | Implemented and captured for keyboard and pad | Verify Deck's active Steam Input configuration |
| No keyboard or mouse glyphs when they are not the active input | Prompts follow the last meaningful input; pad hides cursor | Physical input-switching acceptance |
| Text input possible with a controller | Pass: no text entry | — |
| Runs at a Deck resolution (1280×800 preferred) | Implemented: minimum view 1280×800, screen aspect ratio followed | Confirm handheld 1280×800, 1280×720 override and docked output on hardware |
| Smallest character at least 9 px tall at 1280×800 | Actual lowercase bitmap bounds measure 10px at 800p and 9px at 720p; captures reviewed | Confirm handheld readability on Deck |
| No compatibility warnings or launcher | Pass | — |
| 30 fps at 800p on default settings | Unmeasured on the Deck. The spec target is 60 fps at 1,000 enemies | Run the `uat` bench and F3 stress on the device |
| Suspend and resume | Shared loop clamps menu, attract and run frame time (§4.3) | Test sleep mid-run, controller reconnection, audio and Steam recovery |
| Speaker mix (spec §3) | Unchecked | Listen on the Deck speakers and record it in `docs/verification/report.md` |

Steam Machine has the same input criteria and a 30 fps target at 1080p,
without the Deck display tests. Record its result separately if targeted;
do not treat WIPE's unmeasured Deck performance as TV acceptance.

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
- Depots: Linux (`wipe-steam`, `assets/`, `libsteam_api.so`); macOS (`wipe-steam`,
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

- **Contracts:** settings round-trip; `view_size` for each §4.1 screen, and
  `fit` filling it at one scale; `earned()` on the veteran fixture
  (`WIPE_PLAY_VETERAN`) returns every achievement, and on a fresh save
  returns none; API names are unique.
- **Lifecycle/retry contracts:** initialization failure, missing stats
  interface after successful initialization, early game exit, failed set,
  failed store and failed completion callback, repeated earned snapshots,
  overlay-open input suppression and shutdown. Use a platform-neutral
  fake for state transitions, then the real SDK harness for ABI behavior.
- **The plain build stays plain:** `wipe` has no unresolved Steam API symbols
  and no `libsteam_api` in its dynamic dependencies (`nm -u`, `otool -L`,
  `ldd`). SDL's static archive contains optional Steam storage function-name
  strings, so string absence is not a valid dependency test. `wipe-steam`
  resolves `libsteam_api` from its own directory: `ldd`
  shows it found through `$ORIGIN`, and `otool -L` through
  `@loader_path`.
- **Nothing from the SDK but the libraries is tracked:** `git ls-files
  vendor` lists only `redistributable_bin/` and the README.
- **Binding check without our app ID:** a `steam-uat` executable run with
  `steam_appid.txt` = 480 (Valve's Spacewar test app, which has test
  achievements). It checks init, the accessors, manual dispatch, setting
  and restoring a test achievement's original state, and the overlay
  callback. Use a test account and Spacewar IDs, never WIPE achievement
  IDs against app 480. The test requires an initially locked achievement;
  Steam may retain unlock history after the visible flag is restored. The
  macOS read-only probe and missing-stats cleanup pass. The deterministic
  disabled-Steam path passes; actual disconnected-client acceptance remains.
- **Tour:** screenshots at three output sizes, plus the pause settings.
- **Hardware, recorded in `docs/verification/report.md`:**
  - Deck handheld in Game Mode, docked at 1080p and 4K, and in Desktop
    Mode.
  - Sleep and resume mid-run.
  - Overlay pause; glyphs; text size on captured frames.
  - The F3 stress at 60 fps; battery draw; the speaker mix.
  - A non-Steam launch on the Deck.

---

## 12. Order of work

The plain game remains a first-class deliverable at every step. The
display/settings work and the platform/achievement foundation are already
committed; do not recreate them.

1. **Baseline restored.** The `clock` collision is fixed; all 16 WIPE test
   files pass on macOS and Linux with the isolated compiler.
2. **Compiler prerequisites complete, in With.** C++ C-linkage imports,
   honest opaque layouts, callback constants, cache separation, per-target
   library paths and rpaths are implemented. The real SDK layout checks and
   full compiler battery pass. Changes are local commits; publishing remains
   deferred.
3. **Steam module and targets implemented.** Both binaries and the harness
   build with the intended dependencies. Read-only Spacewar, SDK failure,
   missing-stats and cleanup checks pass. Store callbacks and a real overlay
   cycle remain acceptance checks (§6.6).
4. **Deck UI implemented.** Active-device prompts, cursor hiding, measured
   text-size floor and controller navigation pass automated checks. The unused
   `native/glfw/` experiment is removed. Physical controls remain to be tested.
5. **Linux test packaging complete.** Both Steam Runtime SDK-built variants
   pass strict-runtime launch, cleanup, graphics and audio checks. Allowlisted
   test archives and verified checksums are in `out/verification/linux/`.
6. **Rendering and pacing implemented.** Output-resolution surfaces, VSync
   and frame caps pass desktop checks, including Retina. LCD/OLED performance,
   docking and suspend/resume still require the Deck and its displays.
7. **Release configuration deferred.** Assigned App ID, achievement schemas,
   Cloud, controller defaults, depots and Verified submission await the later
   publishing phase. Real offline recovery and hardware acceptance must be
   recorded before that phase is considered complete.

---

## 13. Advice that does not apply here

Common Steam Deck advice, checked against this tree:

| Advice | For WIPE |
|---|---|
| "Query the display with `SDL_GetCurrentDisplayMode`." | raylib and GLFW own the window. SDL is initialized only for gamepads. `GetMonitorWidth/Height` and `GetRenderWidth/Height` give the same answer. (That snippet is also SDL2; the tree uses SDL3.) |
| "Render to a virtual framebuffer and let gamescope letterbox." | Not needed: the view takes the screen's aspect ratio (§4.1), so there is nothing to letterbox, on SteamOS or anywhere else. |
| "Use OpenGL 3.3+ or Vulkan; use `SDL_Renderer` with VSync." | Already OpenGL 3.3 core through raylib. `SDL_Renderer` is not involved. VSync/frame caps are implemented (§4.3). Test the available LCD/OLED refresh settings. |
| "Steam has a C-compatible ABI you can call with that header." | The flat functions have C linkage and the C calling convention. The header is C++: `steam_api_flat.h` includes `steam_api.h`. The compiler candidate's explicit `lang: "c++"` mode handles that boundary (§6.1). |
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
4. **Display/settings decision updated 2026-09-29:** retain the hotkey
   title, follow the screen's aspect ratio automatically, and keep volume,
   deadzone and fullscreen in the pause menu (§3–4). This supersedes the
   earlier proposal for an OPTIONS screen and resolution selector.
   Controller prompts now reflect the active device.

5. **Render at output resolution (§4.2).** Implemented 2026-09-30. The view
   follows the screen's aspect ratio with no resolution setting; scene and
   bloom surfaces follow the actual framebuffer. Docked and Retina acceptance
   remains a hardware check.

**Open:**
6. **Depots.** Target Linux and macOS; both have desktop build and runtime
   evidence, and Linux test bundles are ready. Deck acceptance remains. Add Windows
   only if a Windows build is made and tested.
7. **`ISteamInput`.** Recommended: not for the first release. SDL plus
   Steam Input's gamepad emulation can provide the controls; the shipped
   configuration, glyphs and every screen still need acceptance (§5, §9).
