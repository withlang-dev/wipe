# WIPE: SURVIVAL — Boss Plan

Decided 2026-10-14. The run has three bosses at 5, 10 and 15 and the Null at
20, each a large enemy with one damage gate. That skeleton stays — the clock,
the Null, the one-rule-each principle — and the vocabulary grows: six bosses,
each a different test, drawn into the run's fixed slots, each worth a
jackpot, each measured by the bot before it ships. This grows what a boss
can be, not how often one arrives.

Everything here is a todo list in order. No estimates.

## 1. Principles

1. **Each boss is a verb, and the verbs do not repeat.** A boss tests one
   skill the swarm does not. Six verbs, six bosses: Position, Time,
   Prioritize, Dodge, Hold, Sustain.
2. **Two gates, scaled apart.** Every boss has a dodge gate (survive its
   pattern) and a DPS gate (kill it before desperation). Health scales with
   the run's minute and difficulty, as now. Pattern density is a property
   of the stage or mode tier the player can see (the Field's Warden is the
   Warden; Boss Rush and the late stages carry the dense pattern). Pattern
   difficulty never scales with account ranks: bought power must not make
   bosses harder to dodge.
3. **Desperation, not a damage ramp.** At the enrage mark the boss changes
   behavior, visibly: cadence up, gaps narrower, recovery windows fewer, a
   new tell. Failure reads as "it entered desperation and I was too slow."
4. **A boss is a jackpot.** The kill decides a reward rung at the kill, and
   the banner names it. Killing a boss never feels like nothing.
5. **Build interaction by geometry, never by multiplier.** No weapon family
   gets a damage scale against a boss. Each boss's shape and reach make
   different families feel different: the pattern boss keeps its distance
   and strafes (range and area matter, a Tether chases), the field boss sits
   in its own zone (short-range weapons are in it naturally), the wall is a
   large slow hull (only sustained single-target damage reads).
6. **Hold is where; Dodge is when.** A Hold boss constrains where the player
   may be — in the right place nothing hits you. A Dodge boss constrains
   nothing about where and everything about timing — free movement,
   threaded projectiles. They must not blur.
7. **Measured before shipped.** A boss bench flies every ship into every
   boss at rank zero and records time to kill, hull lost, and time unable
   to damage. Bands fail the build.

## 2. The six

| Verb | Boss | Slot | The rule | Desperation |
|---|---|---|---|---|
| Position | **Warden** (have) | 5:00 fixed | its back is the weak point; it turns to face you | stops turning: charges in straight lines, back exposed only on the turnaround |
| Time | **Lancer** (have) | mid pool | soft only in its open state after a lunge | lunges twice as often, the open window half as long |
| Prioritize | **Hive** (have) | late pool | near-immune while drones live | drones respawn in waves; the core moves |
| Dodge | **Lattice** (new) | mid pool | a pattern boss: spirals and walls, telegraphed, with gaps; always soft, always at range | gaps narrower, rings faster, two patterns at once |
| Hold | **Keeper** (new) | late pool | a field boss: its zone is the attack — a safe sector that turns, then moves; the boss sits at the middle | the sector shrinks and reverses now and then |
| Sustain | **Bulwark** (new) | mid and late pools | the wall: a large slow hull, no trick, an honest DPS check against the enrage | speed doubles and it rams; hull plates shed, each a Tank |

Pools: 5:00 Warden, fixed (the tutorial boss). 10:00 drawn from the mid pool
{Lancer, Lattice, Bulwark}. 15:00 drawn from the late pool {Hive, Keeper,
Bulwark}. 20:00 the Null, fixed. The Bulwark sits in both pools at two
tunings because the Sustain verb scales cleanly with health and reads the
build most directly; it should not be rare. The draw is from the run's RNG,
so replays stay exact. A run never draws the same boss twice.

Existing bosses keep their rules and gain only desperation and the reward
rung. The Hive is expected to fail the time-unable-to-damage band as it
stands (×0.08 while drones live); its fix is the drones' reach, not the
multiplier.

### Lattice (Dodge)

- Keeps 300–420 px from the ship, strafing; never charges.
- Patterns, each telegraphed a second ahead by a thin tracing of its shape:
  a spiral of slow shots with a gap that rotates; a wall of shots with one
  opening that drifts; a ring that expands then contracts.
- Always soft (×1.0). The whole difficulty is the pattern. Its health is
  the lowest of the six.
- Build geometry: range and area shine; a close-range build must thread the
  pattern to reach it.
- Desperation at 75 s: two patterns at once, gaps a third narrower, rings
  a third faster.

### Keeper (Hold)

- Sits still at the arena's middle (the Hold stage's Rotor, as a boss). A
  safe sector of 110° turns once a minute; outside it the field bites every
  half second, as the Rotor does.
- Soft from inside the sector only (×1.0), ×0.25 from outside — you are
  meant to be in the sector anyway.
- Every 20 s the sector jumps a quarter turn with a two-second tell.
- Build geometry: the boss is at the middle of its own zone; short-range and
  orbiting weapons reach it from inside the sector; a long beam reaches it
  from anywhere but only counts from inside.
- Desperation at 75 s: the sector narrows to 70° and reverses direction each
  jump.

### Bulwark (Sustain)

- A large slow hull, the highest health of the six at its late tuning. No
  weak point, no immunity: ×1.0 everywhere.
- Walks at the ship, slowly; contact is heavy. Sheds a hull plate at each
  quarter of its health — the plate is a Tank.
- Build geometry: the only thing it reads is sustained single-target damage;
  a build of area weapons learns it has none.
- Desperation at 75 s: speed doubles and it rams in straight lines, with a
  tell; plates shed twice as often.

## 3. Rewards

Decided at the kill, named on the banner, and worth more than the elites' cache:

| Rung | When | What |
|---|---|---|
| **MERGE READY** | any recipe is ready (a weapon at V and its key held) | the merge offer, guaranteed, as the boost card |
| **CACHE** | no merge ready | a cache of three cards drawn from owned upgrades and missing recipe pieces (the key passive of any weapon at V, the weapon of any held key) |
| **BOUNTY** | the build is full and nothing is missing | credits (the current bonus, doubled) and a run buff: five seconds of invulnerability (the game's cap) and the next level's cards at five choices |

The full repair and the first-kill account bonus stay. The Null's reward is
unchanged (the clear).

## 4. The bench

`bosses` grows from a smoke tool to the measure. For every ship at rank zero
and every boss at its slot's minute, the careful bot with its own build at
that minute (the profile's build), four seeds:

- **time to kill**, seconds, and whether desperation was reached
- **hull lost**, in health, and whether the bot died
- **time unable to damage**: ticks while the boss is alive, outside an
  explicit mechanic (the Hive's drones, the Keeper's jump tell), in which
  the bot dealt no damage to the boss — as a longest streak and as a share

Bands, failing the build (`test/boss_bands.w`):

- no boss is unkillable before desperation by every ship; no boss dies in
  under 15 s to any ship
- hull lost under half for the median ship on the tutorial boss
- the longest no-damage streak under 8 s and the share under a fifth,
  outside explicit mechanics, for every boss and the median ship

The bench is a tool in the repository; its numbers are not.

## 5. Order

1. **Reward ladder.** `kill_enemy`'s boss arm decides the rung
   (`loadout.w` has `ready_merges`; the cache draw grows a "missing pieces"
   pool); the banner names it (`BannerKind.Bounty(rung)`); `open_cache`
   takes a card source. Tests: a ready merge is offered on the kill and
   nothing else; no merge gives three cards of the right kinds; a full build
   gives the bounty; replays exact.
2. **Bench metrics.** `src/bosses.w` flies ship × boss and prints the three
   metrics; `test/boss_bands.w` bands them for the three existing bosses.
   The Hive's result decides its drone reach.
3. **Lattice.** `Enemy.boss = 3`: strafing movement, three telegraphed
   patterns, hostile shots with gaps, desperation. Drawn into the mid pool.
   Bench, band, gallery frame, a contract test for the gap (a still ship in
   the gap takes nothing).
4. **Keeper.** `boss = 4`: the sector, the bite, the jump and its tell, the
   soft-from-inside rule, desperation. Late pool. Bench, band, frame, a
   contract test for the sector (inside: no bite, full damage; outside: bite,
   quarter damage).
5. **Bulwark.** `boss = 5`: the hull, the walk, plates as Tanks at each
   quarter, desperation's ram with a tell. Both pools at two tunings. Bench,
   band, frame, a contract test for the plates.
6. **Rotation.** The draw at 10:00 and 15:00 from the run's RNG, never the
   same boss twice; Boss Rush becomes all six in verb order, desperation at
   50 s; Endless draws from all six and, from the second cycle, two at once
   (a mid and a late). `boss_rush` and `stages` contracts updated; the
   control document records the bench per ship.

## 6. Touches

| Area | Files |
|---|---|
| Rules and pools | `src/tuning.w` (`boss_minutes`, pools, Boss Rush order), `src/game.w` (`spawn_boss` draw) |
| Boss behavior | `src/game.w` (the `.Boss` arm of the enemy step; `boss_damage_scale`; desperation timers on `Enemy`) |
| Reward | `src/game.w` (`kill_enemy` boss arm, `open_cache`), `src/loadout.w` (missing-pieces pool), `src/app.w` / `src/presentation.w` (banner) |
| Bench | `src/bosses.w`, `test/boss_bands.w`, `docs/verification/progression-control.md` |
| Drawing | `src/presentation.w` (three new bosses, telegraphs, the sector, the plates), `src/gallery.w` (frames) |
| Tests | `test/boss_rewards.w`, `test/boss_bands.w`, per-boss contracts, `test/stages_contracts.w` (Boss Rush) |
