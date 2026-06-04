// current bug: cell gain vx too easily, especially sand, causing a long vertical stream line when foundation cell move diagonally and the above cell gain just enough vx to slide next frame and so on
package simulation

import "core:fmt"
import "core:math"
// randomly move down-left or down-right, will try to transfer some velocity to its below cell on a success tick
move_diagonal :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
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
		wake_chunk_next(world, cx, cy)
		vx[next] = vx[now] * config.friction
		vy[next] = vy[now] * config.friction
		{
			if check, inside := world_index(x, y + 1); inside && is_solid(world, check) {
				vx[check] += math.max(vx[now], vy[now]) * config.slide_drag
				world.side[check] = world.side[now]
			}
		}
		move_cell(world, next, now)
		return true
	}
	return false
}

// randomly move left or right, will try to transfer some velocity to the obstacle on a failed tick
move_side :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
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
		if vx[now] >= config.impact_thresh { 	// maybe we can flip side here
			vx[next] += vx[now] * config.impact_to_side
			vx[now] *= config.damp
			world.side[now] *= -1
		}
		return false
	}
	cx, cy := to_chunk_pos(x + side, y)
	wake_chunk_next(world, cx, cy)
	vx[next] = vx[now] * config.friction
	move_cell(world, next, now)
	return true
}

// move down based on vy value, will transfer some velocity to left-and-right cell
move_down :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	below, inside := world_index(x, y + 1)
	if !inside || is_solid(world, below) do return false
	step := int(math.clamp(vy[now], 1, Powder.Max_Vy))
	to_y := y
	for s in 1 ..= step {
		next_y := y + s
		next, inside := world_index(x, next_y)
		if !inside || is_solid(world, next) {
			if vy[now] >= config.impact_thresh {
				// this the only place where newly create cell will get its first vx value
				// try picking the preferred side for this cell
				vx[now] = vy[now] * config.impact_to_side
				world.side[now] = random_side()
			}
			vy[now] *= config.damp
			break
		}
		to_y = next_y
	}
	if to_y != y {
		to := idx(x, to_y)
		vx[to] = vx[now]
		vy[to] = vy[now]
		cx, cy := to_chunk_pos(x, to_y)
		get_friction := false
		if left, inside := world_index(x - 1, to_y); inside {
			vx[left] += vy[now] * config.fall_drag
			left_cx, left_cy := to_chunk_pos(x - 1, to_y)
			wake_chunk_next(world, left_cx, left_cy)
			get_friction = true
		}
		if right, inside := world_index(x + 1, to_y); inside {
			vx[right] += vy[now] * config.fall_drag
			right_cx, right_cy := to_chunk_pos(x + 1, to_y)
			wake_chunk_next(world, right_cx, right_cy)
			get_friction = true
		}
		if get_friction do vx[now] *= config.friction
		wake_chunk_next(world, cx, cy)
		move_cell(world, to, now)
		return true
	}
	return false
}
