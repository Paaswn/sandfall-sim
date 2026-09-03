package simulation

import "core:prof/spall"
import "core:math"
import "../profiling"

// bound is always a local coordinate of a chunk

Chunk_Manager :: struct {
	// index of active odd chunk
	active_white_chunk: [dynamic]int,
	// index of active even chunk
	active_red_chunk:   [dynamic]int,
	chunks:             []Chunk,
}

update_bound :: proc {
	update_bound_world,
	update_bound_local,
}

resize_bound :: proc {
	resize_bound_world,
	resize_bound_local,
}

@(private = "file")
update_bound_world :: proc(chunk: ^Chunk, pos: World_Pos) {
	bound := get_bound(chunk)
	resize_bound(&bound, pos)
	chunk.next_bound = bound
}

@(private = "file")
update_bound_local :: proc(chunk: ^Chunk, pos: Local_Pos) {
	bound := get_bound(chunk)
	resize_bound_local(&bound, pos)
	chunk.next_bound = bound
}

@(private = "file")
get_bound :: proc(chunk: ^Chunk) -> (bound: Bound ){
	if bound_, ok := chunk.next_bound.?; ok {
		bound = bound_
	} else {
		bound = Bound{Chunk_Size, Chunk_Size,  0,  0}
	}
	return
}

@(private = "file")
resize_bound_world :: proc(bound: ^Bound, pos: World_Pos) {
	lpos := Local_Pos(pos) % Chunk_Size
	resize_bound_local(bound, lpos)
}

Bound_Padding :: 5
@(private = "file")
resize_bound_local :: proc(bound: ^Bound, pos: Local_Pos) {
	bound.x = clamp(pos.x - Bound_Padding, 0, bound.x)
	bound.y = clamp(pos.y - Bound_Padding, 0, bound.y)
	bound.x2 = clamp(pos.x + Bound_Padding, bound.x2, Chunk_Size-1)
	bound.y2 = clamp(pos.y + Bound_Padding, bound.y2, Chunk_Size-1)
}

delete_chunk_manager :: proc(manager: ^Chunk_Manager) {
	delete(manager.active_red_chunk)
	delete(manager.active_white_chunk)
	delete(manager.chunks)
}

to_chunk_index :: proc {
	chunk_index_from_chunk_pos,
	chunk_index_from_world_pos,
}

@(private = "file")
chunk_index_from_chunk_pos :: proc(pos: Chunk_Pos) -> int {
	return pos.y * Width_In_Chunk + pos.x
}

@(private = "file")
chunk_index_from_world_pos :: proc(pos: World_Pos) -> int {
	pos := to_chunk_pos(pos)
	return pos.y * Width_In_Chunk + pos.x
}

@(require_results)
get_chunk :: proc {
	chunk_from_world_pos,
	chunk_from_chunk_pos,
}

@(private = "file")
chunk_from_world_pos :: proc(chunks: []Chunk, pos: World_Pos) -> ^Chunk {
	return &chunks[chunk_index_from_world_pos(pos)]
}

@(private = "file")
chunk_from_chunk_pos :: proc(chunks: []Chunk, pos: Chunk_Pos) -> ^Chunk {
	return &chunks[chunk_index_from_chunk_pos(pos)]
}

// accept world position or chunk index
to_chunk_pos :: proc {
	chunk_pos_from_world_pos,
	chunk_pos_from_chunk_index,
}

@(private = "file")
chunk_pos_from_chunk_index :: proc(cidx: int) -> Chunk_Pos {
	return {cidx % Width_In_Chunk, cidx / Width_In_Chunk}
}

@(private = "file")
chunk_pos_from_world_pos :: proc(pos: World_Pos) -> Chunk_Pos {
	return Chunk_Pos(pos / Chunk_Size)
}

to_world_pos :: proc {
	world_pos_from_index,
	world_pos_from_chunk_local,
}

@(private = "file")
world_pos_from_index :: proc(widx: int) -> World_Pos {
	return {widx % World_Width, widx / World_Width}
}

@(private = "file")
world_pos_from_chunk_local :: proc(cpos: Chunk_Pos, lpos: Local_Pos) -> World_Pos {
	return World_Pos(Local_Pos(cpos * Chunk_Size) + lpos)
}

is_chunk_outside :: proc(pos: Chunk_Pos) -> bool {
	return pos.x < 0 || pos.x > Width_In_Chunk - 1 || pos.y < 0 || pos.y > Height_In_Chunk - 1
}

activate_chunk :: proc {
	put_chunk_in_queue_chunk,
	put_chunk_in_queue_idx,
	put_chunk_in_queue_context
}

@(private = "file")
put_chunk_in_queue_context :: proc(uctx: Update_Context) {
	uctx.chunk.last_updated_tick = uctx.tick
	update_bound(uctx.chunk, uctx.lpos)
}
@(private = "file")
put_chunk_in_queue_chunk :: proc(world: ^World, chunk: ^Chunk, pos: World_Pos) {
	// chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
	update_bound(chunk, pos)
}

@(private = "file")
put_chunk_in_queue_idx :: proc(world: ^World, cpos: Chunk_Pos, wpos: World_Pos) {
	cx := math.clamp(cpos.x, 0, Width_In_Chunk - 1)
	cy := math.clamp(cpos.y, 0, Height_In_Chunk - 1)
	chunk := get_chunk(world.chunks, Chunk_Pos{cx, cy})
	// chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
	update_bound(chunk, wpos)
}

// can be turned into a field
chunk_active :: proc(chunk: ^Chunk, tick: u32) -> bool {
	if chunk.last_updated_tick == 0 do return false // this acts like^ initially all chunk.active feild with false
	return tick - chunk.last_updated_tick <= Material_Awake_Threshold // force chunk update if last_updated tick is less than 5 anyway
}
mark_dirty :: proc {
	mark_dirty_context,
	mark_chunk_dirty
}
mark_dirty_context :: proc(world: ^World, uctx: Update_Context) {
	activate_chunk(uctx)
	if uctx.lpos.y == 0 {
		activate_chunk(world, uctx.cpos - {0, 1}, uctx.wpos - {0, 1})
	}
	if uctx.lpos.x == 0 {
		activate_chunk(world, uctx.cpos - {1, 0}, uctx.wpos - {1, 0})
	}
	if uctx.lpos.x == Chunk_Size - 1 {
		activate_chunk(world, uctx.cpos + {1, 0}, uctx.wpos + {1, 0})
	}
}
to_local_pos :: proc(wpos: World_Pos) -> Local_Pos {
	return Local_Pos(wpos) % Chunk_Size
}
mark_chunk_dirty :: proc(world: ^World, wpos: World_Pos) {
	cpos := to_chunk_pos(wpos)
	activate_chunk(world, cpos, wpos)
	lpos := to_local_pos(wpos)
	if lpos.y == 0 {
		activate_chunk(world, cpos - {0, 1}, wpos - {0, 1})
	}
	if lpos.x == 0 {
		activate_chunk(world, cpos - {1, 0}, wpos - {1, 0})
	}
	if lpos.x == Chunk_Size - 1 {
		activate_chunk(world, cpos + {1, 0}, wpos + {1, 0})
	}
}