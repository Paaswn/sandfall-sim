package main

import "core:fmt"
import "core:math"
import sim "simulation"
import rl "vendor:raylib"

build_pixel_buf :: proc(game: ^Game) {
	debug_mode := game.config.debug_mode
	world := &game.world
	buf := game.pixel_buf
	switch debug_mode {
	case .Velocity_Y:
		build_pixel_index(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			if world.config[ world.grid[idx] ].type == .Powder do buf[idx] = get_vel_color(1, world.vel_y[idx], sim.Powder.Max_Vy)
			else if world.config[ world.grid[idx] ].type == .Liquid do buf[idx] = get_vel_color(1, world.vel_y[idx], sim.Liquid.Max_Vy)
		})
	case .Velocity_X:
		build_pixel_index(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			else if world.config[ world.grid[idx] ].type == .Powder do buf[idx] = get_vel_color(world.side[idx], world.vel_y[idx], sim.Powder.Max_Vx)
			else if world.config[ world.grid[idx] ].type == .Liquid do buf[idx] = get_vel_color(world.side[idx], world.vel_y[idx], sim.Liquid.Max_Vx)
		})

	case .Off:
		build_pixel_index(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			buf[idx] = world.color[idx]
		})
	}

}
build_pixel_index :: proc(
	world: ^sim.World,
	buf: []rl.Color,
	fill_color: proc(idx: int, buf: []rl.Color, world: ^sim.World),
) {
	when ODIN_DEBUG {
		for _, idx in world.grid {
			fill_color(idx, buf, world)
		}
	} else {
		for cy in 0..<sim.Chunk_Per_Column {
			for cx in 0..<sim.Chunk_Per_Row {
				if !sim.is_chunk_active( sim.chunk_from_chunk_pos(world.chunks, cx, cy), world.tick ) {
					continue
				}
				for local_y in 0..<sim.Chunk_Size {
					for local_x in 0..<sim.Chunk_Size {
						x, y := sim.to_world_pos(cx, cy, local_x, local_y)
						if idx, ok := sim.world_index(x, y); ok {
							buf[idx] = world.color[idx]
						}
					}
				}
			}
		}
		
	}
}
build_pixel_pos :: proc(
	world: ^sim.World,
	buf: []rl.Color,
	fill_color: proc(x, y: int, buf: []rl.Color, world: ^sim.World),
) {
	for y in 0 ..< sim.World_Height {
		for x in 0 ..< sim.World_Width {
			fill_color(x, y, buf, world)
		}
	}
}

render_debug_chunk :: proc(world: ^sim.World) {
	for &chunk, i in world.chunks {
		if sim.is_chunk_active(&chunk, world.tick) {
			x := i % sim.Chunk_Per_Row
			y := i / sim.Chunk_Per_Row
			S := sim.Scale
			CS := sim.Chunk_Size
			rl.DrawRectangleLines(
				i32(x * CS * S),
				i32(y * CS * S),
				i32(CS * S),
				i32(CS * S),
				rl.RED,
			)
		}
	}
}
// draw_rectangle :: proc(brush_size: int, mouse.world.x, mouse.world.y: int) {
// 	y_start := mouse.world.y - brush_size
// 	y_end := mouse.world.y + brush_size
// 	x_start := mouse.world.x - brush_size
// 	x_end := mouse.world.x + brush_size
// 	for y in y_start ..= y_end {
// 		for x in x_start ..= x_end {
// 			if sim.is_outside(x, y) {
// 				continue
// 			}
// 			if y == y_start || y == y_end || x == x_start || x == x_end {
// 				rl.DrawRectangle(
// 					i32(x * sim.Scale),
// 					i32(y * sim.Scale),
// 					i32(sim.Scale),
// 					i32(sim.Scale),
// 					rl.WHITE,
// 				)
// 			}
// 		}
// 	}
// }

// draw_pixelated_circle :: proc(mouse.world.x, mouse.world.y: int) {
//     for y in mouse.world.y - config.brush_size ..= mouse.world.y + config.brush_size {
//         for x in mouse.world.x - config.brush_size ..= mouse.world.x + config.brush_size {
// 			if sim.is_outside(x, y) {
// 				continue
// 			}
// 			dx := x - mouse.world.x
// 			dy := y - mouse.world.y
// 			dist2 := dx * dx + dy * dy
// 			outer := config.brush_size * config.brush_size
// 			inner := (config.brush_size - 1) * (config.brush_size - 1)
// 			if dist2 < outer && dist2 >= inner {
// 				rl.DrawRectangle(
// 					i32(x * sim.Scale),
// 					i32(y * sim.Scale),
// 					i32(sim.Scale),
// 					i32(sim.Scale),
// 					rl.WHITE,
// 				)
// 			}
// 		}
// 	}
// }

render_brush :: proc(config: ^Game_Config, mouse: Mouse_State) {

	rl.DrawRectangle(
		i32(mouse.world.x * sim.Scale),
		i32(mouse.world.y * sim.Scale),
		i32(sim.Scale),
		i32(sim.Scale),
		rl.WHITE,
	)
	if config.brush_size == 0 do return

	for y in mouse.world.y - config.brush_size ..= mouse.world.y + config.brush_size {
		for x in mouse.world.x - config.brush_size ..= mouse.world.x + config.brush_size {
			if sim.is_outside(x, y) {
				continue
			}
			dx := x - mouse.world.x
			dy := y - mouse.world.y
			dist2 := dx * dx + dy * dy
			outer := config.brush_size * config.brush_size
			inner := (config.brush_size - 1) * (config.brush_size - 1)
			if dist2 < outer && dist2 >= inner {
				rl.DrawRectangle(
					i32(x * sim.Scale),
					i32(y * sim.Scale),
					i32(sim.Scale),
					i32(sim.Scale),
					rl.WHITE,
				)
			}
		}
	}
}

get_vel_color :: proc(side: int, vel: f32, max: f32) -> (color: rl.Color) {
	value := abs(vel / max)
	if side > 0 {
		new_r := u8(math.clamp(int(value * 255), 0, 255))
		color = rl.Color{new_r, 0, 0, 255}
	} else if side < 0 {
		new_g := u8(math.clamp(int(value * 255), 0, 255))
		color = rl.Color{0, new_g, 0, 255}
	} else {
		new_b := u8(math.clamp(int(value * 255), 0, 255))
		color = rl.Color{0, 0, new_b, 255}
	}
	return
}
