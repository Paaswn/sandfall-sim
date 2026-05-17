package main

import rl "vendor:raylib"

build_pixel :: proc(world: ^World) {
	for cell, idx in world.grid {
		pixel := world.pixel
		switch cell {
		case .Empty:
			pixel[idx] = rl.BLACK

		case .Sand:
			pixel[idx] = rl.BEIGE
		}
	}
}

render_brush :: proc(mx, my: int) {
    if spawn_radius == 0 {
     	rl.DrawRectangle(i32(mx * SCALE), i32(my * SCALE), i32(SCALE), i32(SCALE), rl.WHITE)
        return
    }
    for y in my - spawn_radius ..= my + spawn_radius {
		for x in mx - spawn_radius ..= mx + spawn_radius {
			if is_outside(x, y) {
				continue
			}
			dx := x - mx
			dy := y - my
			dist2 := dx*dx + dy*dy
			outer := spawn_radius * spawn_radius
			inner := ( spawn_radius - 1  )* ( spawn_radius - 1  )
			if dist2 <= outer && dist2 >= inner {
    			rl.DrawRectangle(i32(x * SCALE), i32(y * SCALE), i32(SCALE), i32(SCALE), rl.WHITE)
			} 
		}
	}
}