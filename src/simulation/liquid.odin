package simulation

import "core:fmt"
import "core:math"

liquid_move_down :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	if is_outside(x, y + 1) || hittable(world, idx(x, y + 1)) do return false
	step := int(math.clamp(vy[now], 1, Powder.Max_Vy))
	to_y := y
	for s in 1 ..= step {
		next_y := y + s
		if is_outside(x, next_y) || hittable(world, idx(x, next_y)) {
			if vy[now] >= config.impact_thresh {
				// this the only place where newly create cell will get its first vx value
				// try picking the preferred side for this cell
				vx[now] = vy[now] * config.impact_to_side
				if world.side[now] == 0 do world.side[now] = random_side()
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
		case is_solid(world, idx(x - 1, to_y)) || is_solid(world, idx(x + 1, to_y)):
			left, right := idx(x - 1, to_y), idx(x + 1, to_y)
			vx[left] += vy[now] * config.fall_drag
			vx[right] += vy[now] * config.fall_drag
			vx[now] *= config.friction
		}

		wake_chunk_next(world, cx, cy)
		move_cell(world, to, now)
		return true
	}
	return false
}
liquid_move_side :: proc(world: ^World, x, y: int) -> bool {
	grid := world.grid
	now := idx(x, y)
	vx := world.vel_x
	vy := world.vel_y
	step := int(math.clamp(vx[now], 0, Powder.Max_Vx))
	side := world.side[now]
	to_x := x
	for s in 1 ..= step {
		next_x := x + s * side
		if is_outside(next_x, y) {

			world.side[now] *= -1
			break
		}
		next := idx(next_x, y)
		if hittable(world, next) {
			check := idx(x - side, y)
			if !(is_outside(x - side, y) || hittable(world, check)) {
				world.side[now] *= -1
				vx[now] *= 0.98
			}
			break
		}
		to_x = next_x
		// if !is_outside(next_x, y + 1) && is_empty(grid, idx(next_x, y + 1)) do break
	}
	if to_x != x {
		to := idx(to_x, y)
		vx[to] = vx[now]
		vy[to] = vy[now]
		cx, cy := to_chunk_pos(to_x, y)
		wake_chunk_next(world, cx, cy)
		move_cell(world, to, now)
		return true
	}
	return false
}

@(private="file")
hittable :: proc(world: ^World, idx: int) -> bool {
	return is_solid(world, idx) || is_liquid(world.grid, idx)
}
