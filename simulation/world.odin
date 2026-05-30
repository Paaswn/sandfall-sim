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
	chunks: []Chunk,
}

Material :: enum u8 {
	Empty,
	Sand,
	Cement,
	Water,
}

create_world :: proc() -> World {

	return World {
		make([]f32, Width * Height),
		make([]f32, Width * Height),
		make([]Material, Width * Height),
		make([]rl.Color, Width * Height),
		make([]Chunk, Width * Height / Chunk_Size),
	}
}

delete_world :: proc(world: ^World) {
	delete(world.vel_x)
	delete(world.vel_y)
	delete(world.grid)
	delete(world.color)
	delete(world.chunks)
}

idx :: proc(x, y: int) -> int {
	return y * Width + x
}

is_outside :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > Width - 1 || y > Height - 1
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

brush_line :: proc(world: ^World, se: Spawn_Event) {
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
	cx, cy := to_chunk_pos(x, y)
	to_wake_chunk(world.chunks, cx, cy)
	total_spawn += 1
	world.grid[i] = material
	world.color[i] = get_material_color(material, x, y, total_spawn)
}
// only move material, color, active state, and reset old position values
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


update :: proc(world: ^World, tick: u64) {
	for cy := Height_Chunk - 1; cy >= 0; cy -= 1 {
		for cx := 0; cx < Width_Chunk; cx += 1 {
			chunk_idx := chunk_idx_by_cpos(cx, cy)
			chunk := get_chunk(world.chunks, chunk_idx)
			chunk.active = chunk.active_next
			if chunk.active {
				update_chunk(world, chunk, cx, cy, tick)
				chunk.active_next = true
				delta_tick := tick - chunk.last_updated_tick
				if delta_tick >= Chunk_Idle_Thresh {
					chunk.active_next = false
				}
			}
		}
	}
}

update_chunk :: proc(world: ^World, chunk: ^Chunk, cx, cy: int, tick: u64) {
	for y := Chunk_Size - 1; y >= 0; y -= 1 {
		if cy == Height_Chunk - 1 && y > Chunk_Size - 4 do continue
		if tick % 2 == 0 {
			for x := 0; x < Chunk_Size; x += 1 {
				wx, wy := to_world_pos(cx, cy, x, y)
				cell := world.grid[idx(wx, wy)]
				if update_cell(world, wx, wy) {
					chunk.last_updated_tick = tick
					if y == 0 && cell != world.grid[idx(wx, wy)] {
						to_wake_chunk(world.chunks, cx, cy - 1)
					}
				}
			}
		} else {
			for x := Chunk_Size - 1; x >= 0; x -= 1 {
				wx, wy := to_world_pos(cx, cy, x, y)
				cell := world.grid[idx(wx, wy)]
				if update_cell(world, wx, wy) {
					chunk.last_updated_tick = tick
					if y == 0 && cell != world.grid[idx(wx, wy)] {
						to_wake_chunk(world.chunks, cx, cy - 1)
					}
				}
			}
		}
	}
}

update_cell :: proc(world: ^World, x, y: int) -> bool {
	now := idx(x, y) // always in border no need to check
	vx := world.vel_x
	vy := world.vel_y
	grid := world.grid
	if is_empty(grid, now) || is_dead(grid, now) do return false
	vy[now] += Gravity * f32(Dt)
	if vy[now] >= Max_Step_Y do vy[now] = Max_Step_Y
	if vx[now] >= Max_Step_X do vy[now] = Max_Step_X
	if move_down(world, x, y) do return true
	if move_diagonal(world, x, y) do return true
	return false
}


is_dead :: proc(grid: []Material, idx: int) -> bool {
	return grid[idx] == .Cement
}
is_solid :: proc(grid: []Material, idx: int) -> bool {
	return grid[idx] == .Sand || grid[idx] == .Cement
}

is_liquid :: proc(grid: []Material, idx: int) -> bool {
	return grid[idx] == .Water
}

is_empty :: proc(grid: []Material, idx: int) -> bool {
	return grid[idx] == .Empty
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
	case .Water:
		color = random_shade(get_material_base_color(mat), x, y, 10, 0)
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
	case .Water:
		to_return = rl.BLUE

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
