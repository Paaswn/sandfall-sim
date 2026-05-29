package main

import "core:math"
import sim "simulation"
import rl "vendor:raylib"

build_pixel_buf :: proc(world: ^sim.World, buf: []rl.Color) {
	#partial switch sim.debug_mode {
	case .Velocity_Y:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			else do buf[idx] = get_vel_color(world.vel_y[idx], sim.Max_Step_Y)
		})
	case .Velocity_X:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			else do buf[idx] = get_vel_color(world.vel_x[idx], sim.Max_Step_X)
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
draw_rectangle :: proc(mx, my: int) {
	y_start := my - sim.spawn_radius
	y_end := my + sim.spawn_radius
	x_start := mx - sim.spawn_radius
	x_end := mx + sim.spawn_radius
	for y in y_start ..= y_end {
		for x in x_start ..= x_end {
			if sim.is_outside(x, y) {
				continue
			}
			if y == y_start || y == y_end || x == x_start || x == x_end {
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

draw_pixelated_circle :: proc(mx, my: int) {
	for y in my - sim.spawn_radius ..= my + sim.spawn_radius {
		for x in mx - sim.spawn_radius ..= mx + sim.spawn_radius {
			if sim.is_outside(x, y) {
				continue
			}
			dx := x - mx
			dy := y - my
			dist2 := dx * dx + dy * dy
			outer := sim.spawn_radius * sim.spawn_radius
			inner := (sim.spawn_radius - 1) * (sim.spawn_radius - 1)
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

render_brush :: proc(mx, my: int) {
	if sim.spawn_radius == 0 {
		rl.DrawRectangle(
			i32(mx * sim.Scale),
			i32(my * sim.Scale),
			i32(sim.Scale),
			i32(sim.Scale),
			rl.WHITE,
		)
		return
	}
	for y in my - sim.spawn_radius ..= my + sim.spawn_radius {
		for x in mx - sim.spawn_radius ..= mx + sim.spawn_radius {
			if sim.is_outside(x, y) {
				continue
			}
			dx := x - mx
			dy := y - my
			dist2 := dx * dx + dy * dy
			outer := sim.spawn_radius * sim.spawn_radius
			inner := (sim.spawn_radius - 1) * (sim.spawn_radius - 1)
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
