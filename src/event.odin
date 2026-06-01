package main

import "core:fmt"
import sim "simulation"
import rl "vendor:raylib"

Event_Queues :: struct {
	spawn:       [dynamic]Spawn_Event,
	spawn_perm:  map[int]Spawn_Point,
	hot_reload:  bool,
	spawn_point: int,
}
Material :: sim.Material
World :: sim.World
Debug :: sim.Debug
Spawn_Event :: struct {
	x0:       int,
	y0:       int,
	x1:       int,
	y1:       int,
	r:        int,
	material: Material,
}

Spawn_Point :: struct {
	point:    int,
	x0:       int,
	y0:       int,
	r:        int,
	material: Material,
}

make_event_queues :: proc() -> Event_Queues {
	return Event_Queues{make([dynamic]Spawn_Event), make(map[int]Spawn_Point), false, 0}
}

delete_event_queues :: proc(queues: ^Event_Queues) {
	delete(queues.spawn)
	delete(queues.spawn_perm)
}

clear_queues :: proc(events: ^Event_Queues) {
	clear(&events.spawn)
}

event_listener :: proc(world: ^World, events: ^Event_Queues) {
	for se in events.spawn {
		brush_line(world, se)
	}
	for _, se in events.spawn_perm {
		sim.circle_brush_spawn(world, se.x0, se.y0, se.r, se.material)
	}
	if events.hot_reload {
		hot_reload(world)
		fmt.eprintln("hot reloaded!")
		events.hot_reload = false
	}
	clear_queues(events)
}

track_input :: proc(game: ^Game) {
	events := &game.events
	config := &game.config
	mouse := &game.mouse
	material_spawn_handler(&events.spawn, mouse, config)
	actions: for input, action in sim.Key_Binds {
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
		case .Debug_Off:
			config.debug_mode = Debug.Off
		case .Debug_Velocity_Y:
			config.debug_mode = Debug.Velocity_Y
		case .Debug_Velocity_X:
			config.debug_mode = Debug.Velocity_X
		case .Debug_Chunk:
			config.debug_mode = Debug.Chunk
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
			if config.time_scale >= len(sim.T_Scales) - 1 do config.time_scale = len(sim.T_Scales) - 1
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

create_spawn_point :: proc(mouse: ^Mouse_State, events: ^Event_Queues, config: ^Game_Config) {
	for _, se in events.spawn_perm {
		if intersect(
			se.x0 - se.r,
			se.y0 - se.r,
			2 * se.r,
			2 * se.r,
			mouse.world.x - config.brush_size,
			mouse.world.y - config.brush_size,
			config.brush_size * 2,
			config.brush_size * 2,
		) {
			events.spawn_point -= 1
			delete_key(&events.spawn_perm, se.point)
			return
		}
	}
	events.spawn_point += 1
	map_insert(
		&events.spawn_perm,
		events.spawn_point,
		Spawn_Point {
			events.spawn_point,
			mouse.world.x,
			mouse.world.y,
			config.brush_size,
			config.current_mat,
		},
	)
}
intersect :: proc(x0, y0, w0, h0, x1, y1, w1, h1: int) -> bool {
	if x0 + w0 < x1 || x0 > x1 + w1 do return false
	if y0 + h0 < y1 || y0 > y1 + h1 do return false
	return true
}

material_spawn_handler :: proc(
	spawn: ^[dynamic]Spawn_Event,
	mouse: ^Mouse_State,
	config: ^Game_Config,
) {
	if rl.IsMouseButtonDown(.LEFT) {
		if len(spawn) < 512 {
			msx, msy := mouse.world[0], mouse.world[1]
			omsx, omsy := mouse.prev_world[0], mouse.prev_world[1]
			if mouse.has_prev {
				append(
					spawn,
					Spawn_Event{omsx, omsy, msx, msy, config.brush_size, config.current_mat},
				)
			} else {
				append(
					spawn,
					Spawn_Event{msx, msy, msx, msy, config.brush_size, config.current_mat},
				)
				mouse.has_prev = true
			}
			mouse.prev_world = {msx, msy}
		}
	} else do mouse.has_prev = false
}

brush_line :: proc(world: ^World, se: Spawn_Event) {
	dx := abs(se.x1 - se.x0)
	dy := -abs(se.y1 - se.y0)

	sx := 1
	if se.x0 >= se.x1 do sx = -1

	sy := 1
	if se.y0 >= se.y1 do sy = -1

	err := dx + dy

	x := se.x0
	y := se.y0

	for {
		sim.circle_brush_spawn(world, x, y, se.r, se.material)

		if x == se.x1 && y == se.y1 {
			break
		}

		e2 := 2 * err

		if e2 >= dy {
			err += dy
			x += sx
		}

		if e2 <= dx {
			err += dx
			y += sy
		}
	}
}
