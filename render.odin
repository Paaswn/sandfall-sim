package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

build_pixel_buf :: proc(world: ^World, buf: []rl.Color) {
	switch debug_mode {
	case .Off:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^World) {
			buf[idx] = world.color[idx]
		})
	case .Velocity_Y:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^World) {
			buf[idx] = random_color_vel(world.vel_y[idx])
		})
	case .Velocity_X:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^World) {
			buf[idx] = random_color_vel(world.vel_x[idx])
		})

	case .Active_Cell:
		build_pixel(world, buf, proc(idx: int, buf: []rl.Color, world: ^World) {
			if world.active[idx] {
				buf[idx] = rl.GREEN
			} else {
				buf[idx] = rl.DARKGRAY
			}
		})

	}
}

build_pixel :: proc(
	world: ^World,
	buf: []rl.Color,
	fill_color: proc(idx: int, buf: []rl.Color, color: ^World),
) {
	for cell, idx in world.grid {
		switch cell {
		case .Empty:
			buf[idx] = rl.BLACK

		case .Sand:
			fill_color(idx, buf, world)
		}
	}
}

render_brush :: proc(mx, my: int) {
	if spawn_radius == 0 {
		rl.DrawRectangle(i32(mx * SCALE), i32(my * SCALE), i32(SCALE), i32(SCALE), rl.WHITE)
		return
	}
	for y in my - spawn_radius ..= my + spawn_radius {
		for x in mx - spawn_radius ..= mx + spawn_radius {
			if is_outside(x, y) {
				continue
			}
			dx := x - mx
			dy := y - my
			dist2 := dx * dx + dy * dy
			outer := spawn_radius * spawn_radius
			inner := (spawn_radius - 1) * (spawn_radius - 1)
			if dist2 <= outer && dist2 >= inner {
				rl.DrawRectangle(i32(x * SCALE), i32(y * SCALE), i32(SCALE), i32(SCALE), rl.WHITE)
			}
		}
	}
}

get_material_color :: proc(mat: Material, x, y: int, salt: u64) -> rl.Color {
	color: rl.Color
	switch mat {
	case .Sand:
		color = random_shade(rl.BEIGE, x, y, 20, salt)
	case .Empty:
		color = rl.BLACK
	}
	return color
}

random_color_vel :: proc(vel: f32) -> rl.Color {
	value := vel / MAX_STEP_Y
	new_r := u8(math.clamp(int(value * 255), 0, 255))
	return rl.Color{new_r, 20, 20, 255}
}
random_shade :: proc(base: rl.Color, x, y, variance: int, salt: u64) -> rl.Color {
	// 1. Generate a single random offset for uniform shading
	// If variance is 30, offset will be between -30 and +30
	hash := (x * 73856093) ~ (y * 19349663) ~ int((salt * 83492791))

	offset := (hash % (variance * 2 + 1)) - variance

	// 2. Apply offset and clamp values between 0 and 255 to prevent integer overflow
	return get_new_color(base, offset)
}
get_new_color :: proc(base: rl.Color, offset: int) -> rl.Color {

	new_r := u8(math.clamp(int(base.r) + offset, 0, 255))
	new_g := u8(math.clamp(int(base.g) + offset, 0, 255))
	new_b := u8(math.clamp(int(base.b) + offset, 0, 255))

	return rl.Color{new_r, new_g, new_b, base.a}
}
