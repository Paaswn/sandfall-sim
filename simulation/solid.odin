package simulation

import "core:fmt"
import "core:math"
drag_neighbor :: proc(world: ^World, source: f32, x, y: int) {

}
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
		vx[next] = vx[now]
		vy[next] = vy[now]
		move_cell(world, next, now)
		return true
	}
	return false
}

move_side :: proc(world: ^World, x, y: int) -> bool {
	return false
}

move_down :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	step := int(math.clamp(vy[now], 1, config.max_vy))
	to_y := y
	for s in 1 ..= step {
		next_y := y + s
		if is_outside(x, y + s) || is_solid(grid, idx(x, y + s)) {
			vx[now] += vy[now] * config.impact_to_side
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
		to_wake_chunk(world.chunks, cx, cy)
		move_cell(world, to, now)
		return true
	}
	return false
}
