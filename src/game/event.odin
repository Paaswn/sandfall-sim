package game

import "core:fmt"
import sim "../simulation"
import rl "vendor:raylib"

Event_Queues :: struct {
	spawn:       [dynamic]Spawn_Event,
	spawn_points:  map[int]Spawn_Point,
	hot_reload:  bool,
	point_spawned: int,
}

Material :: sim.Material
World :: sim.World
Debug :: sim.Debug
Spawn_Event :: struct {
    prev_pos: sim.World_Pos,
    pos: sim.World_Pos,
	r:        int,
	material: Material,
}

Spawn_Point :: struct {
	point:    int,
	pos: sim.World_Pos,
	r:        int,
	material: Material,
}

make_event_queues :: proc() -> Event_Queues {
	return Event_Queues{make([dynamic]Spawn_Event), make(map[int]Spawn_Point), false, 0}
}

delete_event_queues :: proc(queues: ^Event_Queues) {
	delete(queues.spawn)
	delete(queues.spawn_points)
}

clear_queues :: proc(events: ^Event_Queues) {
	clear(&events.spawn)
}

dispatch_event :: proc(world: ^World, events: ^Event_Queues) {
	for se in events.spawn {
		brush_line(world, se)
	}
	for _, se in events.spawn_points {
		sim.circle_brush_spawn(world, se.pos, se.r, se.material)
	}
	if events.hot_reload {
		hot_reload(world)
		events.hot_reload = false
	}
	clear_queues(events)
}

intersect :: proc(x0, y0, w0, h0, x1, y1, w1, h1: int) -> bool {
	if x0 + w0 < x1 || x0 > x1 + w1 do return false
	if y0 + h0 < y1 || y0 > y1 + h1 do return false
	return true
}

brush_line :: proc(world: ^World, se: Spawn_Event) {
	dx := abs(se.pos.x - se.prev_pos.x)
	dy := -abs(se.pos.y - se.prev_pos.y)

	sx := 1
	if se.prev_pos.x >= se.pos.x do sx = -1

	sy := 1
	if se.prev_pos.y >= se.pos.y do sy = -1

	err := dx + dy

	x := se.prev_pos.x
	y := se.prev_pos.y

	for {
		sim.circle_brush_spawn(world, { x, y }, se.r, se.material)

		if x == se.pos.x && y == se.pos.y {
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
