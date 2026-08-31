package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:prof/spall"
import "core:sync"
import "core:time"
import "game"
import "profiling"
import sim "simulation"
import rl "vendor:raylib"
// import imgui "../vendor/odin-imgui"
// import imgui_rl "../vendor/imgui_impl_raylib"

main :: proc() {
	// handle, err := os.open(
	// 	fmt.tprintf(".log/FallingSand-%v.log", time.to_unix_seconds(time.now())),
	// 	{.Write, .Create},
	// )
	// defer os.close(handle)
	// assert(err == nil, "Cannot open log file")
	// file_logger := log.create_file_logger(handle)
	// defer log.destroy_file_logger(file_logger)
	// context.logger = file_logger
	console_logger := log.create_console_logger()
	defer log.destroy_console_logger(console_logger)
	context.logger = console_logger
	when profiling.PROFILE {
		profiling.profiler = spall.context_create("profile.spall")
		defer spall.context_destroy(&profiling.profiler)
		backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
		defer delete(backing)

		profiling.prof_buffer = spall.buffer_create(backing, u32(sync.current_thread_id()))
		defer spall.buffer_destroy(&profiling.profiler, &profiling.prof_buffer)
	}
	// imgui init
	// imgui.CreateContext()
	// defer imgui.DestroyContext()

	// imgui_rl.init()
	// defer imgui_rl.shutdown()
	// raylib window init
	rl.InitWindow(sim.World_Width * sim.Scale, sim.World_Height * sim.Scale, "sandfall")
	rl.SetTargetFPS(120)
	rl.HideCursor()
	// create a texture buffer
	image := rl.GenImageColor(sim.World_Width, sim.World_Height, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	defer rl.UnloadTexture(texture)

	// create game instance
	instance: game.Game
	game.create_game(&instance)
	defer game.delete_game(&instance)
	log.info("Initialized Game struct")

	world := &instance.world
	events := &instance.events
	pixel_buf := instance.pixel_buf
	config := &instance.config
	debugger := &instance.debugger
	TS := sim.Time_Scales

	// main loop
	prev := rl.GetTime()
	acc: f64 = 0

	log.info("Starting Game...")
	for !rl.WindowShouldClose() {

		game.update_mouse_state(&instance.mouse)
		overlap :=
			(rl.CheckCollisionPointRec(instance.mouse.pos, instance.debug_ui.bound) &&
				instance.debug_ui.show) ||
			(rl.CheckCollisionPointRec(instance.mouse.pos, instance.debug_ui.float_uis.bound) &&
					instance.debug_ui.float_uis.show)
		if overlap {
			instance.mouse.has_prev = false
		} else {
			game.mouse_handler(&instance)
		}
		game.keyboard_handler(&instance)
		now := rl.GetTime()
		if debugger.on && debugger.len >= game.Debugger_Size {
    		world = game.current_debug_frame(debugger)
    		if debugger.process_next_frame {
    			world = &instance.world
    			clear(&world.movement)
    			world.tick += 1
    			sim.update_grid(world)
    			game.dispatch_event(world, events)
    			game.copy_to_frame(debugger, world)
    			game.forward_frame(debugger)
    			debugger.process_next_frame = false
    		}
		} else {
    		dt := now - prev
    		acc += dt * TS[config.time_scale]
			for acc >= sim.Dt {
				world = &instance.world
				clear(&world.movement)
				sim.update_grid(world)
				game.dispatch_event(world, events)
				if debugger.on {
					game.copy_to_frame(debugger, world)
				} else {
					game.reset_debugger(debugger)
				}
				sim.update_particles(&world.particles)
				if debugger.len < game.Debugger_Size {
					world.tick += 1
				}
				acc -= sim.Dt
			}
		}
		prev = now
		
		if config.debug_render != .Off {
			game.build_pixel_buf(&instance, world)
			rl.UpdateTexture(texture, raw_data(pixel_buf))
		} else {
			rl.UpdateTexture(texture, raw_data(world.color))
		}
		// imgui_rl.process_events()
		// imgui_rl.new_frame()
		// imgui.NewFrame()
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, sim.Scale, rl.WHITE)
		// game.render_particles(world.particles)
		if config.show_material_movement {
			for p in world.movement {
				np := sim.Scale * p
				rl.DrawLine(i32(np.x) + 2, i32(np.y) + 2, i32(np.z) + 2, i32(np.w) + 2, rl.PINK)
			}
		}

		for i: i32 = 0; i <= sim.World_Height; i += sim.Chunk_Size {
			rl.DrawLine(0, i*sim.Scale, sim.World_Width*sim.Scale, i*sim.Scale, {255, 255, 255, 89})
		}
		for i: i32 = 0; i <= sim.World_Width; i += sim.Chunk_Size {
			rl.DrawLine(i*sim.Scale, 0, i*sim.Scale, sim.World_Height*sim.Scale, {255, 255, 255, 89})
		}
		if config.show_chunk_border {
			game.render_debug_chunk(world)
		}

		if debugger.on {
			rl.DrawText(
				fmt.ctprintf(
					"Oldest Tick:  %v\nCurrent Tick: %v\nLatest Tick:  %v\nMain Tick:    %v",
					game.first_debug_frame(debugger).tick,
					game.current_debug_frame(debugger).tick,
					game.last_debug_frame(debugger).tick,
					instance.world.tick,
				),
				500,
				500,
				20,
				rl.WHITE,
			)
		}
		if instance.debug_ui.show {
			game.draw_ui(&instance)
			rl.DrawFPS(100, 20)
		}

		if instance.debug_ui.float_uis.show {
			game.material_list_selector(
				config,
				&instance.debug_ui,
				instance.debug_ui.float_uis.bound,
			)
		}
		game.render_tool(config, &instance.mouse)
		// imgui.ShowDemoWindow()
		// imgui.Render()
		// imgui_rl.render_draw_data(imgui.GetDrawData())
		rl.EndDrawing()
	}
	log.info("Closing Game...")
}


on_window_resize :: proc() {
	if rl.IsWindowResized() {
		rl.SetWindowSize(rl.GetRenderWidth(), rl.GetRenderHeight())
	}
}
