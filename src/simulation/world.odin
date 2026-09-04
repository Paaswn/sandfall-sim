package simulation
import "../profiling"
import "core:log"
import "core:math/rand"
import "core:prof/spall"
import rl "vendor:raylib"


create_world :: proc(world: ^World) {
	world.tick = 0
	world.vel_x = make([]f32, World_Size)
	world.vel_y = make([]f32, World_Size)
	world.grid = make([]Material, World_Size)
	world.color = make([]rl.Color, World_Size)
	world.chunks = make([]Chunk, Width_In_Chunk * Height_In_Chunk)
	world.updated = make([]u32, World_Size)
	world.side = make([]int, World_Size)
	world.particles = make([dynamic]Particle, 0, 128)
	world.config = load_world_config(Config_Path)
	world.movement = make([dynamic][4]int, 0, World_Size)
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
	delete(world.movement)
}

idx :: proc {
    idx_xy,
    idx_vec
}

@(private="file")
idx_xy :: proc(x, y: int) -> int {
	return y * World_Width + x
}

@(private="file")
idx_vec :: proc(pos: World_Pos) -> int {
	return pos.y * World_Width + pos.x
}
world_index :: proc {
    world_index_from_xy,
    world_index_from_vec
}

@(private="file")
world_index_from_vec :: proc(pos: World_Pos) -> (index: int, inside: bool) {
	inside = !is_outside(pos.x, pos.y)
	index = idx(pos.x, pos.y)
	return
}

@(private="file")
world_index_from_xy :: proc(x, y: int) -> (index: int, inside: bool) {
	inside = !is_outside(x, y)
	index = idx(x, y)
	return
}

is_outside :: proc {
	is_outside_vec,
	is_outside_xy
}
@(private="file")
is_outside_vec :: proc(pos: World_Pos) -> bool {
	return pos.x < 0 || pos.y < 0 || pos.x > World_Width - 1 || pos.y > World_Height - 1
}
@(private="file")
is_outside_xy :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > World_Width - 1 || y > World_Height - 1
}


circle_brush_spawn :: proc(world: ^World, o: World_Pos, r: int, material: Material) {
	for x in o.x - r ..= o.x + r {
		for y in o.y - r ..= o.y + r {
			if is_outside(x, y) {
				continue
			}
			dx := x - o.x
			dy := y - o.y
			if dx * dx + dy * dy < r * r {
				spawn_material(world, material, { x, y })
			}
		}
	}
}

/*
	 
*/ 
spawn_material :: proc(world: ^World, material: Material, pos: World_Pos) {
	@(static) total_spawn: u64 = 0
	i := idx(pos)
	if world.grid[i] == material do return
	world.updated[i] = world.tick
	cpos := to_chunk_pos(pos)
	chunk := get_chunk(world.chunks, cpos)
	activate_chunk(world, chunk, pos)

	if world.config[material].type == .Liquid {
		world.side[i] = random_side()
	}
	world.vel_x[i] = 0
	world.vel_y[i] = 1
	world.grid[i] = material
	world.color[i] = get_material_color(material, pos, total_spawn)
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
/* 
	MOVE material, color, active state

	RESET old position values, old velocity values

	**DOESN'T MOVE VELOCITY**
*/ 
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
			c := get_chunk(world.chunks, Chunk_Pos{ x, y })
			if chunk_active(c, world.tick) {
				update_context := Update_Context{c, 0, {x,y}, {}, {} }
				update_region(world, &update_context)
			} else {
				c.next_bound = nil
			}
		}
	}
}

update_region :: proc(world: ^World, uctx: ^Update_Context)  {
	when profiling.PROFILE {
		spall.SCOPED_EVENT(&profiling.profiler, &profiling.prof_buffer, #procedure)
	}
    updated := false
	bound, ok := uctx.chunk.next_bound.?
	uctx.chunk.next_bound = nil
	min_y := bound.y
	for ly := bound.y2; ly >= min_y; ly -= 1 {
		start_lx, end_lx, step_lx := bound.x, bound.x2 + 1, 1
		if world.tick % 2 != 0 {
			start_lx = bound.x2
			end_lx = bound.x - 1
			step_lx = -1
		}
		for lx := start_lx; lx != end_lx; lx += step_lx {
			lpos := Local_Pos{lx , ly}
			pos := to_world_pos(uctx.cpos, lpos)
			if is_outside(pos) do continue
			uctx.now = idx(pos)
			uctx.lpos = lpos
			uctx.wpos = pos
			
			if update_cell(world, uctx){
				mark_dirty(world, uctx^)
				updated = true
				if ly == min_y {
					new_y := max(ly - 1, 0)
					update_bound(uctx.chunk, Local_Pos{lx, new_y})
					min_y = new_y
				}
			} else if chunk_active(uctx.chunk, world.tick) && world.grid[uctx.now] != .Empty {
				update_bound(uctx.chunk, uctx.lpos)
			}
		}
	}
}


update_cell :: proc(world: ^World, uctx: ^Update_Context) -> bool {
	now := uctx.now
	if world.tick == world.updated[now] do return false
	config := world.config[world.grid[now]]
	if is_empty(world.grid, now) || is_hard(world.grid, now) {
		world.vel_x[now] = 0
		world.vel_y[now] = 0
		return false
	}
	if is_dead(world, uctx.wpos) {
		// vy[now] *= config.damp
		return false // skip possible dead cell
	}
	mat_type := config.type
	#partial switch mat_type {
	case .Powder:
		apply_gravity(world, config, Powder, now)
		if powder_move_down(world, config, uctx) do return true
		if powder_move_diagonal(world, config, uctx) do return true
		if powder_move_side(world, config, uctx) do return true
	case .Liquid:
		apply_gravity(world, config, Liquid, now)
		if liquid_move(world, config, uctx) do return true
		if liquid_move_diagonal(world, config, uctx) do return true
		if liquid_move_side(world, config, uctx) do return true
	}
	return false
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

is_dead :: proc(world: ^World, wpos: World_Pos) -> bool {
	x := wpos.x
	y := wpos.y
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

material_at :: proc(world: ^World, i: int) -> Material {
    assert(i < World_Size && i >= 0)
    return world.grid[i]
}