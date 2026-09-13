package app

import "core:math"
import g "../game"
import "../profiling"
import rd "../rendering"
import sim "../simulation"
import "core:log"
import "core:prof/spall"
import "core:sync"
import rl "vendor:raylib"

App :: struct {
	game:    g.Game,
	ui:      Ui,
	control: g.Control,
	texture: rl.Texture2D,
	logger:  log.Logger,
}

Ui :: struct {
	show:              bool,
	float_ui:          Float_Ui,
	bound:             rl.Rectangle,
	material_selector: Listview_Control,
	edit_modes:        [Edit_Modes]bool,
}

Edit_Modes :: enum {
	Time_Edit,
	Friction_Text,
	Debug_Render,
}


Float_Ui :: struct {
	bound: rl.Rectangle,
	show:  bool,
}

Listview_Control :: struct {
	choices:      cstring,
	scroll_index: i32,
	active:       i32,
}

when profiling.PROFILE {
	backing: [spall.BUFFER_DEFAULT_SIZE]u8
}
init_app :: proc(app: ^App) {

	// handle, err := os.open(
	// 	fmt.tprintf(".log/FallingSand-%v.log", time.to_unix_seconds(time.now())),
	// 	{.Write, .Create},
	// )
	// defer os.close(handle)
	// assert(err == nil, "Cannot open log file")
	// file_logger := log.create_file_logger(handle)
	// defer log.destroy_file_logger(file_logger)
	// context.logger = file_logger
	app.logger = log.create_console_logger()
	context.logger = app.logger
	when profiling.PROFILE {
		profiling.profiler = spall.context_create("profile.spall")
		profiling.prof_buffer = spall.buffer_create(backing[:], u32(sync.current_thread_id()))
	}
	// create g instance
	g.init_game(&app.game)
	init_ui(&app.ui, app.game.simulation.config)
	g.init_control(&app.control)
	// imgui_rl.init()
	rl.InitWindow(sim.WORLD_WIDTH * sim.SCALE, sim.WORLD_HEIGHT * sim.SCALE, "sandfall") // defer imgui_rl.shutdown()
	rl.SetTargetFPS(120)
	rl.HideCursor()
	// create a texture buffer
	image := rl.GenImageColor(sim.WORLD_WIDTH, sim.WORLD_HEIGHT, rl.BLACK)
	app.texture = rl.LoadTextureFromImage(image)
	rl.UnloadImage(image)
	// imgui.CreateContext()
	// defer imgui.DestroyContext()

	log.info("Initialized Game Struct")
}

run :: proc(a: ^App) {
	TS := sim.TIME_SCALES

	// main loop

	log.info("Starting Game...")
	prev := rl.GetTime()
	acc: f64 = 0
	for !rl.WindowShouldClose() {
		update_input(a)
		consume_action(a)
		now := rl.GetTime()
		if a.game.debugger.on && a.game.debugger.len > 0 {
			update_game_step(&a.game)
		} else {
			acc = update_game(&a.game, acc, now, prev)
		}
		prev = now
		simulation := get_simulation(&a.game)
		g.dispatch_event(simulation, &a.game.events)
		// imgui.ShowDemoWindow()
		// imgui.Render()
		// imgui_rl.render_draw_data(imgui.GetDrawData())
		rl.BeginDrawing()
		// g.update_camera(a.control.cursor, &a.game.camera)
		rl.BeginMode2D(a.game.camera)
		rl.ClearBackground(rl.BLACK)
		rd.render_game(a.texture, &a.game, simulation^)
		draw_ui(a, simulation^)
		rl.EndMode2D()
		rl.EndDrawing()
	}
}

get_simulation :: #force_inline proc(game: ^g.Game) -> ^sim.Simulation {
	if game.debugger.on && game.debugger.len > 0 && game.debugger.cursor != game.debugger.tail {
		return g.current_debug_frame(&game.debugger)
	}
	return &game.simulation
}

ts := sim.TIME_SCALES
update_game_step :: #force_inline proc(game: ^g.Game) {
	debugger := &game.debugger
	if debugger.process_next_frame {
		simulation := &game.simulation
		clear(&simulation.cell_traces)
		simulation.tick += 1
		sim.update_grid(simulation)
		g.copy_to_frame(debugger, simulation)
		g.forward_frame(debugger)
		debugger.process_next_frame = false
	}
}
update_game :: #force_inline proc(game: ^g.Game, acc, now, prev: f64) -> f64 {
	acc := acc
	debugger := &game.debugger
	simulation := &game.simulation
	dt := now - prev
	acc += dt * ts[game.config.time_scale]
	for acc >= sim.DT {
		clear(&simulation.cell_traces)
		sim.update_grid(simulation)
		if debugger.on {
			g.copy_to_frame(debugger, simulation)
		} else {
			g.reset_debugger(debugger)
		}
		// sim.update_particles(&simulation.particles)
		if debugger.len < 1 {
			simulation.tick += 1
		}
		acc -= sim.DT
	}
	return acc
}

delete_app :: proc(app: ^App) {
	rl.CloseWindow()
	log.info("Closing Game...")
	log.destroy_console_logger(app.logger)
	when profiling.PROFILE {
		spall.context_destroy(&profiling.profiler)
		spall.buffer_destroy(&profiling.profiler, &profiling.prof_buffer)
	}
	rl.UnloadTexture(app.texture)
	g.destroy_game(&app.game)
	g.delete_control(&app.control)
	delete_ui(&app.ui)
}


update_input :: #force_inline proc(a: ^App) {
	g.update_mouse_state(a.game.camera, &a.control.cursor)
	overlap :=
		(rl.CheckCollisionPointRec(a.control.cursor.pos, a.ui.bound) && a.ui.show) ||
		(rl.CheckCollisionPointRec(a.control.cursor.pos, a.ui.float_ui.bound) &&
				a.ui.float_ui.show)
	if overlap {
		a.control.cursor.has_prev = false
		a.control.enable_mouse = false
	} else {
		a.control.enable_mouse = true
	}
	g.input_handler(&a.game, &a.control, &a.control.actions)
}

consume_action :: #force_inline proc(app: ^App) {
	game := &app.game
	config := &game.config
	debug_ui := &app.ui
	control := &app.control
	for e in control.actions {
		switch e {

		case .Zoom_In:
		    before := rl.GetScreenToWorld2D(control.cursor.pos, game.camera)
			game.camera.zoom = math.clamp(0.1 + game.camera.zoom, 1, 10.0)
            after := rl.GetScreenToWorld2D(control.cursor.pos, game.camera)
            game.camera.target += before - after
		case .Zoom_Out:
            before := rl.GetScreenToWorld2D(control.cursor.pos, game.camera)
			game.camera.zoom = math.clamp(game.camera.zoom - 0.1, 1, 10.0)
			after := rl.GetScreenToWorld2D(control.cursor.pos, game.camera)
            game.camera.target += before - after
		case .Show_Floating_Ui:
			app.ui.float_ui.show = !app.ui.float_ui.show
			app.ui.float_ui.bound.x = control.cursor.pos.x
			app.ui.float_ui.bound.y = control.cursor.pos.y
		case .Use_Tool:
			g.use_tool(game, control)
		case .Debugger_Backward:
			if game.debugger.on {
				g.backward_frame(&game.debugger)
			}
		case .Debugger_Forward:
			if game.debugger.on {
				g.forward_frame(&game.debugger)
			}
		case .Debugger_Toggle:
			game.debugger.on = !game.debugger.on
		case .Debug_Material_Movement:
			game.config.show_material_movement = !game.config.show_material_movement
		case .Toggle_Brush_Tool:
			g.switch_tool(&game.config, .Brush)
		case .Toggle_Pipette_Tool:
			g.switch_tool(&game.config, game.config.tool_man.prev_tool)
		case .Open_Debug_Menu:
			debug_ui.show = !debug_ui.show
		case .Debug_Off:
			config.debug_render = sim.Debug.Off
		case .Debug_Velocity_Y:
			config.debug_render = sim.Debug.Velocity_Y
		case .Debug_Velocity_X:
			config.debug_render = sim.Debug.Velocity_X
		case .Debug_Chunk:
			config.show_chunk_border = !config.show_chunk_border
		case .Select_Empty:
			config.current_mat = 0
		case .Increase_Tick:
			config.time_scale += 1
			if config.time_scale >= i32(len(sim.TIME_SCALES)) - 1 do config.time_scale = i32(len(sim.TIME_SCALES)) - 1
		case .Decrease_Tick:
			config.time_scale -= 1
			if config.time_scale <= 0 do config.time_scale = 0
		case .Increase_Brush_Size:
			config.brush_size += 1
		case .Decrease_Brush_Size:
			config.brush_size -= 1
			if config.brush_size <= 1 do config.brush_size = 1
		case .Make_Spawn_Point:
			g.create_spawn_point(control.cursor, &game.events, config)
		case .Hot_Reload:
			if !game.events.hot_reload do game.events.hot_reload = true
		}
	}
	clear(&app.control.actions)
}
