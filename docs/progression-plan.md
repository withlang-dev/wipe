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

## 11. Order of work

1. **Telemetry** (§3): the score, the streak, time-to-first, exposure; the
   control group captured.
2. **Stage gates, Hurry, three-thread goals** (§8): `next_unlock()` grows
   to near / new / stretch on the results and Collection screens.
3. **Content staging** (§4): tiers as conditions, the draft reads the pool,
   the fresh-unlock weight.
4. **Pressure and power** (§9): the HP/density swap, XP per HP, the rank
   price curve; tuned against §3's targets with the bot and human runs.
5. **Proximity Mine** (§5.2).
6. **Weapons** (§5.3): Tether, Gravity Well, Drone, Lob, then the rest, each
   through the review columns; displacement resistance with the first
   pusher or puller.
7. **Ships and derelicts** (§7).
8. **Stages and modes** (§8).

Each step lands with its tests and its `runs` numbers, on `main`.
