package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

World :: struct {
	vel_x:  []f32,
	vel_y:  []f32,
	grid:   []Material,
	color:  []rl.Color,
	active: []bool,
}

Material :: enum u8 {
	Empty,
	Sand,
}

create_world :: proc() -> World {

	return World {
		make([]f32, WIDTH * HEIGHT),
		make([]f32, WIDTH * HEIGHT),
		make([]Material, WIDTH * HEIGHT),
		make([]rl.Color, WIDTH * HEIGHT),
		make([]bool, WIDTH * HEIGHT),
	}
}

delete_world :: proc(world: ^World) {
	delete(world.vel_x)
	delete(world.vel_y)
	delete(world.grid)
	delete(world.color)
	delete(world.active)
}

idx :: proc(x, y: int) -> int {
	idx := y * WIDTH + x
	return idx
}

is_outside :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > WIDTH - 1 || y > HEIGHT - 1
}


circle_brush_spawn :: proc(world: ^World, se: Spawn_Event) {
	for y := se.y + se.r - 1; y >= se.y - se.r; y -= 1 {
		for x in se.x - se.r ..= se.x + se.r {
			if is_outside(x, y) {
				continue
			}
			dx := x - se.x
			dy := y - se.y
			if dx * dx + dy * dy <= se.r * se.r {
				spawn_material(world, se.material, x, y)
			}
		}
	}
}

total_spawn: u64 = 0
spawn_material :: proc(world: ^World, material: Material, x, y: int) {
	i := idx(x, y)
	if world.grid[i] == material do return
	total_spawn += 1
	world.grid[i] = material
	world.color[i] = get_material_color(material, x, y, total_spawn)
}
// only move material, and color
// **doesn't move velocity**
move_cell :: proc(world: ^World, to, now: int) {
	world.grid[to] = world.grid[now]
	world.color[to] = world.color[now]
	world.grid[now] = .Empty
	world.vel_x[now] = 0
	world.vel_y[now] = 0
}

cell_should_sleep :: proc(world: ^World, x, y: int) -> bool {
	vx := world.vel_x
	vy := world.vel_y
	grid := world.grid
	active := world.active
	now := idx(x, y)
	// check cell speed
	vel_sqr := vx[now] * vx[now] + vy[now] * vy[now]
	if vel_sqr > SLEEP_EPSILON {
		return false
	}
	// if below is border go to sleep
	if is_outside(x, y + 1) {
		return true
	}
	// check if falling
	below := idx(x, y + 1)
	if !is_solid_and_sleep(active, grid, below) {
		return false
	}

	// check if being held by solid cell
	if is_outside(x - 1, y + 1) || is_outside(x + 1, y + 1) {
		return true
	}
	below_left := idx(x - 1, y + 1)
	below_right := idx(x + 1, y + 1)
	if (is_solid_and_sleep(active, grid, below_left)) ||
	   (is_solid_and_sleep(active, grid, below_right)) {
		return true
	}

	return true

}
update :: proc(world: ^World, tick: int) {
	for y := HEIGHT - 1; y >= 0; y -= 1 {
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

update_row :: proc(world: ^World, x, y: int) {
	now := idx(x, y) // always in border no need to check
	vx := world.vel_x
	vy := world.vel_y
	grid := world.grid
	active := world.active
	if grid[now] == .Empty { 	// skip expensive calc for empty cell immediately
		// reset velocity for empty cell to 0. This is just a guardrail, normally every moved cell will set their old vel to 0
		// build_pixel already handle render empty pixel so no need to set here
		vx[now] = 0
		vy[now] = 0
		return
	}
	// try waking cell up first
	if !is_outside(x, y + 1) && grid[idx(x, y + 1)] == .Empty {
		active[now] = true
	}
	// if cell do not active, skip
	if !active[now] do return
	if cell_should_sleep(world, x, y) {
		// if cell should active then skip
		active[now] = false
		return
	}
	vy[now] += GRAVITY * f32(DT) // apply gravity to an active cell
	if update_y(world, x, y) do return
	if update_x(world, x, y) do return
	vy[now] *= 0.5
	vx[now] *= 0.5
}

update_x :: proc(world: ^World, x, y: int) -> bool {
	grid := world.grid
	vx := world.vel_x
	now := idx(x, y)
	vx_amp := abs(vx[now])
	if vx_amp > X_THRESHOLD {
		side := int(vx[now] / vx_amp)
		// try fall diag first then horizontal
		for h in ([]int{-1, 0}) {
			if is_outside(x + side, y + h) {
				continue
			}
			to := idx(x + side, y + h)
			if is_solid(grid, to) { 	// maybe add energy
				continue
			}
			wake_neighbor(world, x, y, x + side, y + h, 1)
			move_cell(world, to, now)
			return true

		}
	}
	return false
}

update_y :: proc(world: ^World, x, y: int) -> bool {
	vy := world.vel_y
	vx := world.vel_x
	now := idx(x, y)
	grid := world.grid
	steps := int(math.clamp(vy[now], 1, MAX_STEP_Y))
	target_y := y
	for s in 1 ..= steps {
		next_y := y + s
		if is_outside(x, next_y) {
			if random_side() > 0 {
				vx[now] += vy[now] * 0.9
			} else {
				vx[now] -= vy[now] * 0.9
			}
			vy[now] *= 0.5
			break
		}
		next := idx(x, next_y)
		if is_solid(grid, next) { 	// in case we stuck we will transfer energy right here
			if random_side() > 0 {
				vx[next] += vy[now] * 0.3
				vx[now] += vy[now] * 0.9
			} else {
				vx[next] -= vy[now] * 0.3
				vx[now] -= vy[now] * 0.9
			}
			vy[now] *= 0.5
			break
		}
		wake_neighbor(world, x, y, x, next_y, 1)
		target_y = next_y
	}
	if target_y != y {
		to := idx(x, target_y)
		vy[to] = vy[now]
		vx[to] = vx[now]
		move_cell(world, to, now)
		return true
	}
	return false
}

wake_neighbor :: proc(world: ^World, start_x, start_y, origin_x, origin_y, off: int) {
	start_x := math.max(0, origin_x - off)
	start_y := math.max(0, origin_y - off)
	end_x := math.min(WIDTH - 1, origin_x + off)
	end_y := math.min(HEIGHT - 1, origin_y + off)
	for y in start_y ..= end_y {
		for x in start_x ..= end_x {
			check := idx(x, y)
			if x != origin_x && y != origin_y {
				start := idx(start_x, start_y)
				world.vel_y[check] += world.vel_y[start] * NEIGHBOR_TRANSFER
				if x < origin_x {
					world.vel_x[check] += world.vel_y[start] * NEIGHBOR_TRANSFER
					world.vel_x[check] += world.vel_x[start] * NEIGHBOR_TRANSFER * 4
				} else if x > origin_x {
					world.vel_x[check] -= world.vel_y[start] * NEIGHBOR_TRANSFER
					world.vel_x[check] -= world.vel_x[start] * NEIGHBOR_TRANSFER * 4
				}
				world.active[check] = true
			}
		}
	}
}

// deprecated
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

is_solid :: proc(grid: []Material, idx: int) -> bool {
	return grid[idx] == .Sand
}

is_solid_and_sleep :: proc(active: []bool, grid: []Material, idx: int) -> bool {
	return is_solid(grid, idx) && !active[idx]
}
random_side :: proc() -> int {
	return int(rand.uint32() & 1) * 2 - 1
}
