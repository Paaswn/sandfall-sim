package simulation
import "../profiling"
import "core:fmt"
import "core:math/rand"
import "core:prof/spall"
import "core:math"

World :: struct {
	tick:      u32,
	vel_x:     []f32,
	vel_y:     []f32,
	grid:      []Cell,
	chunks:    []Chunk,
	particles: [dynamic]Particle,
	config:    Simulation_Config,
	update_tick: []u32,
	frame:     []Color,
	movement:  [dynamic][4]int,
}

create_world :: proc(world: ^World) {
	world.tick = 0
	world.vel_x = make([]f32, World_Size)
	world.vel_y = make([]f32, World_Size)
	world.grid = make([]Cell, World_Size)
	world.chunks = make([]Chunk, Width_In_Chunk * Height_In_Chunk)
	world.particles = make([dynamic]Particle, 0, 128)
	load_world_config(Config_Path, &world.config)
	world.frame = make([]Color, World_Size)
	world.movement = make([dynamic][4]int, 0, World_Size)
	world.update_tick = make([]u32, World_Size)
}

delete_world :: proc(world: ^World) {
	delete(world.vel_x)
	delete(world.vel_y)
	delete(world.grid)
	delete(world.chunks)
	delete(world.particles)
	delete(world.movement)
	delete(world.config)
	delete(world.frame)
	delete(world.update_tick)
	delete(world.config)
}

idx :: proc {
	idx_xy,
	idx_vec,
}

@(private = "file")
idx_xy :: proc(x, y: int) -> int {
	return y * World_Width + x
}

@(private = "file")
idx_vec :: proc(pos: World_Pos) -> int {
	return pos.y * World_Width + pos.x
}
world_index :: proc {
	world_index_xy,
	world_index_vec,
}

@(private = "file")
world_index_vec :: proc(pos: World_Pos) -> (index: int, inside: bool) {
	inside = !is_outside(pos.x, pos.y)
	index = idx(pos.x, pos.y)
	return
}

@(private = "file")
world_index_xy :: proc(x, y: int) -> (index: int, inside: bool) {
	inside = !is_outside(x, y)
	index = idx(x, y)
	return
}

is_outside :: proc {
	is_outside_vec,
	is_outside_xy,
}
@(private = "file")
is_outside_vec :: proc(pos: World_Pos) -> bool {
	return pos.x < 0 || pos.y < 0 || pos.x > World_Width - 1 || pos.y > World_Height - 1
}
@(private = "file")
is_outside_xy :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > World_Width - 1 || y > World_Height - 1
}


circle_brush_spawn :: proc(world: ^World, o: World_Pos, r: int, id: Material_ID) {
	for x in o.x - r ..= o.x + r {
		for y in o.y - r ..= o.y + r {
			if is_outside(x, y) {
				continue
			}
			dx := x - o.x
			dy := y - o.y
			if dx * dx + dy * dy < r * r {
				spawn_material(world, id, {x, y})
			}
		}
	}
}

/*
	This function will be called before world's tick has advanced but after world's grid has updated
*/
spawn_material :: proc(world: ^World, id: Material_ID, pos: World_Pos) {
	i := idx(pos)
	if (id_at(world^, i) == id) do return

	cell: Cell
	activate_chunk(world, to_chunk_pos(pos), pos)
	if type_of_id_match(world^, id, .Liquid){
		cell.side = i8(random_side())
	}
	cell.id = id
	world.update_tick[i] = world.tick
	cell.variance = 1
	world.frame[i] = get_cell_color(world^, cell)
	world.grid[i] = cell

	world.vel_x[i] = 0
	world.vel_y[i] = 1
}

remove_material :: proc(world: ^World, idx: int) {
	world.grid[idx] = {
		id   = 0,
		side = 0,
	}
	world.vel_x[idx] = 0
	world.vel_y[idx] = 0
}
/*
	MOVE material, color, active state

	RESET old position values, old velocity values

	**DOESN'T MOVE VELOCITY**
*/
move_cell :: proc(world: ^World, to, from: int) {
	world.grid[to], world.grid[from] = world.grid[from], Cell {
			id   = 0,
			side = 0,
	}
	world.update_tick[to] = world.tick
	world.frame[to], world.frame[from] = world.frame[from], {0,0,0,255}
	world.vel_x[from], world.vel_y[from] = 0, 0
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
			c := get_chunk(world.chunks, Chunk_Pos{x, y})
			if chunk_active(c, world.tick) {
				update_context := Update_Context{c, 0, {x, y}, {}, {}}
				update_region(world, &update_context)
			} else {
				c.next_bound = nil
			}
		}
	}
}

update_region :: proc(world: ^World, uctx: ^Update_Context) {
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
			lpos := Local_Pos{lx, ly}
			pos := to_world_pos(uctx.cpos, lpos)
			if is_outside(pos) do continue
			uctx.now = idx(pos)
			uctx.lpos = lpos
			uctx.wpos = pos
			if update_cell(world, uctx^) {
				mark_dirty(world, uctx^)
				updated = true
				if ly == min_y {
					new_y := max(ly - 1, 0)
					update_bound(uctx.chunk, Local_Pos{lx, new_y})
					min_y = new_y
				}
			} else if chunk_active(uctx.chunk, world.tick) &&
			   !is_cell(world^, uctx.now, {.Empty}) {
				update_bound(uctx.chunk, uctx.lpos)
			}
		}
	}
}


update_cell :: proc(world: ^World, uctx: Update_Context) -> (ok: bool) {
	now := uctx.now
	ok = false
	if world.tick == world.update_tick[now] do return 
	if is_empty(world^, now) || is_hard(world^, now) {
		world.vel_x[now] = 0
		world.vel_y[now] = 0
		return 
	}
	if is_dead(world^, uctx.wpos) {
		// vy[now] *= config.damp
		return
	}
	conf := config_of(world^, now)
	#partial switch conf.type {
	case .Powder:
		apply_gravity(world, now, conf, Powder)
		if powder_move_down(world, conf, uctx) do ok = true
		if powder_move_diagonal(world, conf, uctx) do ok = true
		if powder_move_side(world, conf, uctx) do ok = true
	case .Liquid:
		apply_gravity(world, now, conf, Liquid)
		if liquid_move(world, conf, uctx) do ok = true
		if liquid_move_diagonal(world, conf, uctx) do ok = true
		if liquid_move_side(world, conf, uctx) do ok = true
	}
	return
}

apply_gravity :: proc(
	world: ^World,
	now: int,
	conf: Material_Config,
	mt_conf: Material_Type_Config,
) {
	vy := world.vel_y
	vy[now] = math.clamp(vy[now] + conf.down_acc * Dt32, 0, mt_conf.Max_Vy)
}

is_dead :: proc(world: World, wpos: World_Pos) -> bool {
	x := wpos.x
	y := wpos.y
	// up := is_outside(x, y - 1) || is_solid(world, idx(x, y - 1))
	left := is_outside(x - 1, y) || is_solid(world, idx(x - 1, y))
	right := is_outside(x + 1, y) || is_solid(world, idx(x + 1, y))
	bottom := is_outside(x, y + 1) || is_solid(world, idx(x, y + 1))
	return left && right && bottom
}

is_hard :: proc(world: World, idx: int) -> bool {
	return is_cell(world, idx, {.Hard, .Semi_Hard})
}

is_solid :: proc(world: World, idx: int) -> bool {
	return is_cell(world, idx, {.Hard, .Semi_Hard, .Powder})
}

is_liquid :: proc(world: World, idx: int) -> bool {
	return is_cell(world, idx, {.Liquid})
}

is_empty :: proc(world: World, idx: int) -> bool {
	return is_cell(world, idx, {.Empty})
}

random_side :: proc() -> int {
	return int(rand.uint32() & 1) * 2 - 1
}

tick_from_sec :: proc(sec: f32) -> u32 {
	return u32(sec * 60)
}

is_cell :: proc(world: World, i: int, $types: Mat_Types) -> bool {
	for type in types {
		if cell_type_match(world, i, type) do return true
	}
	return false

}
