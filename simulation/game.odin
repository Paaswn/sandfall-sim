package simulation

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
//
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
	if move_side(world, x, y) do return
	vy[now] *= RESTING_DAMPING
	vx[now] *= RESTING_DAMPING
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

is_solid :: proc(grid: []Material, idx: int) -> bool {
	return grid[idx] == .Sand || grid[idx] == .Cement
}

is_solid_and_sleep :: proc(active: []bool, grid: []Material, idx: int) -> bool {
	return is_solid(grid, idx) && !active[idx]
}
random_side :: proc() -> int {
	return int(rand.uint32() & 1) * 2 - 1
}

get_material_color :: proc(mat: Material, x, y: int, salt: u64) -> rl.Color {
	color: rl.Color
	switch mat {
	case .Cement:
		color = random_shade(get_material_base_color(mat), x, y, 20, salt)
	case .Sand:
		color = random_shade(get_material_base_color(mat), x, y, 20, salt)
	case .Empty:
		color = rl.BLACK
	}
	return color
}

get_material_base_color :: proc(mat: Material) -> rl.Color {
	to_return: rl.Color
	switch mat {
	case .Empty:
		to_return = rl.BLACK
	case .Sand:
		to_return = rl.BEIGE
	case .Cement:
		to_return = rl.DARKGRAY
	}
	return to_return
}

random_shade :: proc(base: rl.Color, x, y, variance: int, salt: u64) -> rl.Color {
	// 1. Generate a single random offset for uniform shading
	// If variance is 30, offset will be between -30 and +30
	hash := (x * 73856093) ~ (y * 19349663) ~ int((salt * 83492791))

	offset := (hash % (variance * 2 + 1)) - variance

	// 2. Apply offset and clamp values between 0 and 255 to prevent integer overflow
	return get_new_color(base, offset)
}

get_new_color :: proc(base: rl.Color, offset: int) -> rl.Color {

	new_r := u8(math.clamp(int(base.r) + offset, 0, 255))
	new_g := u8(math.clamp(int(base.g) + offset, 0, 255))
	new_b := u8(math.clamp(int(base.b) + offset, 0, 255))

	return rl.Color{new_r, new_g, new_b, base.a}
}