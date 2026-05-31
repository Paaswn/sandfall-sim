package simulation

import "core:fmt"
import "core:math"
Chunk :: struct {
	last_updated_tick: u64,
	active_next:       bool,
	active:            bool,
}

chunk_idx_by_cpos :: proc(x, y: int) -> int {
	return y * Width_Chunk + x
}

chunk_idx_by_wpos :: proc(x, y: int) -> int {
	cx, cy := to_chunk_pos(x, y)
	return cy * Width_Chunk + cx
}

get_chunk_by_cidx :: proc(chunks: []Chunk, idx: int) -> ^Chunk {
	return &chunks[idx]
}

get_chunk_by_wpos :: proc(chunks: []Chunk, x, y: int) -> ^Chunk {
	return &chunks[chunk_idx_by_wpos(x, y)]
}
get_chunk :: proc {
	get_chunk_by_cidx,
	get_chunk_by_wpos,
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
	return x < 0 || x > Width_Chunk - 1 || y < 0 || y > Height_Chunk - 1
}

wake_neighbor_chunk :: proc(chunks: []Chunk, origin_x, origin_y, off: int) {
	cx, cy := to_chunk_pos(origin_x, origin_y)
	for y in cy - off ..= cy + off {
		for x in cx - off ..= cx + off {
			to_wake_chunk(chunks, x, y)
		}
	}
}

// auto clamping
to_wake_chunk :: proc(chunks: []Chunk, cx, cy: int) {
	x := math.clamp(cx, 0, Width_Chunk - 1)
	y := math.clamp(cy, 0, Height_Chunk - 1)
	idx := chunk_idx_by_cpos(x, y)
	get_chunk(chunks, idx).active_next = true
}

wake_chunk :: proc(chunks: []Chunk, cx, cy: int) {
	x := math.clamp(cx, 0, Width_Chunk - 1)
	y := math.clamp(cy, 0, Height_Chunk - 1)
	idx := chunk_idx_by_cpos(x, y)
	get_chunk(chunks, idx).active = true
}