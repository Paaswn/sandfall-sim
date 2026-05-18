package main

import rl "vendor:raylib"

Spawn_Event :: struct {
	x:        int,
	y:        int,
	r:        int,
	material: Material,
}

spawn_mat := Material.Sand

event_listener :: proc(world: ^World, events: ^[dynamic]Spawn_Event) {
	for e in events {
		spawn_circle(world, e)
	}
	clear(events)
}

track_mouse :: proc(events: ^[dynamic]Spawn_Event) {
	mouse_scale_x := int(rl.GetMouseX() / SCALE)
	mouse_scale_y := int(rl.GetMouseY() / SCALE)
	spawn_mat_ctl(events, mouse_scale_x, mouse_scale_y, spawn_mat)
	cursor_size_ctl()
}

track_kb :: proc() {
    if rl.IsKeyPressed(.ONE) {
       spawn_mat = .Empty 
    }
    else if rl.IsKeyPressed(.TWO) {
        spawn_mat = .Sand
    }
}
spawn_mat_ctl :: proc(events: ^[dynamic]Spawn_Event, msx, msy: int, mat: Material) {
    if rl.IsMouseButtonDown(.LEFT) {
		if len(events) < 512 {
			append(events, Spawn_Event{msx, msy, spawn_radius, mat})
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