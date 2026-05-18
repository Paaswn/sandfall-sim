package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

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

update :: proc(world: ^World, tick: int) {
	for y := HEIGHT - 2; y >= 0; y -= 1 {
		if tick % 2 == 0 {
			for x := 0; x < WIDTH; x += 1 {
				update_row(world, x, y)
			}
		} else {
			for x := WIDTH - 1; x >= 0; x -= 1 {
				update_row(world, x, y)
			}
		}
	}
}

explosion :: proc(world: ^World, ee: Explosion_Event) {
	vx := world.vel_x
	vy := world.vel_y
	for x in ee.x - ee.r ..= ee.x + ee.r {
		for y in ee.y - ee.r ..= ee.y + ee.r {
			if is_outside(x, y) {
				continue
			}
			dx := x - ee.x
			dy := y - ee.y
			dist_sq := dx * dx + dy * dy
			if dist_sq > 0 && dist_sq <= ee.r * ee.r {
				i := idx(x, y)
				if world.grid[i] != .Empty {
					dist := math.sqrt(f32(dist_sq))
					dir_x := f32(dx) / dist
					dir_y := f32(dy) / dist
					falloff := 1.0 - dist / f32(ee.r)
					weighted_force := ee.force * falloff
					vx[i] += dir_x * weighted_force
					vy[i] += dir_y * weighted_force
				}
			}
			if dist_sq > 0 && dist_sq <= ee.r * ee.r / 4 {
				i := idx(x, y)
				if world.grid[i] != .Empty {
				    world.grid[i] = .Empty
				}
			}
		}
	}
}

circle_brush_spawn :: proc(world: ^World, se: Spawn_Event) {
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

update_row :: proc(world: ^World, x, y: int) {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	if grid[now] == .Empty {
		vy[now] = 0
		vx[now] = 0
		return
	}
	vy[now] += GRAVITY * f32(DT)
	step_y := clamp(int(vy[now]), 0, MAX_SAND_STEP)
	dir_y := 0
	if vy[now] > 0 {
		dir_y = 1
	} else if vy[now] < 0 {
		dir_y = -1
	}
	target_y := y
	for s in 1 ..= step_y { 	// loop through possible step to check
		next_y := y + s * dir_y
		if is_outside(x, next_y) {
			vy[now] = 0
			break
		}

		if grid[idx(x, next_y)] == .Empty {
			target_y = next_y
		} else { 	// if below isn't Empty just break and set the current velocity to 0
			vy[now] = 0
			break
		}
	}
	if target_y != y && dir_y != 0 {
		to := idx(x, target_y)
		grid[to] = grid[now] // move material to target
		vy[to] = vy[now] // move velocity to target
		vx[to] = vx[now]

		grid[now] = .Empty
		vy[now] = 0 // clear old velocity
		vx[now] = 0
		return
	}

	if abs(vx[now]) >= 1.0 {
		side := 1
		if vx[now] < 0 {
			side = -1
		}

		target_x := x + side
		target_y := y
		if !is_outside(target_x, target_y) {
			to := idx(target_x, target_y)

			if grid[to] == .Empty {
				grid[to] = grid[now]
				vx[to] = vx[now] * SIDE_FRICTION
				vy[to] = vy[now]

				grid[now] = .Empty
				vx[now] = 0
				vy[now] = 0
				return
			} else {
				vx[now] *= 0.4
			}
		}
	}
	{
		side := rand.choice([]int{-1, 1})
		for attempt in 1 ..= 2 {
			if attempt == 2 {
				side = -side
			}
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
					vx[to] = vx[now] * SIDE_FRICTION
					vy[to] = vy[now] * 0.4
					vx[now] = 0
					vy[now] = 0
				}
				return
			}
		}
	}
	vx[now] *= 0.85
	vy[now] *= 0.4
}

create_world :: proc() -> World {
	return World {
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
