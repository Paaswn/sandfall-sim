package main

import "core:fmt"
import rl "vendor:raylib"

Event_Queues :: struct {
	spawn:   [dynamic]Spawn_Event,
	explode: [dynamic]Explosion_Event,
}

Explosion_Event :: struct {
	x:     int,
	y:     int,
	r:     int,
	force: f32,
}

Spawn_Event :: struct {
	x:        int,
	y:        int,
	r:        int,
	material: Material,
}


event_listener :: proc(world: ^World, events: ^Event_Queues) {
	for se in events.spawn {
		circle_brush_spawn(world, se)
	}
	for ee in events.explode {
		explosion(world, ee)
	}
	clear_queues(events)
}

track_mouse :: proc(events: ^Event_Queues) {
	mouse_scale_x := int(rl.GetMouseX() / SCALE)
	mouse_scale_y := int(rl.GetMouseY() / SCALE)
	material_spawn_handler(&events.spawn, mouse_scale_x, mouse_scale_y, current_mat)
	explosion_event_handler(&events.explode, mouse_scale_x, mouse_scale_y, 1)
	cursor_size_handler()
}

track_kb :: proc() {
	actions: for input, action in KEY_BINDS {
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
		if !rl.IsKeyPressed(input.trigger) {
			continue
		}
		switch action {
		case .Debug_Off:
			debug_mode = Debug.Off
		case .Debug_Velocity_Y:
			debug_mode = Debug.Velocity_Y
		case .Debug_Velocity_X:
			debug_mode = Debug.Velocity_X
		case .Debug_Active_Cell:
			debug_mode = Debug.Active_Cell
		case .Select_Sand:
			current_mat = .Sand
		case .Select_Empty:
			current_mat = .Empty
		case .Select_Cement:
			current_mat = .Cement
		}
	}
}

explosion_event_handler :: proc(expl: ^[dynamic]Explosion_Event, msx, msy: int, force: f32) {
	if rl.IsMouseButtonDown(.LEFT) && select_explosive {
		if len(expl) < 512 {
			append(expl, Explosion_Event{msx, msy, spawn_radius, force})
		}
	}
}

material_spawn_handler :: proc(spawn: ^[dynamic]Spawn_Event, msx, msy: int, mat: Material) {
	if rl.IsMouseButtonDown(.LEFT) && !select_explosive {
		if len(spawn) < 512 {
			append(spawn, Spawn_Event{msx, msy, spawn_radius, mat})
		}
	}
}

cursor_size_handler :: proc() {
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() > 0 {
		spawn_radius += 1
	} else if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() < 0 {
		spawn_radius -= 1
		if spawn_radius <= 1 {
			spawn_radius = 1
		}
	}
}

make_event_queues :: proc() -> Event_Queues {
	return Event_Queues{make([dynamic]Spawn_Event), make([dynamic]Explosion_Event)}
}

delete_event_queues :: proc(queues: ^Event_Queues) {
	delete(queues.explode)
	delete(queues.spawn)
}

clear_queues :: proc(events: ^Event_Queues) {
	clear(&events.explode)
	clear(&events.spawn)
}
