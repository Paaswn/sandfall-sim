package game

import sim "../simulation"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Mouse_State :: Mouse

build_pixel_buf :: proc(game: ^Game) {
	debug_mode := game.config.debug_render
	world := &game.world
	buf := game.pixel_buf
	switch debug_mode {
	case .Velocity_Y:
		build_pixel_index(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			if world.config[world.grid[idx]].type == .Powder do buf[idx] = get_vel_color(1, world.vel_y[idx], sim.Powder.Max_Vy)
			else if world.config[world.grid[idx]].type == .Liquid do buf[idx] = get_vel_color(1, world.vel_y[idx], sim.Liquid.Max_Vy)
		})
	case .Velocity_X:
		build_pixel_index(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			if world.grid[idx] == .Empty do buf[idx] = rl.GRAY
			else if world.config[world.grid[idx]].type == .Powder do buf[idx] = get_vel_color(world.side[idx], world.vel_x[idx], sim.Powder.Max_Vx)
			else if world.config[world.grid[idx]].type == .Liquid do buf[idx] = get_vel_color(world.side[idx], world.vel_x[idx], sim.Liquid.Max_Vx)
		})

	case .Off:
		build_pixel_index(world, buf, proc(idx: int, buf: []rl.Color, world: ^sim.World) {
			buf[idx] = world.color[idx]
		})
	}

}
build_pixel_index :: proc(
	world: ^sim.World,
	buf: []rl.Color,
	fill_color: proc(idx: int, buf: []rl.Color, world: ^sim.World),
) {
	when ODIN_DEBUG {
		for _, idx in world.grid {
			fill_color(idx, buf, world)
		}
	} else {
		// only render alive chunks
		for &c, i in world.chunks {
			if !sim.chunk_active(&c, world.tick) {
				continue
			} else {
				for local_y in 0 ..< sim.Chunk_Size {
					for local_x in 0 ..< sim.Chunk_Size {
						cx, cy := sim.chunk_idx_to_chunk_pos(i)
						x, y := sim.to_world_pos(cx, cy, local_x, local_y)
						if idx, ok := sim.world_index(x, y); ok {
							buf[idx] = world.color[idx]
						}
					}
				}
			}
		}
	}
}


render_debug_chunk :: proc(world: ^sim.World) {
	for &chunk, i in world.chunks {
		if sim.chunk_active(&chunk, world.tick) {
		    cx, cy := sim.chunk_idx_to_chunk_pos(i)
			S := sim.Scale
			bound, ok := chunk.active_bound.?
			if !ok do continue
			// CS := sim.Chunk_Size
			x, y := sim.to_world_pos(cx, cy, bound.x, bound.y)
			x2, y2 := sim.to_world_pos(cx, cy, bound.x2, bound.y2)
			rl.DrawRectangleLines(
				i32(x * S),
				i32(y * S),
				i32((x2 - x) * S),
				i32((y2 - y) * S),
				rl.RED,
			)
		}
	}
}
render_tool :: proc(config: ^Game_Config, mouse: ^Mouse_State) {
	switch config.tool_man.curr_tool {
	case .Pipette:
		render_pipette(config, mouse)
	case .Brush:
		render_brush(config, mouse)
	}
}
render_pipette :: proc(config: ^Game_Config, mouse: ^Mouse_State) {
	rl.DrawRectangle(
		i32(mouse.world.x * sim.Scale),
		i32(mouse.world.y * sim.Scale),
		i32(sim.Scale),
		i32(sim.Scale),
		rl.WHITE,
	)
}
render_brush :: proc(config: ^Game_Config, mouse: ^Mouse_State) {

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

get_vel_color :: proc(side: int, vel: f32, max: f32) -> (color: rl.Color) {
	value := abs(vel / max)
	if side > 0 {
		new_r := u8(math.clamp(int(value * 255), 0, 255))
		color = rl.Color{new_r, 0, 0, 255}
	} else if side < 0 {
		new_g := u8(math.clamp(int(value * 255), 0, 255))
		color = rl.Color{0, new_g, 0, 255}
	} else {
		new_b := u8(math.clamp(int(value * 255), 0, 255))
		color = rl.Color{0, 0, new_b, 255}
	}
	return
}

render_particles :: proc(particles: [dynamic]sim.Particle) {
	for &p in particles {
		if p.life <= 0 do continue
		rl.DrawRectangleV(p.pos, {sim.Scale, sim.Scale}, p.color)
	}
}
