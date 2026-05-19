package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

World :: struct {
	vel_x: []f32,
	vel_y: []f32,
	grid:  []Material,
	color: []rl.Color,
}

Material :: enum u8 {
	Empty,
	Sand,
}

create_world :: proc() -> World {
	return World {
		make([]f32, WIDTH * HEIGHT),
		make([]f32, WIDTH * HEIGHT),
		make([]Material, WIDTH * HEIGHT),
		make([]rl.Color, WIDTH * HEIGHT),
	}
}

delete_world :: proc(world: ^World) {
	delete(world.vel_x)
	delete(world.vel_y)
	delete(world.grid)
	delete(world.color)
}

idx :: proc(x, y: int) -> int {
	idx := y * WIDTH + x
	return idx
}

is_outside :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > WIDTH - 1 || y > HEIGHT - 1
}


circle_brush_spawn :: proc(world: ^World, se: Spawn_Event) {
	for x in se.x - se.r ..= se.x + se.r {
		for y in se.y - se.r ..= se.y + se.r {
			if is_outside(x, y) {
				continue
			}
			dx := x - se.x
			dy := y - se.y
			if dx * dx + dy * dy <= se.r * se.r {
				spawn_material(world, se.material, x, y)
			}
		}
	}
}

spawn_material :: proc(world: ^World, material: Material, x, y: int) {
	i := idx(x, y)
	if world.grid[i] == material do return
	world.grid[i] = material
	world.color[i] = get_material_color(material, x, y)
}
// only move material, and color
// vx vy will be reset in the next update any way but also
// reset vx vy to 0 as a guardrail
move_cell :: proc(world: ^World, to, now: int) {
	world.grid[to] = world.grid[now]
	world.color[to] = world.color[now]
	world.grid[now] = .Empty
	world.vel_x[now] = 0
	world.vel_y[now] = 0
}

update :: proc(world: ^World, tick: int) {
	for y := HEIGHT - 2; y >= 0; y -= 1 {
		if tick % 2 == 0 {
			for x := 0; x < WIDTH; x += 1 {
				update_row(world, x, y)
			}
		} else {
			for x := WIDTH - 1; x >= 0; x -= 1 {
				update_row(world, x, y)
			}
		}
	}
}

should_cell_sleep :: proc(world: ^World, x, y: int) {
    
}
update_row :: proc(world: ^World, x, y: int) {
    now := idx(x,y) // always in border no need to check
    vx := world.vel_x
    vy := world.vel_y
    grid := world.grid
    if grid[now] == .Empty { // skip expensive calc for empty cell immediately
        // reset velocity for empty cell to 0. This is just a backup, normally every moved cell will set their old vel to 0
        // build_pixel already handle render empty pixel so no need to set here
        vx[now] = 0
        vy[now] = 0
        return
    }
    vy[now] += GRAVITY * f32(DT) // apply gravity to an actual cell
}

update_x :: proc(world: ^World, x, y: int) -> bool {
	
}

update_y :: proc(world: ^World, x, y: int) -> bool {
	
}

// deprecated
explosion :: proc(world: ^World, ee: Explosion_Event) {
	vx := world.vel_x
	vy := world.vel_y
	for x in ee.x - ee.r ..= ee.x + ee.r {
		for y in ee.y - ee.r ..= ee.y + ee.r {
			if is_outside(x, y) {
				continue
			}
			dx := x - ee.x
			dy := y - ee.y
			dist_sq := dx * dx + dy * dy
			if dist_sq > 0 && dist_sq <= ee.r * ee.r {
				i := idx(x, y)
				if world.grid[i] != .Empty {
					dist := math.sqrt(f32(dist_sq))
					dir_x := f32(dx) / dist
					dir_y := f32(dy) / dist
					falloff := 1.0 - dist / f32(ee.r)
					weighted_force := ee.force * falloff
					vx[i] += dir_x * weighted_force
					vy[i] += dir_y * weighted_force
				}
			}
			if dist_sq > 0 && dist_sq <= ee.r * ee.r / 4 {
				i := idx(x, y)
				if world.grid[i] != .Empty {
					world.grid[i] = .Empty
				}
			}
		}
	}
}
