package game

import sim "../simulation"
import rl "vendor:raylib"

Modifier_Key :: enum {
	None,
	Ctrl,
	Shift,
	Alt,
}

Modifiers :: bit_set[Modifier_Key]
Input :: struct {
	mouse_wheel: Wheel_State,
	trigger:     rl.KeyboardKey,
	modifer:     Modifiers,
}

Wheel_State :: enum {
	Up,
	None,
	Down,
}

Action :: enum {
	Debug_Off,
	Debug_Velocity_Y,
	Debug_Velocity_X,
	Debug_Chunk,
	Select_Empty,
	Select_Sand,
	Select_Cement,
	Select_Dirt,
	Select_Water,
	Increase_Tick,
	Decrease_Tick,
	Increase_Brush_Size,
	Decrease_Brush_Size,
	Make_Spawn_Point,
	Hot_Reload,
	Open_Debug_Menu
}

Key_Binds :: [Action]Input {
	.Debug_Off           = {.None, .ONE, {.Ctrl}},
	.Debug_Velocity_Y    = {.None, .TWO, {.Ctrl}},
	.Debug_Velocity_X    = {.None, .THREE, {.Ctrl}},
	.Debug_Chunk         = {.None, .FOUR, {.Ctrl}},
	.Select_Empty        = {.None, .ONE, {.None}},
	.Select_Sand         = {.None, .TWO, {.None}},
	.Select_Cement       = {.None, .THREE, {.None}},
	.Select_Water        = {.None, .FOUR, {.None}},
	.Select_Dirt         = {.None, .FIVE, {.None}},
	.Increase_Tick       = {.Up, .KEY_NULL, {.Shift}},
	.Decrease_Tick       = {.Down, .KEY_NULL, {.Shift}},
	.Increase_Brush_Size = {.Up, .KEY_NULL, {.Ctrl}},
	.Decrease_Brush_Size = {.Down, .KEY_NULL, {.Ctrl}},
	.Make_Spawn_Point    = {.None, .F, {.None}},
	.Hot_Reload          = {.None, .R, {.Ctrl}},
	.Open_Debug_Menu = {.None, .F1, {.None}}
}
keyboard_handler :: proc(game: ^Game) {
	events := &game.events
	config := &game.config
	mouse := &game.mouse
	actions: for input, action in Key_Binds {
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
		if input.mouse_wheel != mouse.wheel do continue
		if !rl.IsKeyPressed(input.trigger) && input.trigger != .KEY_NULL {
			continue
		}
		switch action {
		case .Open_Debug_Menu:
			game.debug_ui.show = !game.debug_ui.show
		case .Debug_Off:
			config.debug_render = Debug.Off
		case .Debug_Velocity_Y:
			config.debug_render = Debug.Velocity_Y
		case .Debug_Velocity_X:
			config.debug_render = Debug.Velocity_X
		case .Debug_Chunk:
			config.show_chunk_border = !config.show_chunk_border
		case .Select_Sand:
			config.current_mat = .Sand
		case .Select_Empty:
			config.current_mat = .Empty
		case .Select_Cement:
			config.current_mat = .Cement
		case .Select_Dirt:
			config.current_mat = .Dirt
		case .Select_Water:
			config.current_mat = .Water
		case .Increase_Tick:
			config.time_scale += 1
			if config.time_scale >= i32( len(sim.T_Scales) ) - 1 do config.time_scale = i32( len(sim.T_Scales) ) - 1
		case .Decrease_Tick:
			config.time_scale -= 1
			if config.time_scale <= 0 do config.time_scale = 0
		case .Increase_Brush_Size:
			config.brush_size += 1
		case .Decrease_Brush_Size:
			config.brush_size -= 1
			if config.brush_size <= 1 do config.brush_size = 1
		case .Make_Spawn_Point:
			create_spawn_point(mouse, events, config)
		case .Hot_Reload:
			if !events.hot_reload do events.hot_reload = true
		}
	}
}
