// current bug: cell gain vx too easily, especially sand, causing a long vertical stream line when foundation cell move diagonally and the above cell gain just enough vx to slide next frame and so on
package simulation

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// randomly move down-left or down-right, will try to transfer some velocity to its below cell on a success tick
powder_move_diagonal :: proc(sim: ^Simulation, config: Material_Config, uctx: Update_Context) -> bool {
    world := sim.world
	now := uctx.now
	x := uctx.wpos.x;
	y := uctx.wpos.y;
	if world[now].vel.x < config.slide_thresh do return false
	side := random_side(sim.rng)
	for try in 1 ..= 2 {
		if try == 2 do side *= -1
		next, inside := world_index(x + side, y + 1)
		if !inside || is_solid(sim^, next) || is_solid(sim^, idx(x + side, y)) {
			// if try == 2 do world[now].vel.x *= config.damp
			continue
		}
		world[now].side = i8( side )
		mark_dirty(sim^, World_Pos{x + side, y + 1})
		world[next].vel = world[now].vel * config.friction
		if check, ok := world_index(x, y + 1); ok && is_solid(sim^, check) {
			world[check].vel.x += math.max(world[now].vel.x, world[now].vel.y) * config.slide_drag
			world[check].side = world[now].side
		}
		if is_liquid(sim^, next) {
			world[next].vel.x *= config.friction
			// swap_cell(world, next, now)
		} 
		move_cell(sim^, next, now)
		append(&sim.cell_traces, [4]int{x, y, x + int( side ), y + 1})
		return true
	}
	return false
}

// randomly move left or right, will try to transfer some velocity to the obstacle on a failed tick
powder_move_side :: proc(sim: ^Simulation, config: Material_Config, uctx: Update_Context) -> bool {
	x := uctx.wpos.x
	y := uctx.wpos.y
	now := uctx.now
	world := sim.world
	if world[now].vel.x < config.side_thresh do return false
	side := int( world[now].side ) // get the side from velocity
	next, inside := world_index(x + side, y)
	if !inside {
		world[now].vel.x *= config.damp
		return false
	}
	if is_solid(sim^, next) {
		if world[now].vel.x >= config.impact_thresh { 	// maybe flipping side here
			world[next].vel.x += world[now].vel.x * config.impact_to_side
			world[now].vel.x *= config.damp
			world[now].side *= -1
		}
		return false
	}
	mark_dirty(sim^, World_Pos{x + side, y})
	world[next].vel.x = world[now].vel.x * config.friction
	world[next].vel.y = world[now].vel.y
	if is_liquid(sim^, next) {
		world[next].vel.x *= config.damp
	} 
	move_cell(sim^, next, now)
	append(&sim.cell_traces, [4]int{x, y, x + side, y})
	return true
}

// move down based on vy value, will transfer some velocity to left-and-right cell
powder_move_down :: proc(sim: ^Simulation, config: Material_Config, uctx: Update_Context) -> bool {
    world := sim.world
	now := uctx.now
	x := uctx.wpos.x
	y := uctx.wpos.y
	below, inside := world_index(uctx.wpos + {0,1})
	if !inside || is_solid(sim^, below) do return false
	if world[now].vel.y < POWDER.Vy_Thresh do return false
	step := int(math.clamp(world[now].vel.y, 1, POWDER.Max_Vy))
	to_y := y
	through_liquid := false
	for s in 1 ..= step {
		next_y := y + s
		next, ok := world_index(x, next_y)
		if !ok || is_solid(sim^, next) {
			if world[now].vel.y >= config.impact_thresh {
				world[now].vel.x = world[now].vel.y * config.impact_to_side
				world[now].side = i8( random_side(sim.rng) )
			}
			world[now].vel.y *= config.damp
			break
		}
		if ok && is_liquid(sim^, next) {
			world[now].vel.y *= config.friction
			through_liquid = true
		}
		to_y = next_y
	}
	if to_y != y {
		to := idx({ x, to_y })
		world[to].vel = world[now].vel
		mark_dirty(sim^, World_Pos {x, to_y})
		if !through_liquid {
			get_friction := false
			if left, inside := world_index(x - 1, to_y); inside && is_solid(sim^, left) {
				world[left].vel.x += world[now].vel.y * config.fall_drag
				mark_dirty(sim^, World_Pos {x - 1, to_y})
				world[left].side = world[now].side
				get_friction = true
			}
			if right, inside := world_index(x + 1, to_y); inside && is_solid(sim^, right) {
				world[right].vel.x += world[now].vel.y * config.fall_drag
				mark_dirty(sim^, World_Pos {x + 1, to_y})
				world[right].side = world[now].side
				get_friction = true
			}
			if get_friction do world[now].vel.x *= config.friction
			move_cell(sim^, to, now)
		} else {
			// swap_cell(world, to, now)
		}
		append(&sim.cell_traces, [4]int{x, y, x, to_y})
		return true
	}
	return false
}
