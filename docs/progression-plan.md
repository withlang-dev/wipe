# WIPE: SURVIVAL — Progression Plan

Decided 2026-10-13. The run is right; the content around it is an order of
magnitude too narrow, and the rewards arrive in the wrong order. This plan
borrows Vampire Survivors' reward cadence, not its combat: WIPE keeps its
20-minute run, its enemy roles, its bosses at 5, 10 and 15 and the Null at
20, and grows the content that run draws from, revealed gradually, measured
at every step. The item-by-item schedule is [progression-matrix.md](progression-matrix.md).

## 1. Targets

| | Now | Target |
|---|---|---|
| Ships | 9 | 24–28, in three tiers (§6) |
| Base weapons | 8 | 20 |
| Evolutions | 8 | 20, one per base weapon |
| Unions | 4 | 5–6 at first, room for 8 |
| Passives | 14 | 18 |
| Stages | 9 | 15, each changing one core variable |
| Run | 20 min | 20 min; Hurry after the first clear |

These are ceilings to grow toward, not launch requirements. An item enters
only if it creates a new decision (§5.1), and the pool is revealed by
accomplishment (§4), so the count a new player sees stays small.

## 2. Three constraints

1. **Every new weapon changes player behavior**, not only projectile
   geometry. About a third of the arsenal must relate to aim direction,
   movement, turning, position or arena geometry: the Geometry Wars half of
   the identity. The matrix has a column for each; a weapon blank in all
   three is questioned.
2. **Every early run materially advances a visible progression thread.**
   Measured, §3.
3. **The pool is revealed gradually**, by what the player has done, never by
   account time. Account time is an acceptance metric only.

## 3. Telemetry first

The harness (`runs.tsv`, exact recordings, `runs calibrate`, `runs profile`,
the bot) captures today's curve before any gate moves, so every change
below is a before/after number, not a feeling. New measures, computed from
the save before and after each run (so they apply to historical recordings
too):

**Progression score per run**

| Points | Event |
|---|---|
| 3 | stage, ship, weapon, passive or mode unlocked |
| 3 | merge discovered |
| 2 | a shop rank bought, or one newly affordable |
| 2 | a derelict objective completed |
| 1 | a named goal advanced by 20% or more |
| 0 | nothing changed |

Tracked: `zero_progress_streak` and `progress_events_per_hour`.

**Time to first**, in runs and account minutes: `first_weapon_unlock`,
`first_ship_unlock`, `first_merge`, `first_new_stage`, `first_clear`,
`first_hurry_clear`.

**Weapon exposure**: runs between a weapon's unlock and its first pick. A
freshly unlocked weapon is weighted up in the draft for its first one or two
runs until picked (a weight in the seeded draft, so replays stay exact).

**Acceptance, fresh account, median human**

- No two consecutive zero-progress runs in the first three hours.
- Two to four plausible goals visible at once in the first 90 minutes.
- Survival: run 1 to about 5:00; runs 2–3 to 8–10:00; runs 4–5 to 13–15:00
  with boss 3 seen; first clear by run 6–8, at one to one and a half hours.

## 4. Staged content

The draft draws from the account's pool, and the pool widens by tier. Each
tier is a `Condition` on the save, like every unlock today, and the matrix
places every item in one.

| Tier | Opens on | Pool |
|---|---|---|
| 1 Starter | a new account | 6–8 weapons, 8 passives |
| 2 | first boss kill, 5:00 and 8:00 survived | ~10 weapons, 11 passives |
| 3 | first merge, first stage unlock, 12:00 survived | ~14 weapons, 15 passives |
| 4 | first clear, Hurry, challenge stages | the full 20 and 18 |

A strong player moves through the tiers in an evening; a struggling one
still opens tier 2 from achievable milestones.

## 5. Weapons

### 5.1 The review columns

Every weapon in the matrix states its damage role, input interaction,
movement interaction and geometry interaction. The arsenal needs builds
that never aim (Orbit, Arc, Drone, Tesla Field, Gravity Well) and builds
that are nothing but aim and position (Cannon, Lob, Tether, Shard, Mines):
both, deliberately.

### 5.2 Proximity Mine (replaces Mines)

- One mine every 3 s at the ship's position. `FireRate` and `Cooldown`
  shorten the interval.
- The drop is **skipped, not queued**, while the ship is within 1.5 × the
  trigger radius of a live mine: moving lays infrastructure, standing still
  stops production. No mine ever stacks.
- Trigger and blast radius scale with `Area`. `Damage` applies.
- `Count` changes **storage, never rate**: `cap = base + min(count_bonus, 4)`.
  Base cap 8; the stress harness decides whether it can be more. The
  oldest mine expires first.
- Minefield (evolution, key `Cooldown`) chain-detonates; Grid (union with
  Arc) stays.

### 5.3 The new twelve, prototyped in this order

**Tether** first: it tests whether the second stick makes a survivor
weapon. A blade on a short chain of linked segments (Verlet, in the fixed
step, so replays stay exact). Turn rate becomes angular lag becomes sweep
width. Angular acceleration is capped, so a committed turn swings wide and
wiggling the stick does nothing. Evolution: a longer chain and a second
blade mid-rope.

**Gravity Well** second: it tests whether displacement is a build axis. A
slow point that pulls enemies in and crushes them. Union with Nova: pull,
then burst.

**Drone** third: VS's birds. It flies its own orbit and targets **the
nearest enemy outside the player's forward aim cone**: the front is the
player's, the flank is the Drone's. One firing system that escalates:
bolt, faster bolt, burst, piercing pulse, short chaining beam. Evolution:
twin drones with chained beams. Union with Turret: an autonomous weapons
net.

**Lob** fourth: a shell along the aim stick to a fixed distance that grows
with level, bursting on landing, with a minimum range. Cannon shoots what
you look at; Lob aims past the near enemies at the far concentration.

Then: Flak, Turret, Sweep, Tesla Field, Boomerang, Shockwave (damage plus a
short vulnerability mark, never pure knockback), Satellite, Repulsor.
Decoy is on the experimental shelf: it attacks the AI, not the HP pool.

### 5.4 Displacement

Shockwave pushes, Gravity Well pulls, and both touch every behavior, so
one rule: **each enemy kind has a displacement resistance**. Darts light,
Blocks heavy, Spinners moderate, elites high, bosses immune. One table in
`game.w`, and a future passive axis if wanted.

### 5.5 Evolutions and unions

One evolution per base weapon, its key passive from the matrix. Keys are
distributed on purpose: most passives key one or two evolutions, a few key
none, and the premium stats (Cooldown, Damage) do not also key the top
weapons. Unions stay at five or six until playtests show "build toward a
union" is not the only strategy: the four today plus Drone + Turret and
Gravity Well + Nova. Tether + Boomerang waits for a result neither has
alone.

## 6. Passives

Keep the fourteen. Add:

- **Duration**: orbit, beam, mine, drone lifetimes. Keys Sweep and Satellite.
- **Pierce**: +1 pierce on every projectile. Keys Flak.
- **Failsafe**: one revival, ever, per run. I: revive at 20% hull; II: 30%;
  III: +1 s invulnerability after; IV: 50%; V: +2 s and a shockwave on
  revival. Every level does something, and the shop's Reboot stays the
  account's safety net while Failsafe is a build choice that costs a slot.
- **Overclock V**: Overclock keeps its identity (danger for XP and credits)
  and its last level is dramatic in both directions.

## 7. Ships

Three tiers, 24–28 in all:

| Tier | Count | Purpose |
|---|---|---|
| Authored | 10–12 | Rule-changing identities: Hull, Phase, Sapper, Halo and their peers |
| Specialists | 8–12 | Start with one weapon and teach its family |
| Secrets | 3–5 | Odd goals, broken rules; Null is the first |

Not one mascot per weapon: the authored ships are what make WIPE's roster
better than VS's early characters, and they are not diluted.

**Derelicts** (VS's coffins): a wreck placed in a stage. The verb varies so
it never becomes a checklist: defend it for 60 s, chase it as it drifts,
activate three relays, kill the elite carrying its core, survive the zone
around it. And the reward varies: some grant the ship, some recover a
**black box** that reveals a ship's condition ("Survive 3 minutes below 25%
hull"), some drop a hint. Exploration feeds the web instead of resolving
on the spot.

## 8. Stages and modes

Level gates within a run replace lifetime gates, so a failed run still
opens doors. The numbers are the bot's and the run log's to set; the shape:

| Stage | Opens | Intended |
|---|---|---|
| Corridor | level ~12 in a run | run 1, a decent beginner |
| Shaft | ~20 | before the first clear |
| Ring | ~28 | around the first clear |
| Cross | ~35 | shortly after |

The first clear unlocks a **system**: **Hurry**. A Hurry clear unlocks the
first challenge stage; the Null, Endless. Each mode is earned, and the
20-minute structure is protected until the player has proved it.

**Hurry** advances **timeline time** at 2× (waves, bosses, the XP curve,
the 20:00 end) while **simulation time** stays real (movement, telegraphs,
projectiles, invulnerability, pickups). It is a `Rules` field,
`timeline_rate`, not a flag, so a challenge stage can run at 1.5. The
timeline already reads the step count, so the mechanism is small; the
card-screen cadence per real minute doubles and needs its own tuning pass.

Fifteen stages, 5 normal / 5 bonus / 4 challenge / 1 hidden as an
organizing shape, not a rule. Each stage changes **one** core variable:
geometry, visibility, composition, spawn topology, mobility, resources or
the clock. WIPE's arenas are bounded and geometric, which VS's are not:
rotating safe sectors, a collapsing arena, a mirrored arena, moving walls
are more WIPE than +300% HP.

## 9. Pressure and power

Two dials, both in the code today.

**Enemies: fewer, tougher, earlier.** Health grows with the square of the
minute (`base_hp`), but opening enemies die to one hit and the first ten
minutes' pressure is the spawn rate. Swap the roles: a Block reaches 2 HP by
1:30, 5 by 3:00, 12 by 5:00, so `Damage`, `FireRate` and weapon levels
matter from minute two; `spawn_rate` ramps flatter and the cap comes down,
so the screen stays readable and the hitboxes survivable; "when the budget
fills, spawn tougher, not more" becomes the main dial. **XP and credits per
kill follow the enemy's max HP**, so fewer kills leave the XP curve per
minute where it is. Pressure is `fewer × tougher × role mix`.

**The account: ranks that lift the ceiling, one per run.** A fresh account
hitting a wall at 5:00 is right; the ranks must raise it faster. In the
first hour a rank should be about one run of income away (today 1.3), and
the early ranks are the ones that move survival: hull, armor, starting
weapon level, a reboot. Weapon and passive unlocks in hour one are power
steps the shop does not have to buy.

## 10. HUD

Health is ship icons, the arcade's lives (implemented 2026-10-13,
`health_icons` in `presentation.w`): one icon per four hull, filled while
intact, hollow once lost. A hull past 32 (the Hull ship, which doubles its
health and grows it per level) thickens the icons instead of adding more,
so the row never passes eight. Max health by source, for anything that
touches it: base 10; shop Hull +1 per rank; Hull passive +2 per level; Null
+3; Dart halves; Phase 1; Hull ship ×2 then +1.5 per level +3.

## 11. Phased implementation

Eight phases, each landing on `main` with its tests and its `runs` numbers.
Dependencies are stated so the order is justified, not asserted. File
names are today's.

### Phase 1: Telemetry

Nothing else is measured without it, so it comes first and changes no
gameplay.

| | |
|---|---|
| Depends on | nothing |
| Touches | `src/save.w` (`record_run` returns what changed), `src/account.w` (a `progress_score(before: &Save, after: &Save) -> i32` and `progress_events`), `src/app.w` (`write_run_files` adds `score`, `events`, `streak` columns to `runs.tsv`), `src/runs.w` (new commands: `runs account DIR` reads a `runs.tsv` and prints the score per run, `zero_progress_streak`, `progress_events_per_hour`, and the six time-to-first in runs and minutes; `runs exposure` prints runs from each weapon's unlock to its first pick) |
| New | `test/progression_contracts.w`: the score table of §3 on save pairs; a streak of two is reported; time-to-first from a synthetic log |
| Exit | `runs account` on your own `runs.tsv` and on a bot account (`runs profile` extended to play an account of twenty runs with the careful bot, buying ranks between runs) prints the control numbers, committed in `docs/verification/progression-control.md` |

### Phase 2: Hour one

The largest effect on a new player for the least code.

| | |
|---|---|
| Depends on | phase 1 (before/after) |
| Touches | `src/account.w` (`stage_condition`: Corridor/Shaft/Ring/Cross to `.Level`; `next_unlock` becomes `next_unlocks` returning near / new / stretch), `src/tuning.w` (`timeline_rate: f64 = 1.0` in `Rules`), `src/game.w` (`table_minute` and everything reading the timeline multiply by it; the step clock and physics do not), `src/ships.w` and `src/save.w` (a `hurry_clears` counter; Hurry's unlock is `.Clear`), `src/app.w` (a Hurry toggle on ship select once unlocked; results and Collection draw three threads), `src/presentation.w` (the three threads) |
| New | `test/hurry_contracts.w`: a Hurry run replays exactly; bosses arrive at real 2:30, 5:00, 7:30; invulnerability and projectile speed are unchanged. `test/threads_contracts.w`: three distinct threads, a 70%-complete ship is "near", a just-revealed condition is "new" |
| Exit | the bot's `first_new_stage` is run 1; your own is run 1 or 2; `zero_progress_streak` max falls against the control; Hurry's card-screen cadence per real minute recorded for phase 4 |

### Phase 3: Staged content

| | |
|---|---|
| Depends on | phase 1; lands before phase 6 so new weapons enter a pool that exists |
| Touches | `src/account.w` (`tier(s: &Save) -> i32` from the conditions of §4; `weapon_condition` and `passive_condition` consult the tier; `Launch` gains `fresh_weapons: [bool; 20]`, unlocked within the last two runs and not yet picked), `src/game.w` (`offer_weight` multiplies a fresh weapon's weight by `rules.fresh_weight`), `src/tuning.w` (`fresh_weight: f64 = 4.0`), `src/save.w` (first-pick timestamps per weapon) |
| New | `test/staging_contracts.w`: a fresh save sees seven weapons and eight passives; tier 2 opens on a first boss kill; a fresh weapon is offered within two card screens at the default weight and the draw stays seeded |
| Exit | `runs exposure` ≤ 2 runs for every tier-1 and tier-2 weapon on the bot account |

### Phase 4: Pressure and power

| | |
|---|---|
| Depends on | phases 1 and 2 (Hurry's cadence is tuned here too) |
| Touches | `src/game.w` (`base_hp` steeper and earlier; cores and credits per kill scale with `max_hp`; `ENEMY_CAP` lower), `src/tuning.w` (`spawn_rate` flatter; `minimum_alive`), `src/account.w` (rank prices: +35% per rank for the first five, +60% after; the Hull, Armor and Reboot ranks first in the list), `src/balance.w` and `src/odds.w` (their bands re-derived) |
| New | `test/pressure_contracts.w`: a Block's HP at 1:30, 3:00, 5:00; XP per minute within 10% of the control at minutes 5, 10, 15 despite fewer kills; the weapon kill-rate bands in `test/weapon_bands.w` re-pinned |
| Exit | `runs profile` with the careful bot at ranks 0, 3 and 6 reaches 5:00, 10:00 and 15:00 medians; your own `runs.tsv` over the next sessions tracks §3's survival targets; the stress harness's frame time at the new cap is at or under today's |

### Phase 5: Proximity Mine

| | |
|---|---|
| Depends on | phase 3 (it is a tier-1 weapon) |
| Touches | `src/game.w` (the mine spawner at the ship's position on a cooldown; the skip rule within 1.5 × trigger radius of a live mine; `cap = base + min(count_bonus, 4)`, oldest expires; the existing contact detonation stays), `src/loadout.w` (`weapon_stats` for `.Mines`: cooldown from `FireRate` and `Cooldown`, radius from `Area`, `count` unused; the card text "+1 armed mine" for Count; Minefield and Grid unchanged), `src/presentation.w` (a mine's trigger ring) |
| New | `test/mine_contracts.w`: one mine per 3 s at the ship; none while within 1.5 × radius; `Count` raises the cap and never the rate; radius follows `Area`; the oldest expires at the cap; a replay with mines is exact |
| Exit | the Sapper's `runs profile` row at or above today's; stress frame time at cap 8 |

### Phase 6: Weapons

| | |
|---|---|
| Depends on | phases 3 and 5 (the pool and the mine's stat conventions) |
| Order | Tether, Gravity Well, Drone, Lob; then Flak, Turret, Sweep, Tesla Field, Boomerang, Shockwave, Satellite, Repulsor |
| Touches | `src/loadout.w` (`Weapon` grows to 20 base + 20 evolved + 6 unions, `WEAPON_COUNT`, `recipes()` from the matrix's key table, `family`, `name`, `describe`, `weapon_stats`), `src/game.w` (one `fire_*` per weapon; `displacement_resistance(kind)` with the first pusher or puller; the Tether's chain in the fixed step; the Drone's "nearest outside the aim cone"), `src/presentation.w` (one draw per weapon), `src/gallery.w` (a frame per weapon), `src/ships.w` (`base_weapon` for the specialists lands in phase 7) |
| New | `test/weapon_contracts.w` grows per weapon: Tether's sweep width grows with committed turn rate and not with stick wiggle; Gravity Well pulls a Dart farther than a Block and a boss not at all; the Drone never targets inside the aim cone while an enemy is outside it; Lob's minimum range; Shockwave's mark. `test/weapon_bands.w` gets a band per weapon |
| Exit | each weapon's row in the matrix filled from play (role and the three columns confirmed, not asserted); the aim-identity count stays at 14 of 20; a bot run and a gallery frame per weapon |

### Phase 7: Ships and derelicts

| | |
|---|---|
| Depends on | phase 6 (the specialists start with the new weapons) |
| Touches | `src/ships.w` (`Ship` to 26; conditions from the matrix; `base_weapon`, quirks), `src/account.w` (derelict and black-box conditions; a black box reveals a condition in the Collection), `src/game.w` (derelicts: a placed wreck, its escort, the five verbs as timeline events; `Formation` for the chase and the carrier), `src/save.w` (derelicts found, black boxes recovered), `src/app.w` and `src/presentation.w` (ship select at 26, the Collection's revealed conditions, the wreck and its objective on screen) |
| New | `test/derelict_contracts.w`: each verb completes under the bot on its stage and fails cleanly when abandoned; a black box reveals and does not unlock; `test/ships.w` (every ship's condition is reachable: the bot account meets each within its matrix hour) |
| Exit | `first_ship_unlock` on run 1 (Dart) and three ships inside 90 minutes on the bot account; no derelict verb used more than three times |

### Phase 8: Stages and modes

| | |
|---|---|
| Depends on | phases 2 (Hurry gates the challenges) and 7 (derelicts are placed per stage) |
| Touches | `src/game.w` and `src/tuning.w` (`Stage` to 15; layouts for Blackout, Boss Rush, Bone Field, Collapse, Rotor, Mirror; `Rules` per stage: `timeline_rate`, HP ramp, the shrinking arena, rotating sectors, the light cone), `src/account.w` (stage conditions; Endless gated on the Null), `src/presentation.w` (the cone, the sectors, the collapse) |
| New | `test/maps.w` grows a case per stage: the one variable it changes is asserted (Bone Field's HP at minute 10 is 4×; Collapse's arena at 10:00 is half; Rotor's safe sector rotates once a minute) and a bot run on each replays exactly |
| Exit | every stage has its variable, its derelict verb and its hour in the matrix confirmed from play; the bot account opens three stages inside two hours |

### Stops

The plan has two natural playtest stops: after phase 4, when hour one has
changed, and after phase 6, when the arsenal has. Nothing is left
half-landed at either.
