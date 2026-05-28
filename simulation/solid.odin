package simulation

import "core:math"
drag_neighbor :: proc(world: ^World, source: f32, x, y: int) {
	vx := world.vel_x
	vy := world.vel_y
	grid := world.grid
	now := idx(x, y)
	for s in 1 ..= 3 {
		check_y := y - 2 + s
		if is_outside(x - 1, check_y) || is_outside(x + 1, check_y) do continue
		check_left := idx(x - 1, check_y)
		check_right := idx(x + 1, check_y)
		vx[check_left] += source
		vx[check_right] += source
	}
}
move_diagonal :: proc(world: ^World, x, y: int) -> bool {
	// check for diagnal movement first
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	grid := world.grid
	if abs( vx[now] ) < X_Threshold/4 do return false
	// probably could flag as inactive here
	if is_outside(x - 1, y + 1) || is_outside(x + 1, y + 1) do return false

	// then randomly choose falling direction
	side := random_side()
	for try in 0 ..< 2 {
		if try == 1 {
			side *= -1
		}
		to := idx(x + side, y + 1)
		if is_solid(grid, to) || is_solid(grid, idx(x + side, y)) {
			continue
		}
		vx[to] = vx[now] * Diagonal_X_Transfer * f32(side)
		vy[to] = vy[now] * Diagonal_Y_Transfer
		wake_neighbor(world, x + side, y + 1, 1)
		drag_neighbor(world, vx[now], x + side, y + 1)
		move_cell(world, to, now)
		return true
	}
	return false
}

move_side :: proc(world: ^World, x, y: int) -> bool {
	now := idx(x, y)
	vx := world.vel_x
	vy := world.vel_y
	if abs(vx[now]) < X_Threshold do return false
	side := random_side()
	for try in 0 ..< 2 {
		if try == 1 {
			side *= -1
		}
		if is_outside(x + side, y) do continue
		to := idx(x + side, y)
		if is_solid(world.grid, to) do continue
		wake_neighbor(world, x + side, y, 1)
		vx[to] = vx[now] * Horizontal_X_Transfer
		vy[to] = vy[now] * Horizontal_Y_Transfer
		move_cell(world, to, now)
		return true
	}
	return false
}

move_down :: proc(world: ^World, x, y: int) -> bool {
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	grid := world.grid
	steps := int(math.clamp(vy[now], 1, Max_Step_Y))
	target_y := y
	for s in 1 ..= steps {
		next_y := y + s
		if is_outside(x, next_y) {
			vx[now] += vy[now] * Impact_To_Side
			vy[now] *= Y_Damp_On_Hit
			break
		}
		next := idx(x, next_y)
		if is_solid(grid, next) { 	// in case we stuck we will transfer energy right here
			if next_y != y + 1 {
				vx[next] += vy[now] * Neighbor_Transfer
				vx[now] += vy[now] * Impact_To_Side
			}
			vy[now] *= Y_Damp_On_Hit
			break
		}
		wake_neighbor(world, x, next_y, 1)
		target_y = next_y
	}
	if target_y != y {
		to := idx(x, target_y)
		vy[to] = vy[now]
		vx[to] = vx[now]
		drag_neighbor(world, vy[now], x, target_y)
		move_cell(world, to, now)
		return true
	}
	return false
}