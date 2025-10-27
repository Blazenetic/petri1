Phase 1.1 scaffold implemented.

Changes applied:
- Project settings updated in [project.godot](project.godot:1)
  - Main scene set: run/main_scene → res://scenes/Main.tscn
  - Rendering method: forward_plus
  - Window: 1920x1080, stretch mode canvas_items, aspect expand
  - Physics: 60 TPS
  - Editor: disable_stdout=false
  - Autoloads registered: GlobalEvents, WorldState, ConfigurationManager
- .gitignore extended in [.gitignore](.gitignore:1) to include .import/, export/, .mono/, .DS_Store, Thumbs.db
- Directory scaffold created:
  - scenes/, scenes/environments/, scenes/entities/, scenes/ui/
  - scripts/, scripts/systems/, scripts/components/, scripts/behaviors/, scripts/utils/
  - resources/, resources/organisms/, resources/tools/, resources/challenges/
  - assets/, assets/sprites/, assets/audio/, assets/shaders/
- Scenes created per blueprint:
  - [scenes/environments/PetriDish.tscn](scenes/environments/PetriDish.tscn:1) with Boundary (StaticBody2D + CollisionShape2D with CircleShape2D radius 480) and Visuals node
  - [scenes/ui/HUD.tscn](scenes/ui/HUD.tscn:1) with Root MarginContainer (full anchors) and DebugInfo Label ("Ready")
  - [scenes/Game.tscn](scenes/Game.tscn:1) with Camera2D (current=true, zoom=(1,1)), DishContainer instancing PetriDish, SystemsContainer
  - [scenes/Main.tscn](scenes/Main.tscn:1) root Node2D with Game instance, UILayer (layer=1) containing HUD instance, SystemsContainer
- Autoload singletons implemented:
  - [scripts/systems/GlobalEvents.gd](scripts/systems/GlobalEvents.gd:1) prints ready and declares signals
  - [scripts/systems/WorldState.gd](scripts/systems/WorldState.gd:1) tracks time and prints ready
  - [scripts/systems/ConfigurationManager.gd](scripts/systems/ConfigurationManager.gd:1) exposes dish_radius/grid_cell_size and prints ready
- Human editor checklist and verification steps authored in [AGENTS/phase_1.1-human.md](AGENTS/phase_1.1-human.md:1)

Verification notes:
- Press F5: Project should launch to Main → Game with Camera2D current and HUD "Ready". Output should print:
  - [GlobalEvents] ready
  - [WorldState] ready
  - [ConfigurationManager] ready
- Window resizing should stretch correctly based on configured stretch settings.

Pending human step:
- Define Input Map actions and bindings via editor as outlined in [AGENTS/phase_1.1-human.md](AGENTS/phase_1.1-human.md:1) Step 3:
  - ui_pan (MMB, optional Space), ui_zoom_in (Wheel Up), ui_zoom_out (Wheel Down), ui_select (LMB), ui_drag_select (LMB), ui_reset_camera (R), ui_pause (Space), ui_speed_1 (1), ui_speed_2 (2), ui_speed_5 (5)

Recommended commit:
- Commit message: chore: phase 1.1 scaffold project settings scenes autoloads input map

Phase 1.1 is ready for final verification and commit once Input Map actions are added in the editor.