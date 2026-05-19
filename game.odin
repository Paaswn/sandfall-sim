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

// only move material.
// vx vy will be reset in the next update any way but also
// reset vx vy to 0 as a guardrail
move_cell :: proc(world: ^World, to, now: int) {
	world.grid[to] = world.grid[now]
	world.grid[now] = .Empty
	world.vel_x[now] = 0
	world.vel_y[now] = 0
}

update_row :: proc(world: ^World, x, y: int) {
	// init local var
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)

	// clear vel for empty cell
	if grid[now] == .Empty {
		vy[now] = 0
		vx[now] = 0
		return
	}

	// apply GRAVITY
	vy[now] += GRAVITY * f32(DT)
	if update_y(world, x, y) do return
	// if can't py move some vy energy to vx
	vx[now] += vy[now] * 0.4
	vy[now] = 0
	if update_x(world, x, y) do return

	// damping a stationary cell
	vx[now] *= 0.85
	vy[now] *= 0.4
}

update_x :: proc(world: ^World, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)

	// if vx > threshold move it
	if abs(vx[now]) >= 4 {
		side := rand.choice([]int{-1, 1})
		for attempt in 1 ..= 2 {
			if attempt == 2 {
				side *= -1
			}
			// try falling diagonal first then slide to the side
			for dy in ([]int{+1, 0}) {
				to := idx(x + side, y + dy)
				if is_outside(x + side, y + dy) {
					continue
				}
				if grid[to] != .Empty {
					continue
				}
				vx[to] = vx[now] * 0.5
				vy[to] = vy[now] * 0.2
				move_cell(world, to, now)
				return true
			}
		}
	}
	return false
}
update_y :: proc(world: ^World, x, y: int) -> bool {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)

	step := clamp(int(vy[now]), 1, MAX_SAND_STEP)
	target_y := y
	for s in 1 ..= step {
		next_y := y + s
		next := idx(x, next_y)
		// move half an energy from vy to vx
		if is_outside(x, next_y) {
			break
		}
		// when hit hard surface. move half an energy from vy to vx
		if grid[next] != .Empty {
			break
		}
		target_y = next_y
	}
	if target_y != y {
		next := idx(x, target_y)
		vy[next] = vy[now]
		vx[next] = vx[now]
		move_cell(world, next, now)
		return true
	}
	return false
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
