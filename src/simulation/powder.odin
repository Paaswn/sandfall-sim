// current bug: cell gain vx too easily, especially sand, causing a long vertical stream line when foundation cell move diagonally and the above cell gain just enough vx to slide next frame and so on
package simulation

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// randomly move down-left or down-right, will try to transfer some velocity to its below cell on a success tick
powder_move_diagonal :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vx := world.vel_x
	vy := world.vel_y
	now := idx(x, y)
	if vx[now] < config.slide_thresh do return false
	side := random_side()
	for try in 1 ..= 2 {
		if try == 2 do side *= -1
		next, inside := world_index(x + side, y + 1)
		if !inside || is_solid(world, next) || is_solid(world, idx(x + side, y)) {
			// if try == 2 do vx[now] *= config.damp
			continue
		}
		world.side[now] = side
		cx, cy := to_chunk_pos(x + side, y + 1)
		put_chunk_in_queue(world, cx, cy, x + side, y+1)
		vx[next] = vx[now] * config.friction
		vy[next] = vy[now] * config.friction
		if check, ok := world_index(x, y + 1); ok && is_solid(world, check) {
			vx[check] += math.max(vx[now], vy[now]) * config.slide_drag
			world.side[check] = world.side[now]
		}
		if is_liquid(grid, next) {
			vx[next] *= config.friction
			swap_cell(world, next, now)
		} else {
			move_cell(world, next, now)
		}
		return true
	}
	return false
}

// randomly move left or right, will try to transfer some velocity to the obstacle on a failed tick
powder_move_side :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	if vx[now] < config.side_thresh do return false
	side := world.side[now] // get the side from velocity
	next, inside := world_index(x + side, y)
	if !inside {
		vx[now] *= config.damp
		return false
	}
	if is_solid(world, next) {
		if vx[now] >= config.impact_thresh { 	// maybe flipping side here
			vx[next] += vx[now] * config.impact_to_side
			vx[now] *= config.damp
			world.side[now] *= -1
		}
		return false
	}
	cx, cy := to_chunk_pos(x + side, y)
	put_chunk_in_queue(world, cx, cy, x+side, y)
	vx[next] = vx[now] * config.friction
	if is_liquid(grid, next) {
		vx[next] *= config.damp
		swap_cell(world, next, now)
	} else {
		move_cell(world, next, now)
	}
	return true
}

// move down based on vy value, will transfer some velocity to left-and-right cell
powder_move_down :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	below, inside := world_index(x, y + 1)
	if !inside || is_solid(world, below) do return false
	if vy[now] < Powder.Vy_Thresh do return false
	// if is_liquid(grid, below) && vy[now] < config.slide_thresh do return false
	// try move side if we in water and has vy below threshold
	step := int(math.clamp(vy[now], 1, Powder.Max_Vy))
	to_y := y
	through_liquid := false
	for s in 1 ..= step {
		next_y := y + s
		next, ok := world_index(x, next_y)
		if !ok || is_solid(world, next) {
			if vy[now] >= config.impact_thresh {
				// this the only place where newly create cell will get its first vx value
				// try picking the preferred side for this cell
				vx[now] = vy[now] * config.impact_to_side
				world.side[now] = random_side()
			}
			vy[now] *= config.damp
			break
		}
		if ok && is_liquid(grid, next) {
			vy[now] *= config.friction
			through_liquid = true
		}
		to_y = next_y
	}
	if to_y != y {
		to := idx(x, to_y)
		vx[to] = vx[now]
		vy[to] = vy[now]
		cx, cy := to_chunk_pos(x, to_y)
		put_chunk_in_queue(world, cx, cy, x , to_y)
		if !through_liquid {
			get_friction := false
			if left, inside := world_index(x - 1, to_y); inside && is_solid(world, left) {
				vx[left] += vy[now] * config.fall_drag
				left_cx, left_cy := to_chunk_pos(x - 1, to_y)
				put_chunk_in_queue(world, left_cx, left_cy, x-1, to_y)
				world.side[left] = world.side[now]
				get_friction = true
			}
			if right, inside := world_index(x + 1, to_y); inside && is_solid(world, right) {
				vx[right] += vy[now] * config.fall_drag
				right_cx, right_cy := to_chunk_pos(x + 1, to_y)
				put_chunk_in_queue(world, right_cx, right_cy, x+1, to_y)
				world.side[right] = world.side[now]
				get_friction = true
			}
			if get_friction do vx[now] *= config.friction
			move_cell(world, to, now)
		} else {
			swap_cell(world, to, now)
		}
		return true
	}
	return false
}


