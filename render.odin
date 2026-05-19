package main

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

build_pixel :: proc(world: ^World, buf: []rl.Color) {
	for cell, idx in world.grid {
		switch cell {
		case .Empty:
			buf[idx] = rl.BLACK

		case .Sand:
			buf[idx] = world.color[idx]
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

get_material_color :: proc(mat: Material, x, y: int) -> rl.Color {
	color: rl.Color
	switch mat {
	case .Sand:
		color = random_shade(rl.BEIGE, x, y, 20)
	case .Empty:
		color = rl.BLACK
	}
	return color
}

random_shade :: proc(base: rl.Color, x, y, variance: int) -> rl.Color {
	// 1. Generate a single random offset for uniform shading
	// If variance is 30, offset will be between -30 and +30
	hash := (x * 73856093) ~ (y * 19349663)
		
	offset := (hash % (variance * 2 + 1)) - variance

	// 2. Apply offset and clamp values between 0 and 255 to prevent integer overflow
	new_r := u8(math.clamp(int(base.r) + offset, 0, 255))
	new_g := u8(math.clamp(int(base.g) + offset, 0, 255))
	new_b := u8(math.clamp(int(base.b) + offset, 0, 255))

	return rl.Color{new_r, new_g, new_b, base.a}
}