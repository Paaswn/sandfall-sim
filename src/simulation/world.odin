package simulation

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

World :: struct {
	tick:    u32,
	vel_x:   []f32,
	vel_y:   []f32,
	grid:    []Material, // will be packed into mat id
	color:   []rl.Color,
	chunks:  []Chunk,
	updated: []u32,
	side:    []int, // will be packed inside mat id
	config:  World_Config,
}
World_Config :: [Material]Material_Config

create_world :: proc() -> World {
	return World {
		0,
		make([]f32, World_Width * World_Height),
		make([]f32, World_Width * World_Height),
		make([]Material, World_Width * World_Height),
		make([]rl.Color, World_Width * World_Height),
		make([]Chunk, Chunk_Per_Row * Chunk_Per_Column),
		make([]u32, World_Width * World_Height),
		make([]int, World_Width * World_Height),
		load_world_config(Config_Path),
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
	return y * World_Width + x
}

world_index :: proc(x, y: int) -> (index: int, inside: bool) {
	inside = !is_outside(x, y)
	index = idx(x, y)
	return
}
is_outside :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > World_Width - 1 || y > World_Height - 1
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
	// to_wake_chunk(world, cx, cy - 1)
	cx, cy := to_chunk_pos(x, y)
	wake_chunk_now(world, cx, cy)
	if world.config[material].type == .Liquid {
		world.side[i] = random_side()
	}
	world.vel_x[i] = 2
	world.vel_y[i] = 2
	world.grid[i] = material
	world.color[i] = get_material_color(material, x, y, total_spawn)
	total_spawn += 1
}
// only move material, color, active state, and reset old position values
//
// **doesn't move velocity**
swap_cell :: proc(world: ^World, to, from: int) {
	// move cell
	world.grid[to], world.grid[from] = world.grid[from], world.grid[to]
	world.updated[to] = world.tick
	world.side[to], world.side[from] = world.side[from], world.side[to]
	world.color[to], world.color[from] = world.color[from], world.color[to]
	// move vel
	world.vel_x[from] = world.vel_x[to]
	world.vel_y[from] = world.vel_y[to]

}
move_cell :: proc(world: ^World, to, from: int) {
	world.grid[to], world.grid[from] = world.grid[from], .Empty
	world.updated[to] = world.tick
	world.side[to], world.side[from] = world.side[from], 0
	world.color[to], world.color[from] = world.color[from], get_material_base_color(.Empty)
	world.vel_x[from] = 0
	world.vel_y[from] = 0
}

update :: proc(world: ^World) {
	for cy := Chunk_Per_Column - 1; cy >= 0; cy -= 1 {
			local_row: for local_y := Chunk_Size - 1; local_y >= 0; local_y -= 1 {
				start_cx, end_cx, step_cx := 0, Chunk_Per_Row, 1 // X chunk for-loop setup
				start_lx, end_lx, step_lx := 0, Chunk_Size, 1 // local X for-loop loop setup
				if world.tick % 2 != 0 {
					// chunk X v
					start_cx = Chunk_Per_Row - 1
					end_cx = -1
					step_cx = -1
					// local X v
					start_lx = Chunk_Size - 1
					end_lx = -1
					step_lx = -1
				}
				for cx := start_cx; cx != end_cx; cx += step_cx {
					chunk := chunk_from_chunk_pos(world.chunks, cx, cy)
					if !is_chunk_active(chunk, world.tick) {
						continue
					}
					 for local_x := start_lx; local_x != end_lx; local_x += step_lx {
						x, y := to_world_pos(cx, cy, local_x, local_y)
						if y >= World_Height { 	// outside in this scope mean local y is too high
							continue local_row
						}
						if x >= World_Width {
							continue
						}
						i := idx(x, y)
						before := world.grid[i]
						if update_cell_vertical(world, x, y) {
							after := world.grid[i]
							chunk.last_updated_tick = world.tick
							chunk.to_update_tick = world.tick + 1
							if local_y == 0 && before != after {
								wake_chunk_now(world, cx, cy - 1)
							}
							if local_x == 0 && before != after {
								wake_chunk_now(world, cx - 1, cy)
							}
							if local_x == Chunk_Size - 1 && before != after {
								wake_chunk_now(world, cx + 1, cy)
							}
						}

					}
				}
				for cx := start_cx; cx != end_cx; cx += step_cx {
					chunk := chunk_from_chunk_pos(world.chunks, cx, cy)
					if !is_chunk_active(chunk, world.tick) {
						continue
					}
					 for local_x := start_lx; local_x != end_lx; local_x += step_lx {
						x, y := to_world_pos(cx, cy, local_x, local_y)
						if y >= World_Height { 	// outside in this scope mean local y is too high
							continue local_row
						}
						if x >= World_Width {
							continue
						}
						i := idx(x, y)
						before := world.grid[i]
						if update_cell_side(world,x ,y) {
							after := world.grid[i]
							chunk.last_updated_tick = world.tick
							chunk.to_update_tick = world.tick + 1
							if local_y == 0 && before != after {
								wake_chunk_now(world, cx, cy - 1)
							}
							if local_x == 0 && before != after {
								wake_chunk_now(world, cx - 1, cy)
							}
							if local_x == Chunk_Size - 1 && before != after {
								wake_chunk_now(world, cx + 1, cy)
							}
						}

					}
				}
			}
		}
}

Update_Context :: struct {
	mat_type : Material_Type,
	now : int,
	config : Material_Config,
}

prepare_cell_update :: proc(world: ^World, x, y: int) -> (ctx: Update_Context, ok: bool) {
	now := idx(x, y) // always in border no need to check
	if world.tick == world.updated[now] do return {} , false
	vx := world.vel_x
	vy := world.vel_y
	grid := world.grid
	config := world.config[grid[now]]
	if is_empty(grid, now) || is_hard(grid, now) {
		vx[now] = 0
		vy[now] = 0
		return {}, false
	}
	if is_dead(world, x, y) {
		// vy[now] *= config.damp
		return {}, false // skip possible dead cell
	}
	mat_type := config.type
	return {mat_type, now, config}, true
}

apply_gravity :: proc(world: ^World, mat_config: Material_Config, mat_type_config: Material_Type_Config, now: int) {
	vx := world.vel_x
	vy := world.vel_y
	vy[now] = rl.Clamp(vy[now] + mat_config.down_acc * f32(Dt), 0, mat_type_config.Max_Vy)
	vx[now] = rl.Clamp(vx[now], 0, mat_type_config.Max_Vx)
}

update_cell_vertical :: proc(world: ^World, x, y: int) -> bool {
	if ctx, ok := prepare_cell_update(world,x ,y); ok {
		now := ctx.now
		config := ctx.config
		mat_type := ctx.mat_type
		#partial switch mat_type {
		case .Powder:
			apply_gravity(world, config, Powder ,now)
			if powder_move_down(world, config, x, y) do return true
		case .Liquid:
			apply_gravity(world, config, Liquid, now)
			if liquid_move_down(world, config, x, y) do return true
		}
	}
	return false
}

update_cell_side :: proc(world: ^World, x, y: int) -> bool {
	if ctx, ok := prepare_cell_update(world,x ,y); ok {
		now := ctx.now
		config := ctx.config
		mat_type := ctx.mat_type
		#partial switch mat_type {
		case .Powder:
			if powder_move_diagonal(world, config, x, y) do return true
			if powder_move_side(world, config, x, y) do return true
		case .Liquid:
			if liquid_move_diagonal(world, config, x, y) do return true
			if liquid_move_side(world,config,  x, y) do return true
		}
	}
	return false
}

is_dead :: proc(world: ^World, x, y: int) -> bool {
	// up := is_outside(x, y - 1) || is_solid(world, idx(x, y - 1))
	left := is_outside(x - 1, y) || is_solid(world, idx(x - 1, y))
	right := is_outside(x + 1, y) || is_solid(world, idx(x + 1, y))
	bottom := is_outside(x, y + 1) || is_solid(world, idx(x, y + 1))
	return left && right && bottom
}

is_hard :: proc(grid: []Material, idx: int) -> bool {
	return grid[idx] == .Cement
}
is_solid :: proc(world: ^World, idx: int) -> (ok: bool) {
	if is_hard(world.grid, idx) do return true
	if world.config[world.grid[idx]].type == .Powder do return true
	return false
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

get_material_color :: proc(mat: Material, x, y: int, salt: u64) -> (color: rl.Color) {
	#partial switch mat {
	case .Empty:
		color = rl.BLACK
	case:
		color = random_shade(get_material_base_color(mat), x, y, 20, salt)
	case .Water:
		color = rl.DARKBLUE
	}
	return
}

get_material_base_color :: proc(mat: Material) -> (color: rl.Color ) {
	switch mat {
	case .Empty:
		color = rl.BLACK
	case .Sand:
		color = rl.BEIGE
	case .Dirt:
		color = rl.BROWN
	case .Cement:
		color = rl.DARKGRAY
	case .Water:
		color = rl.BLUE
	}
	return
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
