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
	Cement,
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


circle_brush_spawn :: proc(world: ^World, ox, oy, r: int, material: Material) {
	for x in ox - r ..= ox + r {
		for y in oy - r ..= oy + r {
			if is_outside(x, y) {
				continue
			}
			dx := x - ox
			dy := y - oy
			if dx * dx + dy * dy < r * r {
				spawn_material(world, material, x, y)
			}
		}
	}
}
brush_spawn :: proc(world: ^World, se: Spawn_Event) {
    dx := abs(se.x1 - se.x0)
	dy := -abs(se.y1 - se.y0)
    
	sx := 1
	if se.x0 >= se.x1 do sx = -1
    
	sy := 1
	if se.y0 >= se.y1 do sy = -1
    
	err := dx + dy
    
	x := se.x0
	y := se.y0
    
	for {
		circle_brush_spawn(world, x, y, se.r, se.material)
    
		if x == se.x1 && y == se.y1 {
			break
		}
    
		e2 := 2 * err
    
		if e2 >= dy {
			err += dy
			x += sx
		}
    
		if e2 <= dx {
			err += dx
			y += sy
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
// only move material, color, and reset old position values
// **doesn't move velocity**
move_cell :: proc(world: ^World, to, now: int) {
	world.grid[to] = world.grid[now]
	world.color[to] = world.color[now]
	world.grid[now] = .Empty
	world.color[now] = get_material_base_color(.Empty)
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
	if grid[now] == .Empty || grid[now] == .Cement { 	// skip expensive calc for empty cell immediately
		// reset velocity for empty cell to 0. This is just a guardrail, normally every moved cell will set their old vel to 0
		// build_pixel already handle render empty pixel so no need to set here
		active[now] = false
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
	if move_down(world, x, y) do return
	if move_diagonal(world, x, y) do return
	if move_horizontal(world, x, y) do return
	vy[now] *= RESTING_DAMPING
	vx[now] *= RESTING_DAMPING
}

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
		vx[to] = vx[now] * DIAGONAL_X_TRANSFER
		vy[to] = vy[now] * DIAGONAL_Y_TRANSFER
		wake_neighbor(world, x + side, y + 1, 1)
		move_cell(world, to, now)
		return true
	}
	return false
}

move_horizontal :: proc(world: ^World, x, y: int) -> bool {
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

move_down :: proc(world: ^World, x, y: int) -> bool {
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
				vx[now] += vy[now] * IMPACT_TO_SIDE
			} else {
				vx[now] -= vy[now] * IMPACT_TO_SIDE
			}
			vy[now] *= Y_DAMP_ON_HIT
			break
		}
		next := idx(x, next_y)
		if is_solid(grid, next) { 	// in case we stuck we will transfer energy right here
			if random_side() > 0 {
				vx[next] += vy[now] * NEIGHBOR_TRANSFER
				vx[now] += vy[now] * IMPACT_TO_SIDE
			} else {
				vx[next] -= vy[now] * NEIGHBOR_TRANSFER
				vx[now] -= vy[now] * IMPACT_TO_SIDE
			}
			vy[now] *= Y_DAMP_ON_HIT
			break
		}
		wake_neighbor(world, x, next_y, 1)
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

wake_neighbor :: proc(world: ^World, origin_x, origin_y, off: int) {
	sx := math.max(0, origin_x - off)
	sy := math.max(0, origin_y - off)
	ex := math.min(WIDTH - 1, origin_x + off)
	ey := math.min(HEIGHT - 1, origin_y + off)
	for y in sy ..= ey {
		for x in sx ..= ex {
			check := idx(x, y)
			world.active[check] = true
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
	return grid[idx] == .Sand || grid[idx] == .Cement
}

is_solid_and_sleep :: proc(active: []bool, grid: []Material, idx: int) -> bool {
	return is_solid(grid, idx) && !active[idx]
}
random_side :: proc() -> int {
	return int(rand.uint32() & 1) * 2 - 1
}
