package rendering

import "core:log"
import "../profiling"
import sim "../simulation"
import "core:fmt"
import "core:math"
import "core:prof/spall"
import "core:strings"
import rl "vendor:raylib"
import g "../game"

build_pixel_buf :: proc(game: ^g.Game, simulation: sim.Simulation) {
	when profiling.PROFILE {
		spall.SCOPED_EVENT(&profiling.profiler, &profiling.prof_buffer, #procedure)
	}
	debug_mode := game.config.debug_render
	buf := game.pixel_buf
	switch debug_mode {
	case .Velocity_Y:
		build_pixel_index(simulation, buf, proc(idx: int, buf: []rl.Color, simulation: sim.Simulation) {
			if sim.cell_type_match(simulation, idx, .Empty) do buf[idx] = rl.GRAY
			else if sim.cell_type_match(simulation, idx, .Powder) do buf[idx] = get_vel_color(1, simulation.world[idx].vel.y, sim.POWDER.Max_Vy)
			else if sim.cell_type_match(simulation, idx, .Liquid) do buf[idx] = get_vel_color(1, simulation.world[idx].vel.y, sim.LIQUID.Max_Vy)
		})
	case .Velocity_X:
		build_pixel_index(simulation, buf, proc(idx: int, buf: []rl.Color, simulation: sim.Simulation) {
			if sim.cell_type_match(simulation, idx, .Empty) do buf[idx] = rl.GRAY
			else if sim.cell_type_match(simulation, idx, .Powder) do buf[idx] = get_vel_color(int( sim.cell_at(simulation.world, idx).side ), simulation.world[idx].vel.x, sim.POWDER.Max_Vx)
			else if sim.cell_type_match(simulation, idx, .Liquid) do buf[idx] = get_vel_color(int( sim.cell_at(simulation.world, idx).side ), simulation.world[idx].vel.x, sim.LIQUID.Max_Vx)
		})

	case .Off:
		log.panic("This shouldn't be reachable")
	}

}
build_pixel_index :: proc(
	simulation: sim.Simulation,
	buf: []rl.Color,
	fill_color: proc(idx: int, buf: []rl.Color, simulation: sim.Simulation),
) {
	for _, idx in simulation.world {
		fill_color(idx, buf, simulation)
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

draw_particles :: proc(particles: [dynamic]sim.Particle) {
	for &p in particles {
		if p.life <= 0 do continue
		rl.DrawRectangleV(p.pos, {sim.SCALE, sim.SCALE}, p.color)
	}
}

render_game :: proc(texture: rl.Texture, game: ^g.Game, simulation: sim.Simulation ) {
	
	if game.config.debug_render != .Off {
		build_pixel_buf(game, simulation)
		rl.UpdateTexture(texture, raw_data(game.pixel_buf))
	} else {
		rl.UpdateTexture(texture, raw_data(simulation.frame))
	}
	rl.DrawTextureEx(texture, {0, 0}, 0, sim.SCALE, rl.WHITE)
}