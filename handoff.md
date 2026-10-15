# Handoff — WIPE: SURVIVAL

Written 2026-10-15 for the next agent. Everything below is pushed to `main`
at `20d73c0` unless it says otherwise. The suite is green: 38 test files,
about 200 s (the limit is 240 s).

## Standing rules from Eric

- Commit and push straight to `main`. No branches or PRs unless asked.
- Build with the installed `~/.local/bin/with`, unpinned. When the compiler
  changes and WIPE breaks, fix WIPE to the new rules. Real compiler bugs are
  filed as issues in `withlang-dev/with`. At a release, tag both repos.
- In With code, let types be inferred; annotate only where the compiler
  requires it (a typed `let x: i32 = g.field` is the way to copy out of a
  view, see below).
- Don't hedge about causes. No "likely" or "probably": probe, bench or test
  it and report the number, or say it is unmeasured and name the measurement.
- Test every step before the next one. The full suite stays under 4 minutes.
- Plans are todo lists. No estimates, days or sizes.
- Players discover synergies; the repo must not list them. The bench tools
  are committed; their tables, pair measurements and synergy findings are
  not. Keep them in your scratchpad or in chat.
- Two sticks, no cursor. A mouse gives direction only, never a location.

## How to work here

| Command | What it does |
|---|---|
| `with build` | the game only (`out/bin/wipe`) |
| `with build :test` | the whole suite; run it alone, builds collide |
| `with test test/x.w` | one test file |
| `with build :bosses :balance :runs :gallery :playtest` | the tools; each is built by name, `with build` alone leaves them stale |
| `./out/bin/bosses 2 [SHIP] [BOSS]` | ship against the bosses it meets; a boss index forces it into its pool's slot |
| `./out/bin/bosses matrix 2` | every ship forced into every boss, two seeds (~15 min) |
| `./out/bin/bosses probe SHIP [BOSS [SEED]]` | a line a second through each boss fight: distance, bearing, damage a second, hull, build |
| `./out/bin/balance bosses 2` | every base weapon held 120 and 280 px from every boss, damage a second |
| `./out/bin/balance five 14 260` | every base weapon at V on one bench |
| `./out/bin/balance pairs 14 260`, `scaling`, `ships`, `pair A B` | the synergy bench (output stays out of the repo) |
| `./out/bin/runs profile 4 0 [SHIP]` | the ship's survival past 2/5/10/15/20 min with the careful bot; `WIPE_PASSIVE=Name:level` presets a passive |
| `./out/bin/playtest SHIP [BOSS] [SEED]` | renders a bot-flown boss fight on screen, frames to `out/playtest/` |
| `./out/bin/gallery` | every element staged and saved to `out/gallery/` (needs a display) |

The tour needs `WIPE_SAVE_DIR` set to a scratch directory and an existing
`out/tour/`. Long tools go in the background; don't start a build while
another build is running.

### With quirks that cost time

- No safe `&mut`. Mutating receivers are `mut self: Self`.
- View liveness (D22/D27): a `let e = self.enemies[i]` is a view; any later
  mutation of `self` while `e` is still used is an error. Copy what you need
  first (`let kind: Kind = e.kind`), or write the copy back and re-read it
  (the boss step functions do `self.enemies[e] = enemy`, call, then
  `enemy = self.enemies[e]`).
- A local can't shadow a receiver field (`elapsed`, `field`, `down` have
  bitten) or an earlier local in the same scope.
- `let ... else` needs a diverging else; use `if let` when it doesn't.
- `parse` needs `use std.string.parse`; `args` needs `use std.process.{args}`.
- Nested mutating calls on one place are refused; bind the inner result first.
- `isize` from `List.len()` doesn't narrow implicitly; type the list.

## Where the game is

Twenty-six ships, twenty base weapons, twenty evolutions and six unions,
eighteen passives (the Shield is the newest), fifteen stages, six bosses,
Tanks, derelicts, four save slots, Steam Input. The design documents are
`docs/progression-plan.md`, `docs/progression-matrix.md` and
`docs/boss-plan.md`. `docs/verification/progression-control.md` is the
running record of every measurement, appended after each pass: read its
last six entries before tuning anything.

### What the last two days changed (newest first)

- **Lancer and Bulwark hulls** resized to 3500 base after the pierce fix,
  measured with the Claw at 10:00 as the yardstick.
- **A bullet strikes a boss once.** `BOSS_HIT_SHARE` (a quarter of the hit
  cooldown) applies only to overlapping strikes, passed as `overlap: true`
  to `damage_enemy`: fields, blades, rings, beams, lightning, blasts. A
  piercing bolt was re-hitting a boss every few ticks before; that was the
  Needle's four-second kills.
- **Crossing strikes scale with the hull** (`cross_share`: a boss ×4, a
  Tank ×1.5) for rings, beams, lightning and blasts, never together with the
  hit share.
- **A boss draws fire** (`BOSS_LURE`), like a Tank and a marked enemy.
- **The Shield** passive: takes one hit whole, back in 12 s, 1.5 s sooner a
  rank, never the Null's.
- **A human-paced bot.** `human()` in `src/pilots.w` decides every tenth of a
  second and holds the input between; every bot-flown measure goes through
  it. Before this the bot re-decided every 8 ms and everything was tuned
  against reflexes no player has. The 0.1 s is a judgment, not a
  measurement; Eric's own sessions through `runs account` would pin it.
- **Desperation** (75 s, the Warden 150 s, Boss Rush 50 s) changes each
  boss's behavior, ramps its touch and shots by half a minute to ×3, and
  brings the swarm back, so no fight stalls.
- **The six bosses**, the jackpot reward ladder, the pools (Warden fixed at
  5:00, a mid draw at 10:00, a late draw at 15:00, the Null at 20:00),
  Boss Rush and Endless rotation. See `docs/boss-plan.md` §6.
- **The balancing campaign**: weapon and passive scaling fixed, synergy
  hooks, the number pass, the Tether as a flail on the aim stick, Tanks.

### The boss matrix now (kills / deaths / reached, 2 seeds a ship)

```text
Warden 34/4/38   Lancer 9/2/11   Hive 8/1/9   Lattice 10/1/11   Keeper 8/1/9   Bulwark 10/1/11
```

The full grid is the last entry of the control document.

## Current activity: push on the remaining boss deaths

Eric asked to push on the ten deaths left in the matrix. Nothing has been
done on it yet. The deaths, with the seconds into the fight:

```text
Claw    Hive     88 s        Sentry  Lancer   92 s
Claw    Keeper   79 s        Sentry  Lattice  88 s
Lasher  Warden   80 s        Sentry  Bulwark  88 s
Hawk    Lancer   17 s        Coil    Warden   17 s
Brace   Warden  133 s        Orbital Warden  102 s
```

How to go at it:

1. The two 17-second deaths (Hawk on the Lancer, Coil on the Warden) are the
   outliers: a boss fight should never end in 17 s by the player's death.
   Probe both first (`bosses probe Hawk 1 SEED`, `bosses probe Coil 0 SEED`;
   the matrix uses seeds 0 and 1) and find what lands the hull: a spawn
   point, a charge with no tell the bot can see, or the swarm.
2. The Sentry dies to three different bosses at about 90 s each. Ninety
   seconds is past the 75-second desperation mark, so read its probe for
   what happens after desperation (the swarm's return, the ramp).
3. The Warden's slow starters (Brace 133 s, Orbital 102 s, Lasher 80 s)
   are builds that hurt the Warden slowly; their deaths come late in the
   fight. Probe them for the damage a second they reach and where the hull
   goes.
4. For each finding, decide whether it is the boss, the ship or the bot.
   A bot fault (it can't see a tell, it walks into a charge) is fixed in
   `careful()` in `src/pilots.w` and is not a reason to soften a boss.
5. After any change: the boss bands (`test/boss_bands.w`,
   `boss_bands_a.w`, `boss_bands_b.w`), the ship profiles
   (`test/targets.w`), the full suite, then `bosses matrix 2` and a new
   entry at the end of the control document with the before/after.

The matrix CSVs from the last runs were in the old session's scratchpad and
are gone; regenerate with `bosses matrix 2`.

## Upcoming plans, in order

1. The remaining boss deaths, above.
2. Tighten the roster boss bands. `boss_bands_a.w`/`_b.w` hold every ship to
   "ends within eight minutes, no 30 s wait, no 0.6 idle share": the floor
   the balance pass found. Tighten them as the deaths come down.
3. Calibrate the bot against Eric. His recordings land in the save's `runs`
   directory; `runs account` and `runs exposure` read them. The control
   document's human baseline is still a smoke test. Ask him for a few real
   sessions; then set `REACTION_STEPS` in `src/pilots.w` from them.
4. The ship profile only guards the nine original ships (`targets.w`); the
   seventeen newer ships have no profile table. Volt, Glass, Ghost and the
   Mortar are weak at rank zero in `runs profile`.
5. The suite is at about 200 s of 240. The time is in the count of compile
   units, not in any one test (the heaviest are `targets` 34 s and
   `weapon_bands` 28 s). If it needs room, fold the small contract files
   together.
6. Not urgent, recorded: the Bulwark is the one late boss with real teeth by
   design; the Needle kills bosses in 24–50 s, its "late killer" identity.

## Loose ends

- `docs/gameplay.mp4` is untracked; it is Eric's, leave it.
- `/Users/eric/with/docs/plans/game-toolkit.md` (the With game-toolkit plan)
  is uncommitted in the With repo; Eric never asked for it to be committed.
- Memory for this project lives in
  `~/.claude/projects/-Users-eric-wipe/memory/`.
