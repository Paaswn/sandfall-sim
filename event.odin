package main

import rl "vendor:raylib"

Spawn_Event :: struct {
	x:        int,
	y:        int,
	r:        int,
	material: Material,
}


event_listener :: proc(world: ^World, events: ^[dynamic]Spawn_Event) {
	for e in events {
		spawn_circle(world, e)
	}
	clear(events)
}

track_mouse :: proc(events: ^[dynamic]Spawn_Event) {
	mouse_scale_x := int(rl.GetMouseX() / SCALE)
	mouse_scale_y := int(rl.GetMouseY() / SCALE)
	spawn_mat_ctl(events, mouse_scale_x, mouse_scale_y)
	cursor_size_ctl()
}

spawn_mat_ctl :: proc(events: ^[dynamic]Spawn_Event, msx, msy: int) {
    if rl.IsMouseButtonDown(.LEFT) {
		if len(events) < 512 {
			append(events, Spawn_Event{msx, msy, spawn_radius, .Sand})
		}
	}
}

cursor_size_ctl :: proc()  {
    if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() > 0 {
		spawn_radius += 1
	} else if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() < 0 {
		spawn_radius -= 1
		if spawn_radius <= 0 {
			spawn_radius = 0
		}
	}
}