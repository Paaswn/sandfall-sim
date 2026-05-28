package simulation

import "core:fmt"
import rl "vendor:raylib"

Event_Queues :: struct {
	spawn:      [dynamic]Spawn_Event,
	spawn_perm: map[int]Spawn_Point,
}

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
	return Event_Queues{make([dynamic]Spawn_Event), make(map[int]Spawn_Point)}
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
		brush_spawn(world, se)
	}
	for _, se in events.spawn_perm {
		circle_brush_spawn(world, se.x0, se.y0, se.r, se.material)
	}
	clear_queues(events)
}

old_mouse_x: int
old_mouse_y: int
has_prev_mouse := false
current_point := 0
track_input :: proc(events: ^Event_Queues) {
	mouse_scale_x := int(rl.GetMouseX() / Scale)
	mouse_scale_y := int(rl.GetMouseY() / Scale)
	material_spawn_handler(&events.spawn, mouse_scale_x, mouse_scale_y, current_mat)
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
		if input.mouse_wheel > 0 && rl.GetMouseWheelMove() < 0 do continue
		if input.mouse_wheel < 0 && rl.GetMouseWheelMove() > 0 do continue
		if !rl.IsKeyPressed(input.trigger) && input.trigger != .KEY_NULL {
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
		case .Select_Water:
			current_mat = .Water
		case .Increase_Tick:
			t_scale += 0.1
			if t_scale >= 1 {
				t_scale = 1
			}
		case .Decrease_Tick:
			t_scale -= 0.1
			if t_scale <= 0.1 {
				t_scale = 0.1
			}
		case .Increase_Brush_Size:
			spawn_radius += 1
		case .Decrease_Brush_Size:
			spawn_radius -= 1
			if spawn_radius <= 1 do spawn_radius = 1
		case .Make_Spawn_Point:
			for _, se in events.spawn_perm {
				if intersect(
					se.x0 - se.r,
					se.y0 - se.r,
					2 * se.r,
					2 * se.r,
					mouse_scale_x - spawn_radius,
					mouse_scale_y - spawn_radius,
					spawn_radius * 2,
					spawn_radius * 2,
				) {
					current_point -= 1
					delete_key(&events.spawn_perm, se.point)
					return
				}
			}
			current_point += 1
			map_insert(
				&events.spawn_perm,
				current_point,
				Spawn_Point {
					current_point,
					mouse_scale_x,
					mouse_scale_y,
					spawn_radius,
					current_mat,
				},
			)
		}
	}
}

intersect :: proc(x0, y0, w0, h0, x1, y1, w1, h1: int) -> bool {
	if x0 + w0 < x1 || x0 > x1 + w1 do return false
	if y0 + h0 < y1 || y0 > y1 + h1 do return false
	return true
}
material_spawn_handler :: proc(spawn: ^[dynamic]Spawn_Event, msx, msy: int, mat: Material) {
	if rl.IsMouseButtonDown(.LEFT) && !select_explosive {
		if len(spawn) < 512 {
			if has_prev_mouse {
				append(spawn, Spawn_Event{old_mouse_x, old_mouse_y, msx, msy, spawn_radius, mat})
			} else {
				append(spawn, Spawn_Event{msx, msy, msx, msy, spawn_radius, mat})
				has_prev_mouse = true
			}
			old_mouse_x = msx
			old_mouse_y = msy
		}
	} else do has_prev_mouse = false
}
