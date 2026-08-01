package game
import sim "../simulation"
import "core:reflect"
import "core:strings"
import rl "vendor:raylib"


Ui :: struct {
	show: bool,
	bound: rl.Rectangle,
	mat_select: Listview_Control,
	dropdowns: Dropdown_Control,
}

Dropdown_Control :: struct {
	debug_edit_mode: bool,
	time_edit_mode: bool
}

Listview_Control :: struct {
	choices: cstring,
	scroll_index: i32,
	active: i32,
}

create_ui :: proc() -> Ui {
	material_choices, ok := strings.join(reflect.enum_field_names(Material), ";")
	cmaterial_choices := strings.clone_to_cstring(material_choices)
	delete(material_choices)
	if ok != .None {
		panic("fahh")
	}
	return Ui {
		false,
		{10, 10, 250, 300},
		{cmaterial_choices ,0,-1 },
		{false, false},
	}
}

delete_ui :: proc(ui: ^Ui) {
	delete(ui.mat_select.choices)
}

ui_draw :: proc(instance: ^Game) {
	conf := &instance.config;
	dbg_ui := &instance.debug_ui

	rl.DrawRectangleRoundedLines(dbg_ui.bound, 0.1, 20, rl.WHITE)
	mat_as_int := i32( conf.current_mat )
	selected := rl.GuiListView({20, 50, 200, 100},  dbg_ui.mat_select.choices, &dbg_ui.mat_select.scroll_index, &mat_as_int)
	if mat_as_int < 0 do mat_as_int = 0
	conf.current_mat = sim.Material(mat_as_int)

	debug_mode_as_int := i32(conf.debug_render)
	if rl.GuiDropdownBox({20, 20, 50, 25}, "Off;Vy;Vx", &debug_mode_as_int, dbg_ui.dropdowns.debug_edit_mode) {
		dbg_ui.dropdowns.debug_edit_mode = !dbg_ui.dropdowns.debug_edit_mode
		conf.debug_render = sim.Debug(debug_mode_as_int)
	}

	if rl.GuiDropdownBox({20, 160, 50, 25}, "0.01;0.05;0.1;0.5;0.75;1", &conf.time_scale, dbg_ui.dropdowns.time_edit_mode) {
		dbg_ui.dropdowns.time_edit_mode = !dbg_ui.dropdowns.time_edit_mode
	}

	rl.GuiCheckBox({20, 190, 50, 25}, "Show Chunk Border", &conf.show_chunk_border)
}
