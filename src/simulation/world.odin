package simulation
import "../profiling"
import "core:fmt"
import "core:math/rand"
import "core:prof/spall"
import "core:math"

idx :: proc {
	idx_xy,
	idx_vec,
}

@(private = "file")
idx_xy :: proc(x, y: int) -> int {
	return y * WORLD_WIDTH + x
}

@(private = "file")
idx_vec :: proc(pos: World_Pos) -> int {
	return pos.y * WORLD_WIDTH + pos.x
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
	return pos.x < 0 || pos.y < 0 || pos.x > WORLD_WIDTH - 1 || pos.y > WORLD_HEIGHT - 1
}
@(private = "file")
is_outside_xy :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > WORLD_WIDTH - 1 || y > WORLD_HEIGHT - 1
}

circle_brush_spawn :: proc(sim: ^Simulation, o: World_Pos, r: int, id: Material_ID) {
	for x in o.x - r ..= o.x + r {
		for y in o.y - r ..= o.y + r {
			if is_outside(x, y) {
				continue
			}
			dx := x - o.x
			dy := y - o.y
			if dx * dx + dy * dy < r * r {
				spawn_material(sim, id, {x, y})
			}
		}
	}
}

/*
	This function will be called before world's tick has advanced but after world's grid has updated
*/
spawn_material :: proc(sim: ^Simulation, id: Material_ID, pos: World_Pos) {
	i := idx(pos)
	if (id_at(sim.world, i) == id) do return

	cell := &sim.world[i]
	activate_chunk(sim^, to_chunk_pos(pos), pos)
	cell.id = id
	cell.update_tick = sim.tick
	cell.variance = random_variance(0, len(sim.config[id].color))
	cell.vel = {0, 1}
	if type_of_id_match(sim^, id, .Liquid){
		cell.side = i8(random_side(sim.rng))
	}

	sim.frame[i] = get_cell_color(sim^, cell^)
}

remove_material :: proc(world: ^World, idx: int) {
	world[idx] = {
		id   = 0,
		side = 0,
	}
	world[idx].vel = {0, 0}
}
/*
	MOVE material, color, active state

	RESET old position values, old velocity values

	**DOESN'T MOVE VELOCITY**
*/
move_cell :: proc(sim: Simulation, to, from: int) {
	sim.world[to]  = sim.world[from]
	sim.world[from].id = 0
	sim.world[to].update_tick = sim.tick
	sim.frame[to] = sim.frame[from] 
	sim.frame[from] = {0, 0, 0, 255}
}


update_grid :: proc(sim: ^Simulation) {
	when profiling.PROFILE {
		spall.SCOPED_EVENT(&profiling.profiler, &profiling.prof_buffer, #procedure)
	}
	for y := HEIGHT_IN_CHUNK - 1; y >= 0; y -= 1 {
		start_x, end_x, step_x := 0, WIDTH_IN_CHUNK, 1
		if sim.tick % 2 == 0 {
			start_x = WIDTH_IN_CHUNK - 1
			end_x = -1
			step_x = -1
		}
		for x := start_x; x != end_x; x += step_x {
			c := get_chunk(sim.chunks, Chunk_Pos{x, y})
			if chunk_active(c, sim.tick) {
				update_context := Update_Context{c, 0, {x, y}, {}, {}}
				update_region(sim, &update_context)
			} else {
				c.next_bound = nil
			}
		}
	}
}

update_region :: proc(sim: ^Simulation, uctx: ^Update_Context) {
	when profiling.PROFILE {
		spall.SCOPED_EVENT(&profiling.profiler, &profiling.prof_buffer, #procedure)
	}
	updated := false
	bound, ok := uctx.chunk.next_bound.?
	uctx.chunk.next_bound = nil
	min_y := bound.y
	for ly := bound.y2; ly >= min_y; ly -= 1 {
		start_lx, end_lx, step_lx := bound.x, bound.x2 + 1, 1
		if sim.tick % 2 != 0 {
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
			if update_cell(sim, uctx^) {
				mark_dirty(sim^, uctx^)
				updated = true
				if ly == min_y {
					new_y := max(ly - 1, 0)
					update_bound(uctx.chunk, Local_Pos{lx, new_y})
					min_y = new_y
				}
			} else if chunk_active(uctx.chunk, sim.tick) &&
			   !is_cell(sim^, uctx.now, {.Empty}) {
				update_bound(uctx.chunk, uctx.lpos)
			}
		}
	}
}


update_cell :: proc(sim: ^Simulation, uctx: Update_Context) -> (ok: bool) {
	now := uctx.now
	ok = false
	if sim.tick == sim.world[now].update_tick do return 
	if is_empty(sim^, now) || is_hard(sim^, now) {
	    sim.world[now].vel = {0, 0}
		return 
	}
	if is_dead(sim^, uctx.wpos) {
		// vy[now] *= config.damp
		return
	}
	conf := config_of(sim^, now)
	#partial switch conf.type {
	case .Powder:
		apply_gravity(sim.world, now, conf, POWDER)
		if powder_move_down(sim, conf, uctx) do ok = true
		if powder_move_diagonal(sim, conf, uctx) do ok = true
		if powder_move_side(sim, conf, uctx) do ok = true
	case .Liquid:
		apply_gravity(sim.world, now, conf, LIQUID)
		if liquid_move(sim, conf, uctx) do ok = true
		if liquid_move_diagonal(sim, conf, uctx) do ok = true
		if liquid_move_side(sim, conf, uctx) do ok = true
	}
	return
}

apply_gravity :: proc(
	world: World,
	now: int,
	conf: Material_Config,
	mt_conf: Material_Type_Config,
) {
    vy := world[now].vel.y
	world[now].vel.y = math.clamp(vy + conf.down_acc * DT32, 0, mt_conf.Max_Vy)
}

is_dead :: proc(sim: Simulation, wpos: World_Pos) -> bool {
	x := wpos.x
	y := wpos.y
	// up := is_outside(x, y - 1) || is_solid(world, idx(x, y - 1))
	left := is_outside(x - 1, y) || is_solid(sim, idx(x - 1, y))
	right := is_outside(x + 1, y) || is_solid(sim, idx(x + 1, y))
	bottom := is_outside(x, y + 1) || is_solid(sim, idx(x, y + 1))
	return left && right && bottom
}

is_hard :: proc(sim: Simulation, idx: int) -> bool {
	return is_cell(sim, idx, {.Hard, .Semi_Hard})
}

is_solid :: proc(sim: Simulation, idx: int) -> bool {
	return is_cell(sim, idx, {.Hard, .Semi_Hard, .Powder})
}

is_liquid :: proc(sim: Simulation, idx: int) -> bool {
	return is_cell(sim, idx, {.Liquid})
}

is_empty :: proc(sim: Simulation, idx: int) -> bool {
	return is_cell(sim, idx, {.Empty})
}
random_side :: proc(rng: rand.Generator) -> int {
	return int(rand.uint32(rng) & 1) * 2 - 1
}

tick_from_sec :: proc(sec: f32) -> u32 {
	return u32(sec * 60)
}

is_cell :: proc(sim: Simulation, i: int, $types: Mat_Types) -> bool {
	for type in types {
		if cell_type_match(sim, i, type) do return true
	}
	return false

}

random_variance :: proc(lo, hi: uint) -> Variance {
    return Variance( rand.uint_range(lo, hi))
}