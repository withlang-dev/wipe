# WIPE: SURVIVAL — Recruiting Prototype Spec

## 1. Purpose

This prototype exists for one reason:

> Show prospective development partners that WIPE: SURVIVAL is real, playable, technically viable in With, and worth building together.

It is **not** the commercial MVP.

It should be small enough to build quickly and polished enough that a 20–40 second gameplay clip makes sense without explanation.

The prototype should demonstrate:

* responsive movement
* responsive aiming
* satisfying shooting
* readable enemy pressure
* stable performance with many entities
* fast death/restart
* enough visual and audio feedback to feel deliberate rather than like an engine test
* that the game is actually running in With

Everything else is out of scope.

---

# 2. Success Criteria

The prototype is successful when:

1. A player can launch directly into gameplay.
2. Movement and aiming feel immediately responsive.
3. Enemies continuously pressure the player.
4. Shooting enemies feels satisfying.
5. The player can die and restart almost instantly.
6. The game can show a substantial number of active enemies, bullets, and particles without obvious frame-time problems.
7. A short recorded clip looks like a recognizable arcade survival game rather than a programming prototype.
8. A prospective partner can play it and immediately start discussing how to improve it.

Target first impression:

> “Okay, this already works — and it has some punch.”

---

# 3. Target Platform

Primary target:

* Desktop development build
* Steam Deck-compatible controls and performance assumptions
* mandatory Xbox controller and Steam Controller support (Steam Input mappings are acceptable; Steamworks integration is not required)

Preferred demonstration:

* running directly on Steam Deck if convenient

Do not block the prototype on:

* Steam integration
* Steam packaging
* achievements
* store setup
* controller certification

---

# 4. Core Loop

The entire prototype loop is:

1. Player spawns in center of arena.
2. Enemies spawn continuously from outside the screen.
3. Player moves with left stick / WASD.
4. Player aims with right stick / mouse.
5. Player automatically fires toward aim direction.
6. Bullets damage and kill enemies.
7. Enemy density increases over time.
8. Contact with an enemy damages the player.
9. Player eventually dies.
10. Death screen appears immediately.
11. Player presses one button to restart.
12. New run begins almost instantly.

No progression between runs.

---

# 5. Player

## Movement

Requirements:

* top-down movement
* mandatory independent dual-stick movement and aiming
* full analog stick support on Xbox controllers
* Steam Controller support through Steam Input: left stick moves; right trackpad supplies the independent aim action (right-stick emulation or mouse mapping)
* keyboard fallback
* normalized diagonal movement
* responsive acceleration
* little or no noticeable input lag

Suggested controls:

```text
Left Stick / WASD = move
Right Stick / Mouse = aim
A / Space = restart after death
Esc = quit
```

The player should be able to move in any direction independently of aim direction.

No dash in this prototype.

---

# 6. Aiming

Requirements:

* right stick controls aim direction independently from movement; this is mandatory
* Xbox controller and Steam Controller/Steam Input mappings must both be validated
* mouse controls aim direction on desktop
* aiming should feel stable at low stick magnitude
* configurable deadzone if needed
* aim direction should be visually obvious

Possible visual:

* weapon/barrel points toward aim direction
* simple aim line or reticle during development

No aim assist required.

---

# 7. Shooting

The player fires automatically whenever alive.

Base weapon:

```text
fire rate: approximately 5–8 shots/sec
projectiles: 1
spread: none or minimal
projectile speed: fast
damage: kills the base enemy in exactly 1 hit (current prototype rule)
```

Exact numbers are tuning values, not architecture.

Requirements:

* bullet direction exactly follows aim
* bullets have a visible trail
* bullets disappear on hit or when leaving the arena
* firing should remain stable under high entity count

No reload system.

No ammo.

No weapon switching.

---

# 8. Arena

Use one fixed rectangular arena.

Requirements:

* single screen or slightly larger than screen
* visually clear boundary
* no environmental obstacles
* player begins near center
* enemies spawn just outside visible area or along arena edges

Placeholder visual design is acceptable, but it should look intentional.

Suggested style:

> dark arena, bright high-contrast entities, strong emissive-looking bullets, simple geometric effects

The visual reference is Geometry Wars: luminous wireframe geometry, a dense electric-blue grid, white-hot projectile cores with long gold trails, saturated green/cyan/magenta light, and energetic radial spark bursts.

Professional shader and effect work is required: a smoothly deforming grid that reacts to nearby motion/impacts, controlled bloom with sharp gameplay silhouettes, layered glow, and strong, directional death effects. Capture and inspect real gameplay frames against these references. Do not treat flat colored outlines on a static grid as the finished aesthetic. Keep effects readable under stress and measure the full rendering pipeline.

---

# 9. Enemy

Implement exactly one enemy type.

## Chaser

Behavior:

* spawns near arena edge
* moves directly toward player
* slightly slower than player
* damages player on contact
* dies from one bullet hit in the current prototype (health = 1)

Suggested properties:

```text
health
move_speed
contact_damage
position
```

Enemies do not need:

* pathfinding
* animation state machines
* sophisticated collision avoidance
* attacks
* status effects

Small overlap between enemies is acceptable.

Basic separation is optional if trivial.

---

# 10. Spawning

Enemies spawn continuously.

The prototype should create visible escalation.

Example:

```text
0–15 sec:
    low spawn rate

15–30 sec:
    medium spawn rate

30–60 sec:
    aggressive spawn rate

60+ sec:
    continue increasing until entity budget is reached
```

Exact curve is not important.

The desired experience is:

> calm start → crowd forms → screen becomes increasingly dangerous

Hard-cap enemies to protect frame time.

Suggested target:

* ordinary gameplay: 50–150 enemies
* stress test/debug command: 300+ enemies if practical

---

# 11. Health and Death

Player has simple health.

Example:

```text
max_health = 3
enemy collision = 1 damage
short damage invulnerability = 0.5 sec
```

Requirements:

* obvious hit feedback
* obvious death
* no lengthy death animation
* death screen appears immediately

Death screen needs only:

```text
YOU DIED

Time: 01:23
Kills: 184

[A] RETRY
```

Optional:

* best survival time for current process
* best kill count for current process

Do not persist anything to disk.

---

# 12. Restart

Restart speed is a major prototype requirement.

Target:

> button press → active gameplay in under 1 second

Preferably much faster.

Restart should reset:

* player
* enemies
* bullets
* particles
* elapsed time
* kill counter
* health

It should not require:

* returning to main menu
* reloading the executable
* reinitializing expensive global systems unnecessarily

---

# 13. Collision

Required collision pairs:

```text
bullet ↔ enemy
enemy ↔ player
```

Nothing else is required.

No enemy-enemy collision is necessary unless easy.

Collision system should be suitable for hundreds of entities.

Do not spend prototype time designing a generalized physics engine.

---

# 14. Showcase Juice

The prototype should have enough visual feedback that a short clip feels like a game, not a collision demo.

This is required scope.

## 14.1 Bullet Presentation

Each shot should have:

* bright projectile core
* short trail
* brief muzzle flash
* subtle firing impulse on the weapon/player sprite if easy

The player should look visibly active even before enemies are hit.

## 14.2 Enemy Hit

On hit:

* 30–60ms bright flash
* tiny scale punch or squash
* 2–6 impact particles
* optional tiny directional knockback

The effect should remain readable when many enemies are on screen.

## 14.3 Enemy Death

Enemy death is the primary visual reward.

Required:

* 8–20 burst particles
* brief expanding ring or shock pulse
* enemy sprite rapidly scales/fades out
* kill sound
* optional tiny camera shake for nearby kills

Particles should inherit some of the impact direction rather than exploding uniformly.

## 14.4 Multi-Kill Energy

Repeated kills in a short period should make the game visually escalate without implementing a combo system.

Possible effects:

* slightly larger kill bursts after rapid consecutive kills
* slightly stronger screen shake
* brighter bullet impact
* short-lived additive glow particles

This does not need gameplay state or scoring.

It is presentation only.

## 14.5 Player Damage

When the player is hit:

* strong flash
* short camera impulse
* brief screen-edge flash or vignette
* 50–100ms hit-stop only if it feels good
* short invulnerability flicker afterward

The hit should feel serious.

## 14.6 Player Death

Death should be the largest effect in the prototype.

Required:

* larger particle burst
* radial shockwave
* stronger but brief camera shake
* short screen flash
* ~100–200ms freeze/hit-stop
* rapid transition to death overlay

The whole sequence should remain under roughly half a second.

## 14.7 Spawn Effect

Enemies should not simply appear.

Use something cheap such as:

* quick scale-in
* brief glow
* small inward particle burst
* faint spawn ring

Duration:

* approximately 100–200ms

Do not make spawn effects visually louder than enemy deaths.

## 14.8 Screen Shake

Implement one simple trauma/impulse-based camera shake system.

Use it for:

* player damage
* enemy death, very lightly
* player death, strongly

Requirements:

* short decay
* capped magnitude
* never interfere with aiming/readability

## 14.9 Hit Stop

Optional but recommended.

Use extremely short pauses:

```text
normal enemy kill: 0–20ms
player hit: 30–60ms
player death: 100–150ms
```

Do not freeze input longer than necessary.

If hit-stop makes the game feel sluggish, remove it.

---

# 15. Particle System

A small reusable particle system is required.

It should support:

```text
position
velocity
lifetime
size
rotation
alpha
optional acceleration/drag
```

Nice to have:

```text
start_size
end_size
```

Avoid building a generalized node-based particle editor.

The prototype only needs a few hard-coded emitters:

* bullet trail
* bullet impact
* enemy death
* player hit
* player death
* spawn effect

Target several hundred active particles without a noticeable hitch.

Particles should be pooled or otherwise avoid pathological per-frame allocation.

---

# 16. Visual Hierarchy

At all times, the player should immediately distinguish:

1. player
2. enemy
3. dangerous contact
4. player bullets
5. decorative particles

Particles must never obscure enemy silhouettes or the player.

A useful rule:

> gameplay shapes stay solid and readable; effects are transient.

---

# 17. Audio

Audio is a core part of the game's identity and a required part of the recruiting prototype's polish.

## 17.1 Sound Direction

The overall experience should be **meditative and engaging**: focused, flowing, and immersive, with satisfying physical impact rather than harsh, fatiguing noise.

Requirements:

* professional-sounding effects and music; obvious placeholder bleeps are not the acceptance target
* good, controlled bass weight in the music, weapon, impacts, and death effects
* a cohesive sound palette that complements the luminous geometric aesthetic
* clear feedback even during dense combat
* a comfortable balance for sustained listening, with no clipping or uncontrolled low-frequency buildup
* important cues remain audible on Steam Deck speakers and ordinary headphones; sub-bass must not be the sole carrier of information

## 17.2 Effects

Required cues:

* shot
* enemy hit
* enemy death
* player hit
* player death

Shots should feel precise and rhythmic, enemy deaths rewarding, and player damage serious. Player death should have the strongest sonic payoff. Use subtle variation in pitch, timbre, or layering to prevent repetition, and cap or coalesce overlapping voices so dense combat remains controlled.

The effects should have bass body and crisp definition without masking the music or drowning out one another. Preserve dynamic headroom; louder is not a substitute for impact.

## 17.3 Music

A professionally presented **ambient-house background** is required, replacing the earlier optional ambient/music loop.

The music should provide:

* a steady, restrained house pulse
* warm, substantial bass
* spacious ambient textures and gentle harmonic movement
* an engaging, meditative flow that supports concentration
* seamless looping without clicks, abrupt restarts, or obvious gaps

Keep the background present but subordinate to gameplay cues. Avoid an aggressive festival/EDM arrangement, intrusive vocals, or relentless high-frequency percussion. Music should continue smoothly through death and retry; restarting gameplay must not reinitialize the audio device or unnecessarily restart the musical phrase.

## 17.4 Assets and Acceptance

Original, generated, commissioned, or appropriately licensed audio is acceptable, but the quality bar applies regardless of source. Record provenance and licensing for any outside material. Discuss dependencies beyond raylib before adding them.

Validate the mix during ordinary gameplay, crowded combat, player damage/death, and repeated retries. Verify audible output and smooth looping on desktop/headphones and validate the target controller/platform setup on Xbox controllers and Steam Controller/Steam Input. A subjective listening review is required in addition to technical checks; successful playback alone does not establish professional quality.

---

# 18. UI

In-run UI:

```text
Time
Kills
Health
FPS / entity count (debug only)
```

No menus.

No settings screen.

No upgrade UI.

No inventory.

No progression UI.

---

# 19. Debug Overlay

Include a toggleable debug overlay.

Display:

```text
FPS
frame time
enemy count
bullet count
particle count
total active entities
elapsed run time
```

Optional:

* spawn rate
* memory usage
* update time
* render time

This serves two purposes:

1. development
2. demonstrating With's real-time performance

---

# 20. Performance Goal

Target hardware philosophy:

> If this simple prototype cannot remain smooth with a few hundred lightweight entities and particles, solve that before building the full game.

Target:

* stable 60 FPS on intended development hardware
* stable frame pacing
* no obvious allocation hitch every frame
* 150+ enemies plus bullets and particles under ordinary stress
* preferably demonstrate 300+ simple active entities in a stress mode

Do not sacrifice responsiveness merely to maximize entity count.

---

# 21. Architecture

Keep prototype architecture deliberately small.

Suggested systems:

```text
Game
Player
EnemyPool
BulletPool
ParticlePool
Spawner
Collision
Renderer
Input
Audio
CameraEffects
DebugStats
```

Prefer simple data-oriented storage where useful.

Avoid:

* ECS framework work unless one already exists
* plugin architecture
* scripting system
* generic gameplay framework
* editor
* serialization system
* asset pipeline redesign
* generalized VFX editor

Build only infrastructure needed for this prototype.

---

# 22. Asset Policy

Prototype assets may be:

* programmer art
* simple generated sprites
* AI-generated or AI-assisted
* public-domain / appropriately licensed placeholders

Consistency matters more than sophistication.

A strong minimal style is preferable to a mixture of unrelated polished assets.

Suggested visual target:

> dark arena + crisp geometric sprites + bright impact effects + restrained glow

The game should look intentionally minimal, not unfinished.

---

# 23. Explicitly Out of Scope

Do **not** implement:

* upgrades
* 3-choice upgrade screen
* combo scoring
* goals
* meta progression
* prestige
* bosses
* multiple enemy types
* achievements
* Steamworks
* save files
* multiple arenas
* procedural levels
* dash
* controller rebinding UI
* settings
* localization
* story
* tutorials
* character selection
* permanent unlocks

Those belong to the real MVP/V1.

---

# 24. Showcase Build

The recruiting build should launch directly into gameplay.

Ideal flow:

```text
launch
↓
WIPE: SURVIVAL logo for <1 sec
↓
gameplay
```

Or simply launch directly into gameplay.

The prospective partner should not need setup instructions beyond:

```text
Move: WASD / left stick
Aim: mouse / right stick
Shooting: automatic
Restart: Space / A
```

---

# 25. Recruiting Video

Record approximately 20–40 seconds.

Suggested sequence:

### 0–5 sec

Show movement + independent aiming + obvious muzzle/trail effects.

### 5–15 sec

Show shooting and satisfying enemy hit/death particles.

### 15–25 sec

Show increasing enemy density and repeated kill bursts.

### 25–32 sec

Show a crowded screen with debug overlay briefly visible.

### 32–36 sec

Player takes damage and dies with the strongest VFX moment.

### 36–40 sec

Press restart and immediately return to gameplay.

The clip should communicate:

> responsive, lots happening, visually punchy, technically real, already playable.

Do not make a trailer.

No voice-over required.

---

# 26. Partner Evaluation Goal

Once the prototype exists, prospective partners should be able to answer questions such as:

* Does movement feel good?
* Does shooting feel good?
* Do the effects make kills satisfying?
* Is the screen readable under load?
* What visual direction would improve this?
* What systems would they want to own?
* What architectural choices would they change?
* Does working in With feel interesting?
* Can they see themselves polishing this for 4–6 months?

The prototype is partly a recruiting tool and partly a compatibility test.

---

# 27. Definition of Done

The recruiting prototype is done when all of the following are true:

* player moves smoothly
* player aims independently
* Xbox controller and Steam Controller/Steam Input dual-stick actions are tested; movement and aim work simultaneously, including deadzones and reconnects
* auto-fire works
* one enemy type continuously spawns
* enemies chase the player
* bullets kill enemies
* enemies damage the player
* player can die
* death screen appears
* restart is effectively instant
* kill/time counters work
* muzzle/trail effects exist
* enemy hit feedback exists
* enemy death particle burst exists
* player hit feedback exists
* player death has a clear visual payoff
* basic screen shake exists
* professional-sounding effects have controlled bass weight and remain readable under load
* ambient-house music provides an engaging, meditative background and loops seamlessly
* music survives death/retry without an audible restart or audio-device reinitialization
* the mix passes listening review on headphones and Steam Deck speakers
* particle effects remain readable under load
* debug performance overlay exists
* at least ~150 active enemies can be demonstrated smoothly
* a 20–40 second gameplay recording looks like a real game rather than an engine test
* another developer can clone/build/run it with reasonable instructions

Anything beyond that should be treated skeptically until a partner has joined.

