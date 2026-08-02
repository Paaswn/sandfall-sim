package simulation

import rl "vendor:raylib"
import sim "../simulation"
import "core:fmt"

Particle :: struct {
	material: Material,
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
