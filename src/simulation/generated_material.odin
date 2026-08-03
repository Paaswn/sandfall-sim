package simulation

// --- THIS FILE WAS AUTOMATICALLY GENERATED ---
import rl "vendor:raylib"
Material_Config :: struct {
	type:           Material_Type,
	down_acc:       f32,
	slide_thresh:   f32,
	side_thresh:    f32,
	friction:       f32,
	damp:           f32,
	impact_to_side: f32,
	impact_thresh:  f32,
	slide_drag:     f32,
	fall_drag:      f32,
}


Material :: enum u8 {
	Empty,
	Cement,
	Sand,
	Dirt,
	Water,
	 
}

get_material_color :: proc(mat: Material, x, y: int, salt: u64) -> (color: rl.Color) {
	#partial switch mat {
	case .Empty:
		color = rl.BLACK
	case:
		color = random_shade(get_material_base_color(mat), x, y, 20, salt)
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
