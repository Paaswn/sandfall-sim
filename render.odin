package main

import sim "simulation"
import "core:math"
import rl "vendor:raylib"

build_pixel_buf :: proc(world: ^sim.World, buf: []rl.Color) {
	switch sim.debug_mode {
	case .Off:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			buf[idx] = world.color[idx]
		})
	case .Velocity_Y:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			buf[idx] = get_vel_color(world.vel_y[idx])
		})
	case .Velocity_X:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			buf[idx] = get_vel_color(world.vel_x[idx])
		})

	case .Active_Cell:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.active[idx] {
				buf[idx] = rl.GREEN
			} else if world.grid[idx] == .Empty {
				buf[idx] = rl.BLACK
			} else {
				buf[idx] = rl.DARKGRAY
			}
		})

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
				rl.DrawRectangle(i32(x * sim.SCALE), i32(y * sim.SCALE), i32(sim.SCALE), i32(sim.SCALE), rl.WHITE)
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
				rl.DrawRectangle(i32(x * sim.SCALE), i32(y * sim.SCALE), i32(sim.SCALE), i32(sim.SCALE), rl.WHITE)
			}
		}
	}
}

render_brush :: proc(mx, my: int) {
    if sim.spawn_radius == 0 {
		rl.DrawRectangle(i32(mx * sim.SCALE), i32(my * sim.SCALE), i32(sim.SCALE), i32(sim.SCALE), rl.WHITE)
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
				rl.DrawRectangle(i32(x * sim.SCALE), i32(y * sim.SCALE), i32(sim.SCALE), i32(sim.SCALE), rl.WHITE)
			}
		}
	}
}

get_vel_color :: proc(vel: f32) -> rl.Color {
	value := abs(vel / sim.MAX_STEP_Y)
	new_r := u8(math.clamp(int(value * 255), 0, 255))
	return rl.Color{new_r, 0, 0, 255}
}

