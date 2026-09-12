package app

import g "../game"
import sim "../simulation"
import "core:fmt"
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

update_mouse_state :: proc(mouse: ^Mouse) {
	mouse_pos := rl.GetMousePosition()
	mouse.world = g.world_cursor(mouse_pos)
	mouse.wheel = get_wheel_state()
	mouse.pos = mouse_pos
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

update_input :: #force_inline proc(a: ^App) {
	update_mouse_state(&a.control.cursor)
	overlap :=
		(rl.CheckCollisionPointRec(a.control.cursor.pos, a.ui.bound) && a.ui.show) ||
		(rl.CheckCollisionPointRec(a.control.cursor.pos, a.ui.float_ui.bound) &&
				a.ui.float_ui.show)
	if overlap {
		a.control.cursor.has_prev = false
		a.control.enable_mouse = false
	} else {
		a.control.enable_mouse = true
	}
	input_handler(&a.game, &a.control, &a.control.actions)
}

consume_action :: #force_inline proc(app: ^App) {
	game := &app.game
	config := &game.config
	debug_ui := &app.ui
	control := &app.control
	for e in control.actions {
		switch e {

		case .Show_Floating_Ui:
			app.ui.float_ui.show = !app.ui.float_ui.show 
			app.ui.float_ui.bound.x = control.cursor.pos.x
			app.ui.float_ui.bound.y = control.cursor.pos.y
		case .Use_Tool:
			use_tool(game, control)
		case .Debugger_Backward:
			if game.debugger.on {
				g.backward_frame(&game.debugger)
			}
		case .Debugger_Forward:
			if game.debugger.on {
				g.forward_frame(&game.debugger)
			}
		case .Debugger_Toggle:
			game.debugger.on = !game.debugger.on
		case .Debug_Material_Movement:
			game.config.show_material_movement = !game.config.show_material_movement
		case .Toggle_Brush_Tool:
			switch_tool(&game.config, .Brush)
		case .Toggle_Pipette_Tool:
			switch_tool(&game.config, game.config.tool_man.prev_tool)
		case .Open_Debug_Menu:
			debug_ui.show = !debug_ui.show
		case .Debug_Off:
			config.debug_render = sim.Debug.Off
		case .Debug_Velocity_Y:
			config.debug_render = sim.Debug.Velocity_Y
		case .Debug_Velocity_X:
			config.debug_render = sim.Debug.Velocity_X
		case .Debug_Chunk:
			config.show_chunk_border = !config.show_chunk_border
		case .Select_Empty:
			config.current_mat = 0 
		case .Increase_Tick:
			config.time_scale += 1
			if config.time_scale >= i32(len(sim.TIME_SCALES)) - 1 do config.time_scale = i32(len(sim.TIME_SCALES)) - 1
		case .Decrease_Tick:
			config.time_scale -= 1
			if config.time_scale <= 0 do config.time_scale = 0
		case .Increase_Brush_Size:
			config.brush_size += 1
		case .Decrease_Brush_Size:
			config.brush_size -= 1
			if config.brush_size <= 1 do config.brush_size = 1
		case .Make_Spawn_Point:
			create_spawn_point(control.cursor, &game.events, config)
		case .Hot_Reload:
			if !game.events.hot_reload do game.events.hot_reload = true
		}
	}
	clear(&app.control.actions)
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
