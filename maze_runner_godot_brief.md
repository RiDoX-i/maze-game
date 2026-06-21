# Project Brief: "Maze Runner" — Procedural Pixel-Art Maze Game

## For: Claude Code
## Engine: Godot 4.x (GDScript)
## Platform target: Mobile (Android/iOS export)

---

## 1. High-Level Concept

A mobile game where the player navigates procedurally generated pixel-art mazes under a time limit. Each maze must be escaped within a scaled time limit. The player has 3 hearts. Losing all hearts resets progress to Level 1, Difficulty Tier 1. Clearing 3 mazes in a difficulty tier without dying advances the player to the next tier and gives a 20% chance to gain back a heart (capped at 3).

---

## 2. Core Game Loop

1. Player starts a run: **3 hearts**, **Difficulty Tier 1**, **Maze 1 of 3**.
2. Player is dropped into a procedurally generated maze with a countdown timer.
3. Player navigates from start to exit before the timer hits 0.
4. **Win** (reach exit in time): advance to the next maze in the tier.
   - If this was maze 3 of the tier (tier cleared with zero deaths in the tier): advance to next Difficulty Tier, reset maze count to 1, and roll a 20% chance to gain +1 heart (max cap: 3 hearts).
   - If hearts were lost during the tier, still advance to the next tier on completing maze 3, but skip the heart-bonus roll.
5. **Lose** (timer hits 0 before reaching exit): lose 1 heart, retry **Maze 1 of the current tier** (do not lose tier progress, only the in-tier maze streak).
6. **Hearts reach 0**: full run reset — back to **Difficulty Tier 1, Maze 1, 3 hearts**.
7. Loop continues indefinitely — there is no final level, difficulty keeps scaling.

---

## 3. State Machine (explicit logic for `game_state.gd`)

State variables:
- `hearts: int` (0–3, start at 3)
- `current_tier: int` (start at 1)
- `maze_in_tier: int` (1, 2, or 3)
- `tier_clean_run: bool` (true if no death has occurred since the start of the current tier; reset to true when a new tier begins)

Transitions:
- `on_maze_won()`:
  - if `maze_in_tier < 3`: `maze_in_tier += 1`, generate next maze
  - if `maze_in_tier == 3`:
	- `current_tier += 1`
	- `maze_in_tier = 1`
	- if `tier_clean_run == true`:
	  - roll random 0–99; if `< 20` and `hearts < 3`: `hearts += 1`
	- `tier_clean_run = true`
	- generate next maze (next tier's complexity)
- `on_maze_lost()`:
  - `hearts -= 1`
  - `tier_clean_run = false`
  - if `hearts <= 0`:
    - full reset: `hearts = 3`, `current_tier = 1`, `maze_in_tier = 1`, `tier_clean_run = true`
  - else:
    - `maze_in_tier = 1` (retry tier from its start, keep `current_tier`)
  - generate next maze

---

## 4. Maze Generation

- **Algorithm**: Recursive backtracker (depth-first search maze generation). Produces good "twisty" mazes with long corridors that read well in pixel art.
- Implement as a standalone, engine-decoupled script: `maze_generator.gd`
  - Input: `width: int`, `height: int`, `seed: int` (optional, for reproducibility/testing)
  - Output: a 2D grid data structure representing walls/paths, plus designated start and exit cells
  - This script should have NO dependency on scene nodes — it should be pure logic so it can be unit tested independently of the Godot editor running.
- **Difficulty scaling**: as `current_tier` increases, increase maze `width`/`height`, and/or increase branching factor / number of dead ends. Define a simple formula, e.g.:
  - `maze_size = base_size + (current_tier - 1) * size_increment`
  - Cap growth at a reasonable max so mazes don't become unrenderable on a phone screen — implement a max tier scaling cutoff (e.g., dimensions stop growing past a certain tier, and from then on only branching complexity increases).

---

## 5. Timer System

- Each maze's time limit is **not fixed at 30 seconds** — it scales with maze complexity.
- Suggested formula (tune via playtesting):
  - `time_limit = base_time + (cell_count * per_cell_factor) + (dead_end_count * dead_end_bonus)`
  - Example starting values: `base_time = 15`, `per_cell_factor = 0.3`, `dead_end_bonus = 0.5`
- Implement in `timer_manager.gd`, taking the generated maze's stats as input and returning the computed time limit.
- Display: countdown visible on-screen at all times during a maze, pixel-art styled font/UI.

---

## 6. Hearts System

- 3 hearts max, displayed as pixel-art heart icons in the HUD (filled/empty states).
- Heart loss/gain should have a small, satisfying visual/audio cue — especially the 20% bonus heart roll, since it's a rare positive event worth celebrating visually.

---

## 7. Project Structure (Godot)

```
res://
├── scenes/
│   ├── main_menu.tscn
│   ├── game.tscn
│   ├── game_over.tscn
│   └── hud.tscn
├── scripts/
│   ├── maze_generator.gd      # pure logic, no scene deps
│   ├── game_state.gd          # hearts/tier/maze state machine
│   ├── timer_manager.gd       # time limit calculation
│   ├── player_controller.gd   # movement/input
│   └── maze_renderer.gd       # turns maze_generator output into tilemap/scene
├── assets/
│   ├── sprites/
│   │   ├── player/
│   │   ├── tiles/
│   │   └── ui/
│   └── audio/
└── tests/
    └── test_maze_generator.gd # GUT unit tests (if GUT framework is added)
```

---

## 8. Build Order / Milestones (suggested phases for Claude Code)

**Phase 1 — Core logic, no visuals:**
- `maze_generator.gd` (recursive backtracker, returns grid + start/exit)
- `game_state.gd` (full state machine as specified in section 3)
- `timer_manager.gd` (time limit formula)
- Basic unit tests for all three, runnable independent of the editor UI

**Phase 2 — Minimal playable scene:**
- `game.tscn` with a simple rendered maze (basic colored tiles, no final art)
- Player movement (grid-based or free movement — decide and implement)
- Countdown timer UI
- Win/lose detection wired to `game_state.gd`

**Phase 3 — Hearts & progression UI:**
- HUD showing hearts, current tier, maze X of 3
- Heart bonus roll feedback
- Game over screen on full reset
- Main menu scene

**Phase 4 — Pixel art integration:**
- Swap placeholder tiles/sprites for final pixel art assets
- Animations (player movement, heart gain/loss, win/lose transitions)

**Phase 5 — Mobile polish:**
- Touch input controls (virtual joystick or swipe, decide based on playtesting)
- Export settings for Android/iOS
- Performance pass on maze size caps for lower-end devices

---

## 9. Open Decisions (flag these back to the user, don't assume)

- Movement style: grid-step movement (tap/swipe a direction) vs. continuous joystick movement?
- Exact tuning constants for timer formula and maze size scaling (start with suggested defaults above, expect to tune after playtesting)
- Whether the heart bonus roll caps at exactly 3 or if there's a reason to allow a temporary buffer above 3

---

## 10. Out of Scope for Claude Code

- Actual pixel art asset creation (use placeholder colored rectangles/tiles until real art is supplied, e.g., via Aseprite)
- Sound design / final audio assets (use placeholder/silent stubs until supplied)



-----

## 11. Game Modes (current)

The original endless loop above is now one of three selectable modes:

- **CLASSIC** — a 1000-level campaign. Levels are beaten in order; clearing a
  level unlocks the next and locks the one just cleared (no replays). Each
  level's difficulty is a deterministic function of its number, so every retry
  plays at the *same* difficulty (a fresh layout, same challenge). There are no
  hearts and no game-over: running out of time simply reloads a same-difficulty
  map. Every block of 10 levels is a "chapter" that shares one art theme. A
  level-select screen (`scenes/level_select.tscn`) shows the chapters with
  theme-tinted cards and resumes at the player's current level. Progress
  persists via `scripts/campaign_progress.gd` (`user://campaign_progress.json`).
  Difficulty curve + helpers live in `scripts/game_state.gd` (`campaign_*`).
- **ENDLESS** — the original tier-based loop described in sections 1–6 (3 mazes
  per tier, hearts, 20% bonus heart, scaling forever). This mode owns the World
  Records board.
- **TRAP** — the fixed prepared-campaign mode (`scripts/prepared_trap_maps.gd`).
