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
	delete(queues.spawn_points)
}

clear_queues :: proc(events: ^Event_Queues) {
	clear(&events.spawn)
}

event_listener :: proc(world: ^World, events: ^Event_Queues) {
	for se in events.spawn {
		brush_line(world, se)
	}
	for _, se in events.spawn_points {
		sim.circle_brush_spawn(world, se.x0, se.y0, se.r, se.material)
	}
	if events.hot_reload {
		hot_reload(world)
		fmt.eprintln("hot reloaded!")
		events.hot_reload = false
	}
	clear_queues(events)
}

create_spawn_point :: proc(mouse: ^Mouse, events: ^Event_Queues, config: ^Game_Config) {
	for _, se in events.spawn_points {
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
			events.point_spawned -= 1
			delete_key(&events.spawn_points, se.point)
			return
		}
	}
	events.point_spawned += 1
	map_insert(
		&events.spawn_points,
		events.point_spawned,
		Spawn_Point {
			events.point_spawned,
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
		
			if rl.IsMouseButtonPressed(.RIGHT) {
				float_ui := &instance.debug_ui.float_uis
				float_ui.show =  !float_ui.show
				float_ui.bound.x  = mouse.pos.x
				float_ui.bound.y  = mouse.pos.y
			}
	}
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
