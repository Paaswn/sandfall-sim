package main

import "core:fmt"
import rl "vendor:raylib"

DT: f64 : 1.0 / 60.0
WIDTH :: 250
HEIGHT :: 180
GRAVITY: f32 : 45.0
SIDE_ACCEL: f32 : 20
SIDE_FRICTION: f32 : 0.75
SCALE :: 4
spawn_radius := 4
MAX_SAND_VY :: 10

World :: struct {
	vel_y: []f32,
	vel_x: []f32,
	grid:  []Material,
	pixel: []rl.Color,
}

Spawn_Event :: struct {
	x:        int,
	y:        int,
	r:        int,
	material: Material,
}

main :: proc() {
	// events queue init
	events := make([dynamic]Spawn_Event)
	defer delete(events)

	// world init
	world := World {
		make([]f32, WIDTH * HEIGHT),
		make([]f32, WIDTH * HEIGHT),
		make([]Material, WIDTH * HEIGHT),
		make([]rl.Color, WIDTH * HEIGHT),
	}
	defer delete(world.vel_y)
	defer delete(world.vel_x)
	defer delete(world.grid)
	defer delete(world.pixel)

	// raylib window init
	rl.InitWindow(WIDTH * SCALE, HEIGHT * SCALE, "sandfall")
	rl.HideCursor()
	image := rl.GenImageColor(WIDTH, HEIGHT, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	defer rl.UnloadTexture(texture)

	// main loop
	prev := rl.GetTime()
	acc: f64 = 0
	for !rl.WindowShouldClose() {
		now := rl.GetTime()
		dt := now - prev
		acc += dt
		prev = now
		track_mouse(&events)
		for acc >= DT {
			event_listener(&world, &events)
			update(&world)
			acc -= DT
		}
		build_pixel(&world)
		rl.UpdateTexture(texture, raw_data(world.pixel))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, SCALE, rl.WHITE)
		render_brush(int(rl.GetMouseX()/SCALE), int(rl.GetMouseY()/SCALE))
		rl.EndDrawing()
	}
}

Material :: enum u8 {
	Empty,
	Sand,
}

track_mouse :: proc(events: ^[dynamic]Spawn_Event) {
	mouse_scale_x := int(rl.GetMouseX() / SCALE)
	mouse_scale_y := int(rl.GetMouseY() / SCALE)
	if rl.IsMouseButtonDown(.LEFT) {
		if len(events) < 512 {
			append(events, Spawn_Event{mouse_scale_x, mouse_scale_y, spawn_radius, .Sand})
		}
	}
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() > 0 {
		spawn_radius += 1
	} else if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() < 0 {
		spawn_radius -= 1
		if spawn_radius <= 0 {
			spawn_radius = 0
		}
	}
}

update :: proc(world: ^World) {
	update_grid(world)
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
spawn_circle :: proc(world: ^World, se: Spawn_Event) {
	for x in se.x - se.r ..= se.x + se.r {
		for y in se.y - se.r ..= se.y + se.r {
			if is_outside(x, y) {
				continue
			}
			dx := x - se.x
			dy := y - se.y
			if dx * dx + dy * dy <= se.r * se.r {
				i := idx(x, y)
				if world.grid[i] == .Sand do continue
				world.grid[i] = .Sand
			}
		}
	}
}


event_listener :: proc(world: ^World, events: ^[dynamic]Spawn_Event) {
	for e in events {
		spawn_circle(world, e)
	}
	clear(events)
}

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

idx :: proc(x, y: int) -> int {
	idx := y * WIDTH + x
	assert(idx < WIDTH * HEIGHT)
	return idx
}

is_outside :: proc(x, y: int) -> bool {
	return x < 0 || y < 0 || x > WIDTH - 1 || y > HEIGHT - 1
}

update_grid :: proc(world: ^World) {
	grid := world.grid
	vy := world.vel_y
	vx := world.vel_x
	for y := HEIGHT - 2; y >= 0; y -= 1 {
		column_loop: for x in 0 ..< WIDTH {
			now := idx(x, y)
			if grid[now] == .Empty {
				vy[now] = 0
				continue
			}
			vy[now] += GRAVITY * f32(DT)
			step_y := clamp(int(vy[now]), 1, MAX_SAND_VY)
			target_y := y
			for s in 1 ..= step_y { 	// loop through possible step to check
				if is_outside(x, y + s) {
					vy[now] = 0
					break
				}

				if grid[idx(x, y + s)] == .Empty {
					target_y = y + s
				} else { 	// if below isn't Empty just break and set the current velocity to 0
					vy[now] = 0
					break
				}
			}
			if target_y != y {
				grid[idx(x, target_y)] = grid[now] // move material to target
				vy[idx(x, target_y)] = vy[now] // move velocity to target

				grid[now] = .Empty
				vy[now] = 0 // clear old velocity
				continue
			}
			for side in ([]int{-1, 1}) {
				target_x := x + side
				target_y := y + 1
				if is_outside(target_x, target_y) {
					continue
				}
				to := idx(target_x, target_y)
				if grid[to] == .Empty {
					vx[now] += SIDE_ACCEL * f32(side) * f32(DT)
					if abs(vx[now]) >= 1.0 {
						grid[now] = .Empty
						grid[to] = .Sand
						vx[to] = 0
						vy[to] = vy[now] * 0.4
						vx[now] = 0
						vy[now] = 0
					}
					continue column_loop
				}
			}
			vx[now] = 0
			vy[now] = 0
		}
	}
}

spawn :: proc(world: ^World) {
	world.grid[5] = .Sand
}

// @(test)
// test_loop :: proc(t: ^testing.T) {
// 	grid := make([]Cell, WIDTH * HEIGHT)
// 	grid[250] = Cell.Sand
// 	testing.expect(t, grid[getIdx(WIDTH - 1, HEIGHT - 1)] == Cell.Empty)
// }
