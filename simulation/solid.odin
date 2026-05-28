package simulation

move_diagonal :: proc(world: ^World, x, y: int) -> bool {
	// check for diagnal movement first
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	grid := world.grid
	if vx[now] < X_THRESHOLD do return false
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
		vx[to] = vx[now] * DIAGONAL_X_TRANSFER * f32(side)
		vy[to] = vy[now] * DIAGONAL_Y_TRANSFER
		wake_neighbor(world, x + side, y + 1, 1)
		move_cell(world, to, now)
		return true
	}
	return false
}

move_side :: proc(world: ^World, x, y: int) -> bool {
	now := idx(x, y)
	vx := world.vel_x
	vy := world.vel_y
	if abs(vx[now]) < X_THRESHOLD do return false
	side := 1
	if vx[now] < 0 {
		side = -1
	}
	if is_outside(x + side, y) do return false
	to := idx(x + side, y)
	if is_solid(world.grid, to) do return false
	wake_neighbor(world, x + side, y, 1)
	vx[to] = vx[now] * HORIZONTAL_X_TRANSFER
	vy[to] = vy[now] * HORIZONTAL_Y_TRANSFER
	move_cell(world, to, now)
	return false
}