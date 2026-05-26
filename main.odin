package main

import rl "vendor:raylib"
T_Scale :: 1
main :: proc() {
	// events queue init
	events := make_event_queues()
	defer delete_event_queues(&events)

	// world init
	world := create_world()
	defer delete_world(&world)

	pixel_buf := make([]rl.Color, WIDTH*HEIGHT)
	defer delete(pixel_buf)
	// raylib window init
	rl.InitWindow(WIDTH * SCALE, HEIGHT * SCALE, "sandfall")
	rl.SetTargetFPS(120)
	rl.HideCursor()
	image := rl.GenImageColor(WIDTH, HEIGHT, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	defer rl.UnloadTexture(texture)

	// main loop
	prev := rl.GetTime()
	acc: f64 = 0
	tick := 0
	for !rl.WindowShouldClose() {
		now := rl.GetTime()
		dt := now - prev
		acc += dt * T_Scale
		prev = now
		track_mouse(&events)
		track_kb()
		for acc >= DT {
			tick += 1
			if tick == 3 do tick = 1
			event_listener(&world, &events)
			update(&world, tick)
			acc -= DT
		}
		build_pixel_buf(&world, pixel_buf)
		rl.UpdateTexture(texture, raw_data(pixel_buf))
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, SCALE, rl.WHITE)
		render_brush(int(rl.GetMouseX() / SCALE), int(rl.GetMouseY() / SCALE))
		rl.DrawFPS(10,10)
		rl.EndDrawing()
	}
}
