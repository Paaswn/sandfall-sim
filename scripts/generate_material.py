import json

OUTPUT = "./src/simulation/generated_material.odin"
CONFIG = "./config/world_config.json"

with open(CONFIG, "r", encoding="utf-8") as f:
     materials = json.load(f)

def make_all_material_name() -> str :
    mats = "\t"
    for k in materials:
        mats += k + ",\n\t"
    return mats
    
content = f"""package simulation

// --- THIS FILE WAS AUTOMATICALLY GENERATED ---

import rl "vendor:raylib"

Material :: enum u8 {{
{make_all_material_name()}
}}

get_material_color :: proc(mat: Material, pos: World_Pos, salt: u64) -> (color: rl.Color) {{
	#partial switch mat {{
	case .Empty:
		color = rl.BLACK
	case:
		color = random_shade(get_material_base_color(mat), pos, 20, salt)
	case .Water:
		color = rl.DARKBLUE
    }}
	return
}}

get_material_base_color :: proc(mat: Material) -> (color: rl.Color ) {{
	switch mat {{
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
	}}
	return
}}

"""

with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write(content)

