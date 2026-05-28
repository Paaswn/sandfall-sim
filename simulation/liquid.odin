package simulation

import "core:fmt"
import "core:math"
liquid_move_down :: proc(world: ^World, x, y: int) -> bool {
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	grid := world.grid
	steps := int(math.clamp(vy[now], 1, Max_Step_Y))
	target_y := y
	for s in 1 ..= steps {
		next_y := y + s
		if is_outside(x, next_y) {
			vx[now] += vy[now] * Impact_To_Side_Liquid
			vy[now] *= Y_Damp_On_Hit
			break
		}
		next := idx(x, next_y)
		if is_solid(grid, next) { 	// in case we stuck we will transfer energy right here
			vx[next] += vy[now] * Neighbor_Transfer
			vx[now] += vy[now] * Impact_To_Side_Liquid
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
		// drag_neighbor(world, vy[now], x, target_y)
		move_cell(world, to, now)
		return true
	}
	return false
}
liquid_move_side :: proc(world: ^World, x, y: int) -> bool {
 return true	
}
