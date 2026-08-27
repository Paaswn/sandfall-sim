package simulation

import "core:log"
import "core:fmt"
import "core:math"
import "core:testing"
import rl "vendor:raylib"

// bound is always a local coordinate of a chunk
Bound :: struct {
	x, y, x2, y2: int,
}
Chunk_Manager :: struct {
	// index of active odd chunk
	active_white_chunk: [dynamic]int,
	// index of active even chunk
	active_red_chunk:   [dynamic]int,
	chunks:             []Chunk,
}

Chunk :: struct {
	active_bound:      Maybe(Bound),
	last_updated_tick: u32,
	last_bound_reset:  u32,
	// active:            bool,
}

update_bound :: proc {
    update_bound_world,
    update_bound_local
}

resize_bound :: proc {
    resize_bound_world,
    resize_bound_local
}

@(private="file")
update_bound_world :: proc(chunk: ^Chunk, pos: World_Pos) {
	bound, ok := chunk.active_bound.?
	if !ok do bound = Bound{Chunk_Size, Chunk_Size, 0, 0}
	resize_bound_world(&bound, pos)
	chunk.active_bound = bound
}

@(private="file")
update_bound_local :: proc(chunk: ^Chunk, pos: Local_Pos) {
	bound, ok := chunk.active_bound.?
	if !ok do bound = Bound{Chunk_Size, Chunk_Size, 0, 0}
	resize_bound_local(&bound, pos)
	chunk.active_bound = bound
}

@(private="file")
resize_bound_world :: proc(bound: ^Bound, pos: World_Pos) {
	lpos: Local_Pos =  transmute(Local_Pos)pos % Chunk_Size
	resize_bound_local(bound, lpos)
}

@(private="file")
resize_bound_local :: proc(bound: ^Bound, pos: Local_Pos) {
	bound.x = clamp(pos.x - 3, 0, bound.x)
	bound.y = clamp(pos.y - 3, 0, bound.y)
	bound.x2 = clamp(pos.x + 4, bound.x2, Chunk_Size)
	bound.y2 = clamp(pos.y + 4, bound.y2, Chunk_Size)
}

delete_chunk_manager :: proc(manager: ^Chunk_Manager) {
	delete(manager.active_red_chunk)
	delete(manager.active_white_chunk)
	delete(manager.chunks)
}

to_chunk_index :: proc {
    chunk_index_from_chunk_pos,
    chunk_index_from_world_pos
}

@(private="file")
chunk_index_from_chunk_pos :: proc(pos: Chunk_Pos) -> int {
	return pos.y * Width_In_Chunk + pos.x 
}

@(private="file")
chunk_index_from_world_pos :: proc(pos: World_Pos) -> int {
	pos := to_chunk_pos(pos)
	return pos.y * Width_In_Chunk + pos.x
}

@(require_results)
get_chunk :: proc {
    chunk_from_world_pos,
    chunk_from_chunk_pos,
}

@(private="file")
chunk_from_world_pos :: proc(chunks: []Chunk, pos: World_Pos) -> ^Chunk {
	return &chunks[chunk_index_from_world_pos(pos)]
}

@(private="file")
chunk_from_chunk_pos :: proc(chunks: []Chunk, pos: Chunk_Pos) -> ^Chunk {
	return &chunks[chunk_index_from_chunk_pos(pos)]
}

// accept world position or chunk index
to_chunk_pos :: proc {
    chunk_pos_from_world_pos,
    chunk_pos_from_chunk_index
}

@(private="file")
chunk_pos_from_chunk_index :: proc(cidx: int) -> Chunk_Pos {
	return { cidx % Width_In_Chunk, cidx / Width_In_Chunk }
}

@(private="file")
chunk_pos_from_world_pos :: proc(pos: World_Pos) -> Chunk_Pos {
	return Chunk_Pos( pos / Chunk_Size )
}

to_world_pos :: proc(cpos: Chunk_Pos, lpos: Local_Pos) -> World_Pos {
    return World_Pos( Local_Pos( cpos * Chunk_Size ) + lpos )
}

is_chunk_outside :: proc(pos: Chunk_Pos) -> bool {
	return pos.x < 0 || pos.x > Width_In_Chunk - 1 || pos.y < 0 || pos.y > Height_In_Chunk - 1
}

activate_chunk :: proc {
	put_chunk_in_queue_chunk,
	put_chunk_in_queue_idx,
}

@(private="file")
put_chunk_in_queue_chunk :: proc(world: ^World, chunk: ^Chunk, pos: World_Pos) {
	// chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
	update_bound(chunk, pos)
}

@(private="file")
put_chunk_in_queue_idx :: proc(world: ^World, cpos: Chunk_Pos, wpos: World_Pos) {
	cx := math.clamp(cpos.x, 0, Width_In_Chunk - 1)
	cy := math.clamp(cpos.y, 0, Height_In_Chunk - 1)
	chunk := chunk_from_chunk_pos(world.chunks, { cx, cy })
	// chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
	update_bound(chunk, wpos)
}

// can be turned into a field
chunk_active :: proc(chunk: ^Chunk, tick: u32) -> bool {
	if chunk.last_updated_tick == 0 do return false // this acts like initially all chunk.active feild with false
	return tick - chunk.last_updated_tick <= 4 // force chunk update if last_updated tick is less than 5 anyway
}

@(test)
chunk_activation_test :: proc(t: ^testing.T) {
	X, Y :: 32, 32
	lx, ly := 1, 0
	world: World
	create_world(&world)
	defer delete_world(&world)
	world.tick = 1
	spawn_material(&world, .Sand, { X, Y })
	update_grid(&world)
	c :: chunk_from_world_pos
	// testing.expect(t, chunk_active(c(world.chunks, X, Y), world.tick))
	// testing.expect(t, chunk_active(c(world.chunks, X, Y-1), world.tick))

}
