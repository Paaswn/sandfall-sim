package simulation

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Bound :: struct {
    x, y, x2, y2: int
}
Chunk_Manager :: struct {
	// index of active odd chunk
	active_white_chunk: [dynamic]int,
	// index of active even chunk
	active_red_chunk:   [dynamic]int,
	chunks:             []Chunk,
}

Chunk :: struct {
	active_bound:      Maybe( Bound ),
	last_updated_tick: u32,
	to_update_tick:    u32,
	// active:            bool,
}

region_bounding :: proc(chunk: ^Chunk, wx, wy: int) {
    lx, ly := wx % Chunk_Size, wy % Chunk_Size
    x, y, x2, y2 := max( lx-1, 0 ), max( ly-1, 0), min( lx+1, Chunk_Size), min( ly+1, Chunk_Size)
    if bound, ok := chunk.active_bound.?; ok{
        x = min(x, bound.x)
        y = min(y, bound.y)
        x2 = max(x2, bound.x2)
        y2 = max(y2, bound.y2)
    }
    chunk.active_bound = Bound{x, y, x2, y2}  
}

delete_chunk_manager :: proc(manager: ^Chunk_Manager) {
	delete(manager.active_red_chunk)
	delete(manager.active_white_chunk)
	delete(manager.chunks)
}

chunk_index_from_chunk_pos :: proc(x, y: int) -> int {
	return y * Width_In_Chunk + x
}

chunk_index_from_world_pos :: proc(x, y: int) -> int {
	cx, cy := to_chunk_pos(x, y)
	return cy * Width_In_Chunk + cx
}

chunk_idx_to_chunk_pos :: proc(cidx: int) -> (int, int) {
	return cidx % Width_In_Chunk, cidx / Width_In_Chunk
}

@(require_results)
chunk_from_world_pos :: proc(chunks: []Chunk, x, y: int) -> ^Chunk {
	return &chunks[chunk_index_from_world_pos(x, y)]
}

@(require_results)
chunk_from_chunk_pos :: proc(chunks: []Chunk, x, y: int) -> ^Chunk {
	return &chunks[chunk_index_from_chunk_pos(x, y)]
}

to_chunk_pos :: proc(x, y: int) -> (int, int) {
	return x / Chunk_Size, y / Chunk_Size
}

to_world_pos :: proc(cx, cy, x, y: int) -> (int, int) {
	nx := cx * Chunk_Size + x
	ny := cy * Chunk_Size + y
	return nx, ny
}

is_chunk_outside :: proc(x, y: int) -> bool {
	return x < 0 || x > Width_In_Chunk - 1 || y < 0 || y > Height_In_Chunk - 1
}
put_chunk_in_queue :: proc {
    put_chunk_in_queue_chunk,
    put_chunk_in_queue_idx
}

put_chunk_in_queue_chunk :: proc(world: ^World, chunk: ^Chunk, wx, wy: int) {
	chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
	region_bounding(chunk, wx, wy)
}

put_chunk_in_queue_idx :: proc(world: ^World, cx, cy: int, wx, wy: int) {
	cx := math.clamp(cx, 0, Width_In_Chunk - 1)
	cy := math.clamp(cy, 0, Height_In_Chunk - 1)
	chunk := chunk_from_chunk_pos(world.chunks, cx, cy)
	chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
	region_bounding(chunk, wx, wy)
}

// auto clamping
wake_chunk_next :: proc(world: ^World, cx, cy: int) {
	x := math.clamp(cx, 0, Width_In_Chunk - 1)
	y := math.clamp(cy, 0, Height_In_Chunk - 1)
	chunk := chunk_from_chunk_pos(world.chunks, x, y)
	chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
}

// auto clamping
wake_chunk_now :: proc(world: ^World, cx, cy: int) {
	x := math.clamp(cx, 0, Width_In_Chunk - 1)
	y := math.clamp(cy, 0, Height_In_Chunk - 1)
	chunk := chunk_from_chunk_pos(world.chunks, x, y)
	chunk.to_update_tick = world.tick
	chunk.last_updated_tick = world.tick
}

// can be turned into a field
chunk_active :: proc(chunk: ^Chunk, tick: u32) -> bool {
	if chunk.to_update_tick == 0 && chunk.last_updated_tick == 0 do return false // this acts like initially all chunk.active feild with false
	return chunk.to_update_tick == tick || tick - chunk.last_updated_tick <= 4 // force chunk update if last_updated tick is less than 5 anyway
}
