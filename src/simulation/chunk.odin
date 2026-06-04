package simulation

import "core:fmt"
import "core:math"
Chunk :: struct {
	last_updated_tick: u32,
	to_update_tick:    u32,
	// active:            bool,
}

chunk_index_from_chunk_pos :: proc(x, y: int) -> int {
	return y * Chunk_Per_Row + x
}

chunk_index_from_world_pos :: proc(x, y: int) -> int {
	cx, cy := to_chunk_pos(x, y)
	return cy * Chunk_Per_Row + cx
}

chunk_from_chunk_index :: proc(chunks: []Chunk, idx: int) -> ^Chunk {
	return &chunks[idx]
}

chunk_from_world_pos :: proc(chunks: []Chunk, x, y: int) -> ^Chunk {
	return &chunks[chunk_index_from_world_pos(x, y)]
}

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
	return x < 0 || x > Chunk_Per_Row - 1 || y < 0 || y > Chunk_Per_Column - 1
}

// deprecated
// wake_neighbor_chunk :: proc(chunks: []Chunk, origin_x, origin_y, off: int) {
// 	cx, cy := to_chunk_pos(origin_x, origin_y)
// 	for y in cy - off ..= cy + off {
// 		for x in cx - off ..= cx + off {
// 			to_wake_chunk(chunks, x, y)
// 		}
// 	}
// }

// auto clamping
wake_chunk_next :: proc(world: ^World, cx, cy: int) {
	x := math.clamp(cx, 0, Chunk_Per_Row - 1)
	y := math.clamp(cy, 0, Chunk_Per_Column - 1)
	chunk := chunk_from_chunk_pos(world.chunks, x, y)
	chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
}

// auto clamping
wake_chunk_now :: proc(world: ^World, cx, cy: int) {
	x := math.clamp(cx, 0, Chunk_Per_Row - 1)
	y := math.clamp(cy, 0, Chunk_Per_Column - 1)
	chunk := chunk_from_chunk_pos(world.chunks, x, y)
	chunk.to_update_tick = world.tick
	chunk.last_updated_tick = world.tick
}

// maybe turn this back to field but for now use proc instead
is_chunk_active :: proc(chunk: ^Chunk, tick: u32) -> bool {
	if chunk.to_update_tick == 0 && chunk.last_updated_tick == 0 do return false // this acts like initially all chunk.active feild with false
	return ( chunk.to_update_tick == tick || tick - chunk.last_updated_tick <= 4 ) // force chunk update if last_updated tick is less than 5 anyway
}