package simulation

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"


World_Config :: struct {
	sand: Material_Config,
}

Material :: enum u8 {
	Empty,
	Sand,
	Dirt,
	Cement,
	Water,
}

Material_Type_Config :: struct {
	Max_Vy: f32,
	Max_Vx: f32,
}

Powder :: Material_Type_Config{8.0, 4.0}
Material_Config :: struct {
	down_acc:       f32,
	slide_thresh:   f32,
	side_thresh:    f32,
	friction:       f32,
	damp:           f32,
	impact_to_side: f32,
	impact_thresh:  f32,
	slide_drag:     f32,
	fall_drag:      f32,
}

World :: struct {
	tick:    u64,
	vel_x:   []f32,
	vel_y:   []f32,
	grid:    []Material,
	color:   []rl.Color,
	chunks:  []Chunk,
	updated: []u64,
	side:    []int,
	config:  World_Config,
}

init_config :: proc() -> World_Config {
	return load_world_config(Config_Path)
}

create_world :: proc() -> World {
	Chunk_Count_X :: (Width + Chunk_Size - 1) / Chunk_Size
	Chunk_Count_Y :: (Height + Chunk_Size - 1) / Chunk_Size
	return World {
		0,
		make([]f32, Width * Height),
		make([]f32, Width * Height),
		make([]Material, Width * Height),
		make([]rl.Color, Width * Height),
		make([]Chunk, Chunk_Count_X * Chunk_Count_Y),
		make([]u64, Width * Height),
		make([]int, Width * Height),
		init_config(),
	}
}

delete_world :: proc(world: ^World) {
	delete(world.vel_x)
	delete(world.vel_y)
	delete(world.grid)
	delete(world.color)
	delete(world.chunks)
	delete(world.updated)
	delete(world.side)
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


total_spawn: u64 = 0
spawn_material :: proc(world: ^World, material: Material, x, y: int) {
	i := idx(x, y)
	if world.grid[i] == material do return
	world.updated[i] = world.tick
	cx, cy := to_chunk_pos(x, y)
	to_wake_chunk(world.chunks, cx, cy - 1)
	to_wake_chunk(world.chunks, cx, cy)
	total_spawn += 1
	world.vel_y[i] = 0.5
	world.grid[i] = material
	world.color[i] = get_material_color(material, x, y, total_spawn)
}
// only move material, color, active state, and reset old position values
//
// **doesn't move velocity**
move_cell :: proc(world: ^World, to, now: int) {
	world.updated[to] = world.tick
	world.side[to] = world.side[now]
	world.side[now] = 0
	world.grid[to] = world.grid[now]
	world.color[to] = world.color[now]
	world.grid[now] = .Empty
	world.color[now] = get_material_base_color(.Empty)
	world.vel_x[now] = 0
	world.vel_y[now] = 0
}


update :: proc(world: ^World) {
	for cy := Height_Chunk - 1; cy >= 0; cy -= 1 {
		for cx := 0; cx < Width_Chunk; cx += 1 {
			chunk_idx := chunk_idx_by_cpos(cx, cy)
			chunk := get_chunk(world.chunks, chunk_idx)
			chunk.active = chunk.active_next
			if chunk.active {
				update_chunk(world, chunk, cx, cy, world.tick)
				chunk.active_next = true
				delta_tick := world.tick - chunk.last_updated_tick
				if delta_tick >= Chunk_Idle_Thresh {
					chunk.active_next = false
				}
			}
		}
	}
}

update_chunk :: proc(world: ^World, chunk: ^Chunk, cx, cy: int, tick: u64) {
	for y := Chunk_Size - 1; y >= 0; y -= 1 {
		if cy == Height_Chunk - 1 && y > Chunk_Size - 3 do continue
		start_x, end_x, step_x := 0, Chunk_Size, 1

		if tick % 2 != 0 {
			start_x = Chunk_Size - 1
			end_x = -1
			step_x = -1
		}

		for x := start_x; x != end_x; x += step_x {
			wx, wy := to_world_pos(cx, cy, x, y)

			before := world.grid[idx(wx, wy)]

			if update_cell(world, wx, wy) {
				chunk.last_updated_tick = tick
				now := world.grid[idx(wx, wy)]
				if y == 0 && before != now {
					to_wake_chunk(world.chunks, cx, cy - 1)
				}
				if x == 0 && before != now {
					to_wake_chunk(world.chunks, cx - 1, cy)
				}
				if x == Chunk_Size - 1 && before != now {
					to_wake_chunk(world.chunks, cx + 1, cy)
				}
			}
		}
	}
}

update_cell :: proc(world: ^World, x, y: int) -> bool {
	now := idx(x, y) // always in border no need to check
	if world.tick == world.updated[now] do return false
	vx := world.vel_x
	vy := world.vel_y
	grid := world.grid
	config := world.config

	if is_empty(grid, now) || is_hard(grid, now) {
		vx[now] = 0
		vy[now] = 0
		return false
	}
	if is_dead(grid, x, y) {
		vy[now] *= config.sand.damp
		return false // skip possible dead cell
	}

	#partial switch grid[now] {
	case .Sand:
		vy[now] = rl.Clamp(vy[now] + config.sand.down_acc * f32(Dt), 0, Powder.Max_Vy)
		vx[now] = rl.Clamp(vx[now], -Powder.Max_Vx, Powder.Max_Vx)
		if move_down(world, config.sand, x, y) do return true
		if move_diagonal(world, config.sand, x, y) do return true
		if move_side(world, config.sand, x, y) do return true
	case .Water:
		return false
	}
	return false
}

is_dead :: proc(grid: []Material, x, y: int) -> bool {
	left := is_outside(x - 1, y) || is_solid(grid, idx(x - 1, y))
	right := is_outside(x + 1, y) || is_solid(grid, idx(x + 1, y))
	bottom := is_outside(x, y + 1) || is_solid(grid, idx(x, y + 1))
	return left && right && bottom
}

is_hard :: proc(grid: []Material, idx: int) -> bool {
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
	case .Dirt:
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
	case .Dirt:
		to_return = rl.BROWN
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
