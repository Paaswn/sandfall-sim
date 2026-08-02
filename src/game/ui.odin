package game
import sim "../simulation"
import "core:reflect"
import "core:strings"
import rl "vendor:raylib"

Ui_Manager :: struct {
	show: bool,
	float_uis: Float_Ui,
	bound: rl.Rectangle,
	mat_select: Listview_Control,
	edit_modes: [Edit_Modes]bool,
}

Edit_Modes :: enum {
	Time_Edit,
	Friction_Text,
	Debug_Render
}


Float_Ui :: struct {
	bound: rl.Rectangle,
	show: bool
}

Listview_Control :: struct {
	choices: cstring,
	scroll_index: i32,
	active: i32,
}

create_ui :: proc() -> Ui_Manager {
	material_choices, ok := strings.join(reflect.enum_field_names(Material), ";")
	cmaterial_choices := strings.clone_to_cstring(material_choices)
	delete(material_choices)
	if ok != .None {
		panic("fahh")
	}
	return Ui_Manager {
		false,
		{{0, 0, 200, 100 }, false },
		{10, 10, 250, 600},
		{cmaterial_choices ,0,-1 },
		[Edit_Modes]bool {
			.Time_Edit = false,
			.Friction_Text = false,
			.Debug_Render = false
		}
	}
}

delete_ui :: proc(ui: ^Ui_Manager) {
	delete(ui.mat_select.choices)
}

draw_ui :: proc(instance: ^Game) {
	conf := &instance.config;
	dbg_ui := &instance.debug_ui
	edit_modes := &dbg_ui.edit_modes
	rl.DrawRectangleRoundedLines(dbg_ui.bound, 0.1, 20, rl.WHITE)
	material_list_selector(conf, dbg_ui, { 20, 50, 200, 100 })
	when ODIN_DEBUG {
		debug_mode_as_int := i32(conf.debug_render)
		if rl.GuiDropdownBox({20, 20, 50, 25}, "Off;Vy;Vx", &debug_mode_as_int, edit_modes[.Debug_Render]) {
			edit_modes[.Debug_Render] = !edit_modes[.Debug_Render]
			conf.debug_render = sim.Debug(debug_mode_as_int)
		}
	}
	if rl.GuiDropdownBox({20, 160, 50, 25}, "0.01;0.05;0.1;0.5;0.75;1", &conf.time_scale, edit_modes[.Time_Edit]) {
		edit_modes[.Time_Edit] = !edit_modes[.Time_Edit]
	}

	rl.GuiCheckBox({20, 190, 50, 25}, "Show Chunk Border", &conf.show_chunk_border)

	ui_draw_next(dbg_ui, proc() {
	})
}

ui_draw_first :: proc(manager: ^Ui_Manager) {
	
}

ui_draw_next :: proc(manager: ^Ui_Manager, ui_elem: proc()) {
	ui_elem()
}

ui_draw_last :: proc(manager: ^Ui_Manager) {
	rl.DrawRectangleRoundedLines(manager.bound, 0.1, 20, rl.WHITE)
	manager.bound = {20,20, 100, 100}
}
material_list_selector :: #force_inline proc(conf: ^Game_Config, dbg_ui: ^Ui_Manager, rect: rl.Rectangle) {
	mat_as_int := i32( conf.current_mat )
	selected := rl.GuiListView(rect,  dbg_ui.mat_select.choices, &dbg_ui.mat_select.scroll_index, &mat_as_int)
	if mat_as_int < 0 do mat_as_int = 0
	conf.current_mat = sim.Material(mat_as_int)
}
