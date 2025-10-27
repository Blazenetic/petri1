# Phase 1.1 — Human Editor Steps (Godot 4.5)

Use these steps to finalize editor-only settings and verify the scaffold. All file paths below must match what's already in the repo.

## 1) Verify Project Settings

1. Open Project Settings
   - Application
     - Run
       - Main Scene: set to res://scenes/Main.tscn
     - Config
       - Name: Petri
       - Icon: res://icon.svg
   - Rendering
     - Rendering Method: Forward+
   - Display
     - Window
       - Size: Viewport Width = 1920, Viewport Height = 1080
       - Stretch: Mode = canvas_items, Aspect = expand
   - Physics
     - Common: Physics Ticks Per Second = 60
   - Editor
     - Run: Disable Stdout = Off (false)
2. Press Close, then Save (Ctrl+S) to persist settings.

Notes:
- We've already configured these in project.godot; this is a verification step.

## 2) Verify Autoload Singletons

Project Settings → Autoload:
- Add or confirm these entries exist with Enabled checked:
  - Name: GlobalEvents, Path: res://scripts/systems/GlobalEvents.gd
  - Name: WorldState, Path: res://scripts/systems/WorldState.gd
  - Name: ConfigurationManager, Path: res://scripts/systems/ConfigurationManager.gd

The repository already includes these scripts. On run, you should see "ready" prints from each once.

## 3) Define Input Map Actions and Bindings

Project Settings → Input Map. Add the following Actions and bindings. After each Add, click the "+" beside the action to add an Event:

- ui_pan
  - Mouse: Middle Button
  - Optional: Space (as a modifier to pan in future; set now as a secondary binding)
- ui_zoom_in
  - Mouse: Wheel Up
- ui_zoom_out
  - Mouse: Wheel Down
- ui_select
  - Mouse: Left Button
- ui_drag_select
  - Mouse: Left Button (same as select; drag behavior will be implemented later)
- ui_reset_camera
  - Keyboard: R
- ui_pause
  - Keyboard: Space
- ui_speed_1
  - Keyboard: 1
- ui_speed_2
  - Keyboard: 2
- ui_speed_5
  - Keyboard: 5

Press Close, then Save (Ctrl+S). These bindings will be used by future systems.

## 4) Scene Scaffold (for reference)

Already created in the repo:
- Main Scene: res://scenes/Main.tscn
  - Node2D Main
    - Game (instance of res://scenes/Game.tscn)
    - CanvasLayer UILayer (layer = 1) with HUD instance
    - Node SystemsContainer
- Game Scene: res://scenes/Game.tscn
  - Node2D Game
    - Camera2D (current = true, zoom = (1,1))
    - Node2D DishContainer
      - Instance of res://scenes/environments/PetriDish.tscn
    - Node2D SystemsContainer
- Petri Dish: res://scenes/environments/PetriDish.tscn
  - Node2D PetriDish
    - StaticBody2D Boundary
      - CollisionShape2D (CircleShape2D radius ~480)
    - Node2D Visuals
- HUD: res://scenes/ui/HUD.tscn
  - Control HUD
    - MarginContainer Root (anchors full rect)
      - Label DebugInfo (text = "Ready")

## 5) Minimal Run Test

1. Press F5 to run.
2. Expect a blank window with:
   - Remote Scene Tree shows: Main → Game → Camera2D (current = true)
   - UILayer → HUD visible; "Ready" in top-left
3. Output panel should print exactly once on launch:
   - [GlobalEvents] ready
   - [WorldState] ready
   - [ConfigurationManager] ready
4. Resize the window: content should scale (stretch mode canvas_items, aspect expand).
5. Stop the game (Esc or Stop button).

If any warnings/errors appear, note them and stop. Do not proceed to gameplay features yet.

## 6) Git Hygiene and Commit

Ensure .gitignore includes at minimum:
- .godot/
- .import/
- export/
- .mono/
- .DS_Store
- Thumbs.db

Then commit:
- Commit message: chore: phase 1.1 scaffold project settings scenes autoloads input map

## 7) Handoff

Once the above is verified and committed, Phase 1.1 acceptance criteria are met. Notify Architect to proceed to Phase 1.2 (Base Entity System).
