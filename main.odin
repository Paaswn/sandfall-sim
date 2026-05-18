package main

import rl "vendor:raylib"

main :: proc() {
	// events queue init
	events := make([dynamic]Spawn_Event)
	defer delete(events)

	// world init
	world := create_world()
	defer delete_world(&world)

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
		track_kb()
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

