package game

import g "../game"
import sim "../simulation"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Control :: struct {
	cursor:       Mouse,
	actions:      [dynamic]Action,
	enable_kb:    bool,
	enable_mouse: bool,
}

Mouse :: struct {
	pos:        rl.Vector2,
	world:      sim.World_Pos,
	prev_world: sim.World_Pos,
	wheel:      Wheel_State,
	has_prev:   bool,
}

Button_State :: struct {
	down:     bool,
	released: bool,
	pressed:  bool,
}

Modifiers :: bit_set[Modifier_Key]

Input :: struct {
	trigger: Trigger,
	modifer: Modifiers,
	hold:    bool,
}

Trigger :: union {
	rl.KeyboardKey,
	rl.MouseButton,
	Wheel_State,
}

Wheel_State :: enum {
	Up,
	None,
	Down,
}


Modifier_Key :: enum {
	None,
	Ctrl,
	Shift,
	Alt,
}

Action :: enum {
	Debug_Off,
	Debug_Velocity_Y,
	Debug_Velocity_X,
	Debug_Chunk,
	Debug_Material_Movement,
	Debugger_Toggle,
	Debugger_Forward,
	Debugger_Backward,
	Select_Empty,
	Increase_Tick,
	Decrease_Tick,
	Increase_Brush_Size,
	Decrease_Brush_Size,
	Make_Spawn_Point,
	Hot_Reload,
	Open_Debug_Menu,
	Toggle_Brush_Tool,
	Toggle_Pipette_Tool,
	Use_Tool,
	Show_Floating_Ui,
	Zoom_In,
	Zoom_Out,
}

MB :: rl.MouseButton
KK :: rl.KeyboardKey
WS :: Wheel_State
Keybinds :: [Action]Input {
	.Debug_Off               = {KK.ONE, {.Ctrl}, false},
	.Debug_Velocity_Y        = {KK.TWO, {.Ctrl}, false},
	.Debug_Velocity_X        = {KK.THREE, {.Ctrl}, false},
	.Debug_Chunk             = {KK.FOUR, {.Ctrl}, false},
	.Select_Empty            = {KK.ONE, {.None}, false},
	.Increase_Tick           = {WS.Up, {.Shift}, false},
	.Decrease_Tick           = {WS.Down, {.Shift}, false},
	.Increase_Brush_Size     = {WS.Up, {.Ctrl}, false},
	.Decrease_Brush_Size     = {WS.Down, {.Ctrl}, false},
	.Make_Spawn_Point        = {KK.F, {.None}, false},
	.Hot_Reload              = {KK.R, {.Ctrl}, false},
	.Open_Debug_Menu         = {KK.F1, {.None}, false},
	.Toggle_Brush_Tool       = {KK.B, {.None}, false},
	.Toggle_Pipette_Tool     = {KK.Q, {.None}, false},
	.Debugger_Toggle         = {KK.SPACE, {.None}, false},
	.Debugger_Forward        = {KK.L, {.None}, false},
	.Debugger_Backward       = {KK.H, {.None}, false},
	.Debug_Material_Movement = {KK.FIVE, {.Ctrl}, false},
	.Use_Tool                = {MB.LEFT, {.None}, true},
	.Show_Floating_Ui        = {MB.RIGHT, {.None}, false},
	.Zoom_In                 = {WS.Up, {.None}, false},
	.Zoom_Out                = {WS.Down, {.None}, false},
}

input_handler :: proc(game: ^g.Game, control: ^Control, action_events: ^[dynamic]Action) {
	events := &game.events
	config := &game.config
	actions: for input, action in Keybinds {
		for mod in input.modifer {
			switch mod {
			case .None:
				if rl.IsKeyDown(.LEFT_CONTROL) ||
				   rl.IsKeyDown(.LEFT_SHIFT) ||
				   rl.IsKeyDown(.LEFT_ALT) {
					continue actions
				}
			case .Ctrl:
				if !rl.IsKeyDown(.LEFT_CONTROL) {
					continue actions
				}
			case .Shift:
				if !rl.IsKeyDown(.LEFT_SHIFT) {
					continue actions
				}
			case .Alt:
				if !rl.IsKeyDown(.LEFT_ALT) {
					continue actions
				}
			}
		}
		switch trig in input.trigger {
		case KK:
			if input.hold {
				if !rl.IsKeyDown(trig) && trig != .KEY_NULL {
					continue
				}
			} else {
				if !rl.IsKeyPressed(trig) && trig != .KEY_NULL {
					continue
				}
			}
		case MB:
			control.enable_mouse or_continue
			if input.hold {
				if !rl.IsMouseButtonDown(trig) {
					control.cursor.has_prev = false
					continue
				}
			} else {
				rl.IsMouseButtonPressed(trig) or_continue
			}
		case WS:
			(trig == control.cursor.wheel) or_continue
		}
		append(action_events, action)
	}
}

switch_tool :: proc(gc: ^g.Game_Config, tool: g.Tool) {
	tm := &gc.tool_man
	tm.prev_tool = tm.curr_tool
	tm.curr_tool = tool
	tm.just_switched = 10
}

update_mouse_state :: proc(camera: rl.Camera2D, mouse: ^Mouse) {
    delta := rl.GetMouseDelta()
    mouse.pos += delta / camera.zoom
	mouse.world = g.world_cursor(mouse.pos)
	mouse.wheel = get_wheel_state()
}

get_wheel_state :: proc() -> (wheel: Wheel_State) {
	if rl.GetMouseWheelMove() < 0 do wheel = .Down
	else if rl.GetMouseWheelMove() > 0 do wheel = .Up
	else do wheel = .None
	return
}

use_tool :: proc(game: ^g.Game, control: ^Control) {

	switch game.config.tool_man.curr_tool {
	case .Pipette:
		game.config.current_mat = sim.id_at(game.simulation.world, sim.idx(control.cursor.world))
		switch_tool(&game.config, game.config.tool_man.prev_tool)
	case .Brush:
		if game.config.tool_man.just_switched > 0 {
			game.config.tool_man.just_switched -= 1
			return
		}
		spawn := &game.events.spawn
		if len(spawn) < 512 {
			if control.cursor.has_prev {
				append(
					spawn,
					g.Spawn_Event {
						control.cursor.prev_world,
						control.cursor.world,
						game.config.brush_size,
						game.config.current_mat,
					},
				)
			} else {
				append(
					spawn,
					g.Spawn_Event {
						control.cursor.world,
						control.cursor.world,
						game.config.brush_size,
						game.config.current_mat,
					},
				)
				control.cursor.has_prev = true
			}
			control.cursor.prev_world = control.cursor.world
		}
	}
}


init_control :: proc(ctl: ^Control) {
	ctl.actions = make([dynamic]Action, 0, 256)
	ctl.cursor = {{}, {}, {}, {}, false}
	ctl.enable_kb = true
	ctl.enable_mouse = true
}

delete_control :: proc(ctl: ^Control) {
	delete(ctl.actions)
}
create_spawn_point :: proc(mouse: Mouse, events: ^g.Event_Queues, config: ^g.Game_Config) {
	deleted := false
	for _, se in events.spawn_points {
		if g.intersect(
			se.pos.x - se.r,
			se.pos.y - se.r,
			2 * se.r,
			2 * se.r,
			mouse.world.x - config.brush_size,
			mouse.world.y - config.brush_size,
			config.brush_size * 2,
			config.brush_size * 2,
		) {
			events.point_spawned -= 1
			delete_key(&events.spawn_points, se.point)
			deleted = true
		}
	}
	if deleted do return
	events.point_spawned += 1
	map_insert(
		&events.spawn_points,
		events.point_spawned,
		g.Spawn_Point{events.point_spawned, mouse.world, config.brush_size, config.current_mat},
	)
}
