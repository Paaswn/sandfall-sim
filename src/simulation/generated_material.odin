package simulation

// --- THIS FILE WAS AUTOMATICALLY GENERATED ---

import rl "vendor:raylib"

Material :: enum u8 {
	Empty,
	Cement,
	Sand,
	Dirt,
	Water,
	
}

get_material_color :: proc(mat: Material, pos: World_Pos, salt: u64) -> (color: rl.Color) {
	#partial switch mat {
	case .Empty:
		color = rl.BLACK
	case:
		color = random_shade(get_material_base_color(mat), pos, 20, salt)
	case .Water:
		color = rl.DARKBLUE
    }
	return
}

get_material_base_color :: proc(mat: Material) -> (color: rl.Color ) {
	switch mat {
	case .Empty:
		color = rl.BLACK
	case .Sand:
		color = rl.BEIGE
	case .Dirt:
		color = rl.BROWN
	case .Cement:
		color = rl.DARKGRAY
	case .Water:
		color = rl.BLUE
	}
	return
}

