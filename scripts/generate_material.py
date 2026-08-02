import json

OUTPUT = "/home/paaswn/Projects/Odin/projectF/src/simulation/generated_material.odin"
CONFIG = "/home/paaswn/Projects/Odin/projectF/config/world_config.json"

with open(CONFIG, "r", encoding="utf-8") as f:
     materials = json.load(f)

mats = "\t"
for k in materials:
    mats += k + ",\n\t"

content = f"""package simulation

// --- THIS FILE WAS AUTOMATICALLY GENERATED ---

Material_Config :: struct {{
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
}}

Material_Type :: enum u8 {{
	Liquid, // move without thresh (side/slide thresh =0)
	Powder, // move with thresh
	Hard, // static material that can't be damaged by any game object
	Semi_Hard, // static material that can be slightly damaged by game object
}}

Material :: enum u8 {{
{mats} 
}}
"""

with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write(content)
