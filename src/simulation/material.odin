package simulation

import rl "vendor:raylib"
import "core:math"

Material_Type :: enum u8 {
	Liquid, // move without thresh (side/slide thresh =0)
	Powder, // move with thresh
	Hard, // static material that can't be damaged by any game object
	Semi_Hard, // static material that can be slightly damaged by game object
}
random_shade :: proc(base: rl.Color, pos: World_Pos, variance: int, salt: u64) -> rl.Color {
	// 1. Generate a single random offset for uniform shading
	// If variance is 30, offset will be between -30 and +30
	hash := (pos.x * 73856093) ~ (pos.y * 19349663) ~ int((salt * 83492791))
	

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