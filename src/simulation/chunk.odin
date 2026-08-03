package simulation

import "core:fmt"
import "core:math"

Chunk_Manager :: struct {
	// index of active odd chunk
	active_white_chunk: [dynamic]int,
	// index of active even chunk
	active_red_chunk: [dynamic]int,
	chunks: []Chunk
}

Chunk :: struct {
	white: bool,
	last_updated_tick: u32,
	to_update_tick:    u32,
	// active:            bool,
}

init_chunk_manager :: proc(manager: ^Chunk_Manager) {
	chunks := make([]Chunk, Width_In_Chunk * Height_In_Chunk)
	if Width_In_Chunk % 2 == 0 {
		flip := true
		for cy in 0..<Height_In_Chunk {
			for cx in 0..<Width_In_Chunk {
				i := chunk_index_from_chunk_pos(cx, cy)
				if flip  {
					if i % 2 == 0 {
						chunks[i].white = false
					} else {
						chunks[i].white = true
					}
				} else {
					if i % 2 == 0 {
						chunks[i].white = true
					} else {
						chunks[i].white = false
					}

				}
			}
			flip = !flip
		}
	}
	else {
		for &c, i in chunks {
			if i % 2 == 0 {
				c.white = false
			} else {
				c.white = true
			}
		}
	}
	manager.active_red_chunk = make([dynamic]int)
	manager.active_white_chunk = make([dynamic]int)
	manager.chunks = chunks
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

chunk_idx_to_chunk_pos :: proc(cidx: int) -> ( int, int ) {
	return cidx % Width_In_Chunk , cidx / Width_In_Chunk
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
	return x < 0 || x > Width_In_Chunk - 1 || y < 0 || y > Height_In_Chunk - 1
}

put_chunk_in_queue :: proc(world: ^World, cx, cy: int) {
	manager := &world.chunk_manager
	cx := math.clamp(cx, 0, Width_In_Chunk - 1)
	cy := math.clamp(cy, 0, Height_In_Chunk - 1)
	cidx := chunk_index_from_chunk_pos(cx, cy)
	if !is_chunk_active(&manager.chunks[cidx], world.tick) {
		if manager.chunks[cidx].white {
			append(&manager.active_white_chunk, cidx)
		} else {
			append(&manager.active_red_chunk, cidx)
		}
		manager.chunks[cidx].last_updated_tick = world.tick
		// fmt.println("odd:", manager.active_odd_chunk[:])
		// fmt.println("even:", manager.active_even_chunk[:])
	}
}

// auto clamping
wake_chunk_next :: proc(world: ^World, cx, cy: int) {
	x := math.clamp(cx, 0, Width_In_Chunk - 1)
	y := math.clamp(cy, 0, Height_In_Chunk - 1)
	chunk := chunk_from_chunk_pos(world.chunk_manager.chunks, x, y)
	chunk.to_update_tick = world.tick + 1
	chunk.last_updated_tick = world.tick
}

// auto clamping
wake_chunk_now :: proc(world: ^World, cx, cy: int) {
	x := math.clamp(cx, 0, Width_In_Chunk - 1)
	y := math.clamp(cy, 0, Height_In_Chunk - 1)
	chunk := chunk_from_chunk_pos(world.chunk_manager.chunks, x, y)
	chunk.to_update_tick = world.tick
	chunk.last_updated_tick = world.tick
}

// maybe turn this back to field but for now use proc instead
is_chunk_active :: proc(chunk: ^Chunk, tick: u32) -> bool {
	if chunk.to_update_tick == 0 && chunk.last_updated_tick == 0 do return false // this acts like initially all chunk.active feild with false
	return ( chunk.to_update_tick == tick || tick - chunk.last_updated_tick <= 4 ) // force chunk update if last_updated tick is less than 5 anyway
}
