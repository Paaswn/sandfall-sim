package main

import rl "vendor:raylib"

spawn_radius := 4
World :: struct {
	vel_y: []f32,
	vel_x: []f32,
	grid:  []Material,
	pixel: []rl.Color,
}

Material :: enum u8 {
	Empty,
	Sand,
}

idx :: proc(x, y: int) -> int {
	idx := y * WIDTH + x
	assert(idx < WIDTH * HEIGHT)
	return idx
}

is_outside :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > WIDTH - 1 || y > HEIGHT - 1
}

update :: proc(world: ^World) {
	update_grid(world)
}

spawn_circle :: proc(world: ^World, se: Spawn_Event) {
	for x in se.x - se.r ..= se.x + se.r {
		for y in se.y - se.r ..= se.y + se.r {
			if is_outside(x, y) {
				continue
			}
			dx := x - se.x
			dy := y - se.y
			if dx * dx + dy * dy <= se.r * se.r {
				i := idx(x, y)
				if world.grid[i] == se.material do continue
				world.grid[i] = se.material
			}
		}
	}
}
update_grid :: proc(world: ^World) {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	for y := HEIGHT - 2; y >= 0; y -= 1 {
		column_loop: for x in 0 ..< WIDTH {
			now := idx(x, y)
			if grid[now] == .Empty {
				vy[now] = 0
				vx[now] = 0
				continue
			}
			vy[now] += GRAVITY * f32(DT)
			step_y := clamp(int(vy[now]), 1, MAX_SAND_VY)
			target_y := y
			for s in 1 ..= step_y { 	// loop through possible step to check
				if is_outside(x, y + s) {
					vy[now] = 0
					break
				}

				if grid[idx(x, y + s)] == .Empty {
					target_y = y + s
				} else { 	// if below isn't Empty just break and set the current velocity to 0
					vy[now] = 0
					break
				}
			}
			if target_y != y {
				grid[idx(x, target_y)] = grid[now] // move material to target
				vy[idx(x, target_y)] = vy[now] // move velocity to target

				grid[now] = .Empty
				vy[now] = 0 // clear old velocity
				continue
			}
			for side in ([]int{-1, 1}) {
				target_x := x + side
				target_y := y + 1
				if is_outside(target_x, target_y) {
					continue
				}
				to := idx(target_x, target_y)
				if grid[to] == .Empty {
					vx[now] += SIDE_ACCEL * f32(side) * f32(DT)
					if abs(vx[now]) >= 1.0 {
						grid[now] = .Empty
						grid[to] = .Sand
						vx[to] = 0
						vy[to] = vy[now] * 0.4
						vx[now] = 0
						vy[now] = 0
					}
					continue column_loop
				}
			}
			vx[now] = 0
			vy[now] = 0
		}
	}
}

create_world :: proc() -> World {
    return  World {
		make([]f32, WIDTH * HEIGHT),
		make([]f32, WIDTH * HEIGHT),
		make([]Material, WIDTH * HEIGHT),
		make([]rl.Color, WIDTH * HEIGHT),
	}
}

delete_world :: proc(world: ^World) {
    delete(world.vel_y)
    delete(world.vel_x)
    delete(world.grid)
    delete(world.pixel)
}