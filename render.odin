package main

import "core:math"
import sim "simulation"
import rl "vendor:raylib"

build_pixel_buf :: proc(game: ^Game) {
	debug_mode := game.config.debug_mode
	world := &game.world
	buf := game.pixel_buf
	#partial switch debug_mode {
	case .Velocity_Y:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			else do buf[idx] = get_vel_color(world.vel_y[idx], world.config.sand.max_vy)
		})
	case .Velocity_X:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			else do buf[idx] = get_vel_color(world.vel_x[idx], world.config.sand.max_vx)
		})

	case:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			buf[idx] = world.color[idx]
		})
	// build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
	// 	if world.active[idx] {
	// 		buf[idx] = rl.GREEN
	// 	} else if world.grid[idx] == .Empty {
	// 		buf[idx] = rl.BLACK
	// 	} else {
	// 		buf[idx] = rl.DARKGRAY
	// 	}
	// jk
	// })
	}

}

build_pixel :: proc(
	world: ^sim.World,
	buf: []rl.Color,
	fill_color: proc(idx: int, buf: []rl.Color, world: ^sim.World),
) {
	for _, idx in world.grid {
		fill_color(idx, buf, world)
	}
}

render_debug_chunk :: proc(world: ^sim.World) {
	for chunk, i in world.chunks {
		if chunk.active {
			x := i % sim.Width_Chunk
			y := i / sim.Width_Chunk
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

get_vel_color :: proc(vel: f32, max: f32) -> rl.Color {
	value := abs(vel / max)
	if vel > 0 {
		new_r := u8(math.clamp(int(value * 255), 0, 255))
		return rl.Color{new_r, 0, 0, 255}
	} else {
		new_g := u8(math.clamp(int(value * 255), 0, 255))
		return rl.Color{0, new_g, 0, 255}
	}
}
