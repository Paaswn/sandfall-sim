package game

import "core:log"
import "../profiling"
import sim "../simulation"
import "core:fmt"
import "core:math"
import "core:prof/spall"
import "core:strings"
import rl "vendor:raylib"

Mouse_State :: Mouse

build_pixel_buf :: proc(game: ^Game, world: ^World) {
	when profiling.PROFILE {
		spall.SCOPED_EVENT(&profiling.profiler, &profiling.prof_buffer, #procedure)
	}
	debug_mode := game.config.debug_render
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
		log.panic("This shouldn't be reachable")
	}

}
build_pixel_index :: proc(
	world: ^sim.World,
	buf: []rl.Color,
	fill_color: proc(idx: int, buf: []rl.Color, world: ^sim.World),
) {
	for _, idx in world.grid {
		fill_color(idx, buf, world)
	}
}


render_debug_chunk :: proc(world: ^sim.World) {
	@(static) num: [9]cstring = {"0", "1", "2", "3", "4", "5", "6", "7", "8"}
	for &chunk, i in world.chunks {
		if sim.chunk_active(&chunk, world.tick) {
			S :: sim.Scale
			bound, ok := chunk.active_bound.?
			cp := sim.to_chunk_pos(i)
			pos := sim.to_world_pos(cp, {0, 0})
			color := rl.GREEN
			color.a = 89
			rl.DrawRectangleLines(
				i32(pos.x * S),
				i32(pos.y * S),
				i32(sim.Chunk_Size * S),
				i32(sim.Chunk_Size * S),
				color,
			)
			// if !ok do continue
			// CS := sim.Chunk_Size
			i := world.tick - chunk.last_bound_reset
			j := world.tick - chunk.last_updated_tick
			to_reset: cstring
			chunk_age: cstring
			if i >= len(num) {
				to_reset = fmt.ctprint(i)
			} else {
				to_reset = num[i]
			}
			if j >= len(num) {
				chunk_age = fmt.ctprint(j)
			} else {
				chunk_age = num[j]
			}
			rl.DrawText(
				fmt.ctprint(to_reset, chunk_age),
				i32((pos.x + sim.Chunk_Size / 2) * S - 20),
				i32((pos.y + sim.Chunk_Size / 2) * S),
				20,
				rl.WHITE,
			)
			ok or_continue
			pos = sim.to_world_pos(cp, {bound.x, bound.y})
			x, y := pos.x, pos.y
			pos2 := sim.to_world_pos(cp, {bound.x2, bound.y2})
			x2, y2 := pos2.x, pos2.y
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
