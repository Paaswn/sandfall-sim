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
		if is_outside(x + side, y + 1) do continue
		next := idx(x + side, y + 1)
		if is_solid(grid, next) || is_solid(grid, idx(x + side, y)) do continue
		cx, cy := to_chunk_pos(x + side, y + 1)
		to_wake_chunk(world.chunks, cx, cy)
		vx[next] = vx[now] * config.friction
		vy[next] = vy[now] * config.friction
		switch {
		case is_outside(x, y + 1):
		case is_solid(grid, idx(x, y + 1)):
			vx[idx(x, y + 1)] += math.max(vx[now], vy[now]) * config.neighbor_drag
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
	side := random_side()
	if is_outside(x + side, y) do return false
	next := idx(x + side, y)
	if is_solid(grid, next) {
		if vx[now] >= config.impact_thresh {
			vx[next] += vx[now] * config.impact_to_side
			vx[now] *= config.friction
		}
		return false
	}
	cx, cy := to_chunk_pos(x + side, y + 1)
	to_wake_chunk(world.chunks, cx, cy)
	vx[next] = vx[now] * config.friction
	vy[next] = vy[now] * config.friction
	move_cell(world, next, now)
	return true
}

// move down based on vy value, will transfer some velocity to left-and-right cell
move_down :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	step := int(math.clamp(vy[now], 1, config.max_vy))
	to_y := y
	for s in 1 ..= step {
		next_y := y + s
		if is_outside(x, next_y) || is_solid(grid, idx(x, next_y)) {
			if vy[now] >= config.impact_thresh {
				vx[now] = vy[now] * config.impact_to_side
			}
			vy[now] *= config.damp
			break
		}
		switch {
		case is_outside(x - 1, y):
		case is_outside(x + 1, y):
		case:
			vx[idx(x - 1, y)] += vy[now] * config.neighbor_drag
			vx[idx(x + 1, y)] += vy[now] * config.neighbor_drag
		}

		to_y = next_y
	}
	if to_y != y {
		to := idx(x, to_y)
		vx[to] = vx[now]
		vy[to] = vy[now]
		cx, cy := to_chunk_pos(x, to_y)
		to_wake_chunk(world.chunks, cx, cy)
		move_cell(world, to, now)
		return true
	}
	return false
}
