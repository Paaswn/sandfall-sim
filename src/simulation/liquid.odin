package simulation

import "core:fmt"
import "core:math"
import "core:math/rand"

liquid_move_down :: proc(sim: ^Simulation, config: Material_Config, uctx: Update_Context) -> bool {
    world := sim.world
	now := uctx.now
	x := uctx.wpos.x;
	y := uctx.wpos.y;
	if i, ok := world_index(x, y + 1); !ok || !is_empty(sim^, i) do return false
	if world[now].vel.y < LIQUID.Vy_Thresh do return false
	step := int(math.clamp(world[now].vel.y, 1, LIQUID.Max_Vy))
	to_y := y
	for s in 1 ..= step {
		next_y := y + s
		if is_outside(x, next_y) || is_cell(sim^, idx(x, next_y), {.Liquid, .Powder}) {
			if world[now].vel.y >= config.impact_thresh {
				// this the only place where newly create cell will get its first vx value
				// try picking the preferred side for this cell
				world[now].vel.x = world[now].vel.y * config.impact_to_side
				if world[now].side == 0 do world[now].side = i8( random_side(sim.rng)) 
				else if random_side(sim.rng) > 0 do world[now].side *= -1
			}
			world[now].vel.y *= config.damp
			break
		}
		to_y = next_y
	}
	if to_y != y {
		to := idx(x, to_y)
		world[to].vel = world[now].vel

		mark_dirty(sim^, World_Pos{ x, to_y })
		move_cell(sim^, to, now)
		return true
	}
	return false
}
liquid_move_side :: proc(sim: ^Simulation, config: Material_Config, uctx: Update_Context) -> bool {
    world := sim.world
	now := uctx.now
	x := uctx.wpos.x;
	y := uctx.wpos.y;
	step := int(math.clamp(world[now].vel.x, 0, LIQUID.Max_Vx))
	side := int( world[now].side )
	to_x := x
	first_valid_x := -1
	for s := 1 ;s <= step; s += 1 {
		next_x := x + s * side
		if is_outside(next_x, y) {
			world[now].side *= -1
			break
		}
		next := idx(next_x, y)
		if !is_empty(sim^, next) {
			if is_liquid( sim^, next) && s != step {
				if first_valid_x == -1 do first_valid_x = to_x
				continue
			}
			check := idx(x - side, y)
			if i, ok := world_index(x - side, y); ok && is_empty(sim^, i) {
				world[now].side *= -1
				world[now].vel.x *= config.damp
				// vx[next] += 1
				// world.side[next] = side
			}
			// if is_solid(world, next) do
			break
		}
		to_x = next_x
		// if !is_outside(next_x, y + 1) && is_empty(grid, idx(next_x, y + 1)) do break
	}
	if first_valid_x != -1 && !is_empty(sim^, idx( to_x, y )) {
		to_x = first_valid_x
	}
	if to_x != x {
		to := idx(to_x, y)
		is_empty(sim^, to) or_return
		world[to].vel = world[now].vel
		mark_dirty(sim^, World_Pos{ to_x, y })
		move_cell(sim^, to, now)
		append(&sim.cell_traces, [4]int{x, y, to_x, y})
		return true
	}
	return false
}

liquid_move_diagonal :: proc(sim: ^Simulation, config: Material_Config, uctx: Update_Context) -> bool {
    world := sim.world
	now := uctx.now
	x := uctx.wpos.x;
	y := uctx.wpos.y;
	side := int( world[now].side )
	to := world_index(x + side, y + 1) or_return
	if check, ok := world_index(x + side, y); !ok || !is_empty(sim^, check) {
		return false
	}
	is_empty(sim^, to) or_return
	world[to].vel = world[now].vel
	mark_dirty(sim^, World_Pos{ x + side, y + 1 })
	move_cell(sim^, to, now)
	return true
}
liquid_move :: proc(sim: ^Simulation, config: Material_Config, uctx: Update_Context) -> bool {
    world := sim.world
	now := uctx.now
	x0 := uctx.wpos.x;
	y0 := uctx.wpos.y;
	side := int( world[now].side )
	step_x := int(math.clamp(world[now].vel.x, 0, LIQUID.Max_Vx)) * side
	step_y := int(math.clamp(world[now].vel.y, 1, LIQUID.Max_Vy))
	x1, y1 := x0 + step_x, y0 + step_y
	dx := abs(x1 - x0)
	dy := -abs(y1 - y0)
	grid := world
	sx := 1
	if x0 >= x1 do sx = -1

	sy := 1
	if y0 >= y1 do sy = -1

	err := dx + dy

	to_x := x0
	to_y := y0
	to := now
	if i, ok := world_index(x0+side, y0); !ok || is_solid(sim^, i) do return false
	for {
    	i := world_index(to_x, to_y) or_break
        if i != now {
           	if !is_empty(sim^, i) {
                world[now].vel.x = world[now].vel.y * config.impact_to_side
                break
            }
            to = i
        }
		if to_x == x1 && to_y == y1 {
			break
		}

		world[now].vel.x *= config.friction
		e2 := 2 * err

		if e2 >= dy {
			err += dy
			to_x += sx
		}

		if e2 <= dx {
			err += dx
			to_y += sy
		}
	}
	moved := to != now
	moved or_return
	pos := to_world_pos(to)
	// if rand.float32() < 0.1 {
	//     world.side[now] *= -1
	// }
	world[to].vel = world[now].vel
	move_cell(sim^, to, now)
	activate_chunk(sim^, to_chunk_pos(pos), pos)
	append(&sim.cell_traces, [4]int{x0, y0, pos.x, pos.y})
	return true
}
