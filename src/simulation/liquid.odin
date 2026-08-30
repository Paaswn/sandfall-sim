package simulation

import "core:fmt"
import "core:math"
import "core:math/rand"

liquid_move_down :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	if i, ok := world_index(x, y + 1); !ok || !is_empty(grid, i) do return false
	if vy[now] < Liquid.Vy_Thresh do return false
	step := int(math.clamp(vy[now], 1, Liquid.Max_Vy))
	to_y := y
	for s in 1 ..= step {
		next_y := y + s
		if is_outside(x, next_y) || hittable(world, idx(x, next_y)) {
			if vy[now] >= config.impact_thresh {
				// this the only place where newly create cell will get its first vx value
				// try picking the preferred side for this cell
				vx[now] = vy[now] * config.impact_to_side
				if world.side[now] == 0 do world.side[now] = random_side()
				else if random_side() > 0 do world.side[now] *= -1
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
		// switch {
		// case is_outside(x - 1, to_y):
		// case is_outside(x + 1, to_y):
		// case is_solid(world, idx(x - 1, to_y)) || is_solid(world, idx(x + 1, to_y)):
		// 	left, right := idx(x - 1, to_y), idx(x + 1, to_y)
		// 	vx[left] += vy[now] * config.fall_drag
		// 	vx[right] += vy[now] * config.fall_drag
		// 	vx[now] *= config.friction
		// }

		activate_chunk(world, to_chunk_pos(World_Pos{ x, to_y }), { x, to_y })
		move_cell(world, to, now)
		return true
	}
	return false
}
liquid_move_side :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	now := idx(x, y)
	vx := world.vel_x
	vy := world.vel_y
	step := int(math.clamp(vx[now], 0, Liquid.Max_Vx))
	side := world.side[now]
	to_x := x
	for s := 1 ;s <= step; s += 1 {
		next_x := x + s * world.side[now]
		if is_outside(next_x, y) {
			world.side[now] *= -1
			break
		}
		next := idx(next_x, y)
		if !is_empty(grid, next) {
			check := idx(x - side, y)
			if i, ok := world_index(x - side, y); ok && is_empty(grid, i) {
				world.side[now] *= -1
				vx[now] *= config.damp
				// vx[next] += 1
				// world.side[next] = side
			}
			// if is_solid(world, next) do
			break
		}
		to_x = next_x
		// if !is_outside(next_x, y + 1) && is_empty(grid, idx(next_x, y + 1)) do break
	}
	if to_x != x {
		to := idx(to_x, y)
		is_empty(grid, to) or_return
		vx[to] = vx[now]
		vy[to] = vy[now]
		activate_chunk(world, to_chunk_pos(World_Pos{ to_x, y }), { to_x, y })
		move_cell(world, to, now)
		append(&world.movement, [4]int{x, y, to_x, y})
		return true
	}
	return false
}

liquid_move_diagonal :: proc(world: ^World, config: Material_Config, x, y: int) -> bool {
	grid := world.grid
	now := idx(x, y)
	vx := world.vel_x
	vy := world.vel_y
	side := world.side[now]
	to := world_index(x + side, y + 1) or_return
	if check, ok := world_index(x + side, y); !ok || !is_empty(grid, check) {
		return false
	}
	is_empty(grid, to) or_return
	vx[to] = vx[now]
	vy[to] = vy[now]
	activate_chunk(world, to_chunk_pos(World_Pos{ x + side, y + 1 }), { x + side, y + 1 })
	move_cell(world, to, now)
	return true
}
liquid_move :: proc(world: ^World, config: Material_Config, x0, y0: int) -> bool {
	now := idx(x0, y0)
	vx := world.vel_x
	vy := world.vel_y
	side := world.side[now]
	step_x := int(math.clamp(vx[now], 0, Liquid.Max_Vx)) * side
	step_y := int(math.clamp(vy[now], 1, Liquid.Max_Vy))
	x1, y1 := x0 + step_x, y0 + step_y
	dx := abs(x1 - x0)
	dy := -abs(y1 - y0)
	grid := world.grid
	sx := 1
	if x0 >= x1 do sx = -1

	sy := 1
	if y0 >= y1 do sy = -1

	err := dx + dy

	to_x := x0
	to_y := y0
	to := now
	if i, ok := world_index(x0+side, y0); !ok || is_solid(world, i) do return false
	if i, ok := world_index(x0+side, y0); !ok || is_solid(world, i) do return false
	for {
    	i := world_index(to_x, to_y) or_break
        if i != now {
           	if !is_empty(grid, i) {
                vx[now] = vy[now] * config.impact_to_side
                break
            }
            to = i
        }
		if to_x == x1 && to_y == y1 {
			break
		}

		e2 := 2 * err

		if e2 >= dy {
			err += dy
			to_x += sx
		}

		if e2 <= dx {
			err += dx
			to_y += sy
		}
	}
	moved := ( to_x != x0 || to_y != y0 ) && (to != now)
	moved or_return
	vx[to] = vx[now]
	vy[to] = vy[now]
	move_cell(world, to, now)
	activate_chunk(world, to_chunk_pos(World_Pos{ to_x, to_y }), { to_x, to_y })
	append(&world.movement, [4]int{x0, y0, to_x, to_y})
	return true
}
@(private = "file")
hittable :: proc(world: ^World, idx: int) -> bool {
	return is_solid(world, idx) || is_liquid(world.grid, idx)
}
