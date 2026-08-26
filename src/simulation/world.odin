package simulation

import "../profiling"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:prof/spall"
import "core:strings"
import rl "vendor:raylib"

World :: struct {
	tick:      u32,
	vel_x:     []f32,
	vel_y:     []f32,
	grid:      []Material, // will be packed into mat id
	color:     []rl.Color,
	chunks:    []Chunk,
	updated:   []u32,
	side:      []int, // will be packed inside mat id
	particles: [dynamic]Particle,
	config:    World_Config,
}


World_Config :: [Material]Material_Config

create_world :: proc() -> World {
	return World {
		0,
		make([]f32, World_Width * World_Height),
		make([]f32, World_Width * World_Height),
		make([]Material, World_Width * World_Height),
		make([]rl.Color, World_Width * World_Height),
		make([]Chunk, Width_In_Chunk * Height_In_Chunk),
		make([]u32, World_Width * World_Height),
		make([]int, World_Width * World_Height),
		make([dynamic]Particle, 128),
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
	delete(world.particles)
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

spawn_material :: proc(world: ^World, material: Material, x, y: int) {
	@(static) total_spawn: u64 = 0
	i := idx(x, y)
	if world.grid[i] == material do return
	world.updated[i] = world.tick - 1
	cx, cy := to_chunk_pos(x, y)
	chunk := chunk_from_chunk_pos(world.chunks, cx, cy)
	put_chunk_in_queue(world, chunk, x, y)

	if world.config[material].type == .Liquid {
		world.side[i] = random_side()
	}
	world.vel_x[i] = 0
	world.vel_y[i] = 2
	world.grid[i] = material
	world.color[i] = get_material_color(material, x, y, total_spawn)
	total_spawn += 1
}
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
remove_material :: proc(world: ^World, idx: int) {
	world.color[idx] = get_material_base_color(.Empty)
	world.grid[idx] = .Empty
	world.side[idx] = 0
	world.vel_x[idx] = 0
	world.vel_y[idx] = 0
}
// only move material, color, active state, and reset old position values
//
// **doesn't move velocity**
move_cell :: proc(world: ^World, to, from: int) {
	world.grid[to], world.grid[from] = world.grid[from], .Empty
	world.updated[to] = world.tick
	world.side[to], world.side[from] = world.side[from], 0
	world.color[to], world.color[from] = world.color[from], get_material_base_color(.Empty)
	world.vel_x[from] = 0
	world.vel_y[from] = 0
}


update_grid :: proc(world: ^World) {
	when profiling.PROFILE {
		spall.SCOPED_EVENT(&profiling.profiler, &profiling.prof_buffer, #procedure)
	}
	for y := Height_In_Chunk - 1; y >= 0; y -= 1 {
		start_x, end_x, step_x := 0, Width_In_Chunk, 1
		if world.tick % 2 == 0 {
			start_x = Width_In_Chunk - 1
			end_x = -1
			step_x = -1
		}
		for x := start_x; x != end_x; x += step_x {
			ci := chunk_index_from_chunk_pos(x, y)
			if chunk_active(&world.chunks[ci], world.tick) {
				update_region(world, ci)
			} else {
				world.chunks[ci].active_bound = nil
			}
		}
	}
	// #reverse for &c, i in c_man.chunks {
	// 	if chunk_active(&c, world.tick) {
	// 		loop_through_region(world, i)
	// 	}
	// }
}


update_region :: proc(world: ^World, cidx: int) {
	updated := false
	cx, cy := chunk_idx_to_chunk_pos(cidx)
	chunk := &world.chunks[cidx]
	bound, ok := chunk.active_bound.?
	if !ok do return
	if world.tick - chunk.last_bound_reset >= 8 {
		chunk.active_bound = nil
		chunk.last_bound_reset = world.tick
	}
	min_y := bound.y
	for ly := bound.y2; ly >= min_y; ly -= 1 {
		start_lx, end_lx, step_lx := bound.x, bound.x2, 1
		if world.tick % 2 != 0 {
			// local X v
			start_lx = bound.x2 - 1
			end_lx = bound.x - 1
			step_lx = -1
		}
		for lx := start_lx; lx != end_lx; lx += step_lx {
			x, y := to_world_pos(cx, cy, lx, ly)
			if y >= World_Height {
				continue
			}
			if x >= World_Width {
				continue
			}

			if update_cell_vertical(world, x, y) || update_cell_side(world, x, y) {
				updated = true
				// after := world.grid[i]
				if ly == min_y {
					new_y := max(ly - 1, 0)
					update_bound_local(chunk, lx, new_y)
					min_y = new_y
				}
				if ly == 0 {
					put_chunk_in_queue(world, cx, cy - 1, x, y - 1)
				}
				if lx == 0 {
					put_chunk_in_queue(world, cx - 1, cy, x - 1, y)
				}
				if lx == Chunk_Size - 1 {
					put_chunk_in_queue(world, cx + 1, cy, x + 1, y)
				}
			}
		}
	}
	if updated {
		chunk.last_updated_tick = world.tick
	}

}

Update_Context :: struct {
	mat_type: Material_Type,
	now:      int,
	config:   Material_Config,
}

prepare_cell_update :: proc(world: ^World, x, y: int) -> (ctx: Update_Context, ok: bool) {
	now := idx(x, y) // always in border no need to check
	if world.tick == world.updated[now] do return {}, false
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

apply_gravity :: proc(
	world: ^World,
	mat_config: Material_Config,
	mat_type_config: Material_Type_Config,
	now: int,
) {
	vx := world.vel_x
	vy := world.vel_y
	vy[now] = rl.Clamp(vy[now] + mat_config.down_acc * Dt32, 0, mat_type_config.Max_Vy)
	// vx[now] = rl.Clamp(vx[now], 0, mat_type_config.Max_Vx)
}

update_cell_vertical :: proc(world: ^World, x, y: int) -> bool {
	if ctx, ok := prepare_cell_update(world, x, y); ok {
		now := ctx.now
		config := ctx.config
		mat_type := ctx.mat_type
		#partial switch mat_type {
		case .Powder:
			apply_gravity(world, config, Powder, now)
			powder_move_down(world, config, x, y) or_return
		case .Liquid:
			apply_gravity(world, config, Liquid, now)
			// liquid_move_down(world, config, x, y) or_return
			liquid_move(world, config, x, y) or_return
		}
	}
	return false
}

update_cell_side :: proc(world: ^World, x, y: int) -> bool {
	if ctx, ok := prepare_cell_update(world, x, y); ok {
		now := ctx.now
		config := ctx.config
		mat_type := ctx.mat_type
		#partial switch mat_type {
		case .Powder:
			if powder_move_diagonal(world, config, x, y) do return true
			if powder_move_side(world, config, x, y) do return true
		case .Liquid:
			if liquid_move_diagonal(world, config, x, y) do return true
			if liquid_move_side(world, config, x, y) do return true
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

tick_from_sec :: proc(sec: f32) -> u32 {
	return u32(sec * 60)
}
