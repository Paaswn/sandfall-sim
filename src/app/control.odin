package app

import g "../game"
import sim "../simulation"
import rl "vendor:raylib"

Control :: struct {
	cursor:  Cursor,
	actions: [dynamic]Action,
	enable_kb: bool,
	enable_mouse: bool
}

Cursor :: struct {
	pos:        rl.Vector2,
	world:      sim.World_Pos,
	prev_world: sim.World_Pos,
	wheel:      Wheel_State,
	has_prev:   bool,
}

Modifiers :: bit_set[Modifier_Key]

Input :: struct {
	mouse_wheel: Wheel_State,
	trigger:     Trigger,
	modifer:     Modifiers,
}

Trigger :: union {
	rl.KeyboardKey,
	rl.MouseButton,
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
}

MB :: rl.MouseButton
KK :: rl.KeyboardKey
Keybinds :: [Action]Input {
	.Debug_Off               = {.None, KK.ONE, {.Ctrl}},
	.Debug_Velocity_Y        = {.None, KK.TWO, {.Ctrl}},
	.Debug_Velocity_X        = {.None, KK.THREE, {.Ctrl}},
	.Debug_Chunk             = {.None, KK.FOUR, {.Ctrl}},
	.Select_Empty            = {.None, KK.ONE, {.None}},
	.Increase_Tick           = {.Up, KK.KEY_NULL, {.Shift}},
	.Decrease_Tick           = {.Down, KK.KEY_NULL, {.Shift}},
	.Increase_Brush_Size     = {.Up, KK.KEY_NULL, {.Ctrl}},
	.Decrease_Brush_Size     = {.Down, KK.KEY_NULL, {.Ctrl}},
	.Make_Spawn_Point        = {.None, KK.F, {.None}},
	.Hot_Reload              = {.None, KK.R, {.Ctrl}},
	.Open_Debug_Menu         = {.None, KK.F1, {.None}},
	.Toggle_Brush_Tool       = {.None, KK.B, {.None}},
	.Toggle_Pipette_Tool     = {.None, KK.Q, {.None}},
	.Debugger_Toggle         = {.None, KK.SPACE, {.None}},
	.Debugger_Forward        = {.None, KK.L, {.None}},
	.Debugger_Backward       = {.None, KK.H, {.None}},
	.Debug_Material_Movement = {.None, KK.FIVE, {.Ctrl}},
	.Use_Tool                = {.None, MB.LEFT, {.None}},
}

input_handler :: proc(game: ^g.Game, control: Control, action_events: ^[dynamic]Action) {
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
		if !is_wheel_match(input.mouse_wheel) do continue
		switch trig in input.trigger {
		case rl.KeyboardKey:
			if !rl.IsKeyDown(trig) && trig != .KEY_NULL {
				continue
			}
		case rl.MouseButton:
			control.enable_mouse or_continue
			rl.IsMouseButtonDown(trig) or_continue
		}
		append(action_events, action)
	}
}

switch_tool :: proc(gc: ^g.Game_Config, tool: g.Tool) {
	tm := &gc.tool_man
	tm.prev_tool = tm.curr_tool
	tm.curr_tool = tool
	tm.just_switched = 30
}

update_mouse_state :: proc(mouse: ^Cursor) {
	mouse_pos := rl.GetMousePosition()
	mouse.world = g.world_cursor(mouse_pos)
	mouse.pos = mouse_pos
}

is_wheel_match :: proc(state: Wheel_State) -> bool {
	wheel : Wheel_State
	if rl.GetMouseWheelMove() < 0 do wheel = .Down
	else if rl.GetMouseWheelMove() > 0 do wheel = .Up
	else do wheel = .None
	return state == wheel
}

use_tool :: proc(game: ^g.Game, control: ^Control) {

	switch game.config.tool_man.curr_tool {
	case .Pipette:
		game.config.current_mat = sim.material_at(&game.world, sim.idx(control.cursor.world))
		switch_tool(&game.config, game.config.tool_man.prev_tool)
	case .Brush:
		if game.config.tool_man.just_switched > 0 {
			game.config.tool_man.just_switched -= 1
			return
		}
		spawn := &game.events.spawn
		if rl.IsMouseButtonDown(.LEFT) {
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
		} else do control.cursor.has_prev = false
	}
}
consume_user_action :: proc(app: ^App) {
	game := &app.game
	config := &game.config
	debug_ui := app.ui
	control := &app.control
	for e in control.actions {
		switch e {

		case .Use_Tool:
		case .Debugger_Backward:
			if game.debugger.on do g.backward_frame(&game.debugger)
		case .Debugger_Forward:
			if game.debugger.on do g.forward_frame(&game.debugger)
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
			config.current_mat = .Empty
		case .Increase_Tick:
			config.time_scale += 1
			if config.time_scale >= i32(len(sim.Time_Scales)) - 1 do config.time_scale = i32(len(sim.Time_Scales)) - 1
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
}

init_control :: proc(ctl: ^Control) {
	ctl.actions = make([dynamic]Action, 0, 256)
}

create_spawn_point :: proc(mouse: Cursor, events: ^g.Event_Queues, config: ^g.Game_Config) {
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
		g.Spawn_Point {
			events.point_spawned,
			mouse.world,
			config.brush_size,
			config.current_mat,
		},
	)
}
