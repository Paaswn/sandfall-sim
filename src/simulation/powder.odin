// current bug: cell gain vx too easily, especially sand, causing a long vertical stream line when foundation cell move diagonally and the above cell gain just enough vx to slide next frame and so on
package simulation

import "core:fmt"
import "core:math"
// randomly move down-left or down-right, will try to transfer some velocity to its below cell on a success tick
move_diagonal :: proc(world: ^World, config: Powder_Config, x, y: int) -> bool {
	grid := world.grid
	vx := world.vel_x
	vy := world.vel_y
	now := idx(x, y)
	if vx[now] < config.slide_thresh do return false
	side := random_side()
	for try in 1 ..= 2 {
		if try == 2 do side *= -1
		next := idx(x + side, y + 1)
		if is_outside(x + side, y + 1) ||
		   is_solid(grid, next) ||
		   is_solid(grid, idx(x + side, y)) {
			// if try == 2 do vx[now] *= config.damp
			continue
		}
		cx, cy := to_chunk_pos(x + side, y + 1)
		to_wake_chunk(world.chunks, cx, cy)
		vx[next] = vx[now] * config.friction
		vy[next] = vy[now] * config.friction
		switch {
		case is_outside(x, y + 1):
		case is_outside(x - side, y):
		case:
			vx[idx(x - side, y)] += math.max(vx[now], vy[now]) * config.slide_drag
			vx[idx(x, y + 1)] += math.max(vx[now], vy[now]) * config.slide_drag
		}
		move_cell(world, next, now)
		return true
	}
	return false
}

// randomly move left or right, will try to transfer some velocity to the obstacle on a failed tick
move_side :: proc(world: ^World, config: Powder_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	if vx[now] < config.side_thresh do return false
	side := world.side[now] // get the side from velocity
	if is_outside(x + side, y) {
		vx[now] *= config.damp
		return false
	}
	next := idx(x + side, y)
	if is_solid(grid, next) {
		if vx[now] >= config.impact_thresh { 	// maybe we can flip side here
			vx[next] += vx[now] * config.impact_to_side
			vx[now] *= config.damp
			world.side[now] *= -1
		}
		return false
	}
	cx, cy := to_chunk_pos(x + side, y + 1)
	to_wake_chunk(world.chunks, cx, cy)
	vx[next] = vx[now] * config.friction
	move_cell(world, next, now)
	return true
}

// move down based on vy value, will transfer some velocity to left-and-right cell
move_down :: proc(world: ^World, config: Powder_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	if is_outside(x, y + 1) || is_solid(grid, idx(x, y + 1)) do return false
	step := int(math.clamp(vy[now], 1, Powder.Max_Vy))
	to_y := y
	for s in 1 ..= step {
		next_y := y + s
		if is_outside(x, next_y) || is_solid(grid, idx(x, next_y)) {
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
		switch {
		case is_outside(x - 1, to_y):
		case is_outside(x + 1, to_y):
		case is_solid(grid, idx(x - 1, to_y)) || is_solid(grid, idx(x + 1, to_y)):
			left, right := idx(x - 1, to_y), idx(x + 1, to_y)
			vx[left] += vy[now] * config.fall_drag
			vx[right] += vy[now] * config.fall_drag
			vx[now] *= config.friction
		}

		to_wake_chunk(world.chunks, cx, cy)
		move_cell(world, to, now)
		return true
	}
	return false
}
