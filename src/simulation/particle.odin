package simulation

import rl "vendor:raylib"
import sim "../simulation"
import "core:fmt"

Particle :: struct {
	color: rl.Color,
	life: u32,
	pos: rl.Vector2,
	vel: rl.Vector2
}

update_particles :: proc(particles: ^[dynamic]Particle) {
	#reverse for &p, i in particles {
		p.life -= 1
		if p.life <= 0 {
			unordered_remove_dynamic_array(particles, i)
			continue
		}
		p.vel.y += sim.Gravity * sim.Dt32
		p.pos += p.vel * sim.Dt32
	}
}

to_particle :: proc(world: ^World, x, y: int) {
	i := idx(x, y)
	particle := Particle {
		world.color[i],
		tick_from_sec(10),
		{f32( x*4 ), f32( y*4 )},
		{world.vel_x[i] * 25 * f32( world.side[i] ), world.vel_y[i] * 200}
	}
	append(&world.particles, particle)
	remove_material(world, i)
}