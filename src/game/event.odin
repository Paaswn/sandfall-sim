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

create_spawn_point :: proc(mouse: ^Mouse, events: ^Event_Queues, config: ^Game_Config) {
	deleted := false
	for _, se in events.spawn_points {
		if intersect(
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
		Spawn_Point {
			events.point_spawned,
			mouse.world,
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

mouse_handler :: proc( instance: ^Game ) {
	spawn := &instance.events.spawn
	mouse := &instance.mouse
	config:= &instance.config

	switch config.tool_man.curr_tool {
		case .Pipette:
			if rl.IsMouseButtonPressed(.LEFT) {
				x, y := instance.mouse.world.x, instance.mouse.world.y
				config.current_mat = instance.world.grid[sim.idx(x, y)]
				switch_tool(config, config.tool_man.prev_tool)
			}
		case .Brush:
			if config.tool_man.just_switched > 0 {
				config.tool_man.just_switched -= 1
				return
			}
			if rl.IsMouseButtonDown(.LEFT) {
				if len(spawn) < 512 {
					if mouse.has_prev {
						append(
							spawn,
							Spawn_Event{mouse.prev_world, mouse.world, config.brush_size, config.current_mat},
						)
					} else {
						append(
							spawn,
							Spawn_Event{mouse.world, mouse.world, config.brush_size, config.current_mat},
						)
						mouse.has_prev = true
					}
					mouse.prev_world = mouse.world
				}
			} else do mouse.has_prev = false
		
			if rl.IsMouseButtonPressed(.RIGHT) {
				float_ui := &instance.debug_ui.float_uis
				float_ui.show =  !float_ui.show
				float_ui.bound.x  = mouse.pos.x
				float_ui.bound.y  = mouse.pos.y
			}
	}
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
