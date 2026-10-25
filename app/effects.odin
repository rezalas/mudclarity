/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:strings"

import "gui:skald"

// The Skald Command that carries out an effect.
command_for :: proc(effect: Effect) -> skald.Command(Msg) {
	switch e in effect {
	case Show_Open_Dialog:
		// No filters: filtered dialogs are unreliable on some Linux
		// desktops (vendor/skald/docs/gotchas.md). world_paths checks
		// what was picked.
		return skald.cmd_open_file_dialog(nil, dialog_closed)
	case Load_Request:
		// cmd_thread allocates its job here and the worker frees it, so it
		// must use the heap like everything else that crosses threads.
		context.allocator = runtime.heap_allocator()
		return skald.cmd_thread(Msg, e, load_world)
	case Follow_System_Theme:
		return skald.cmd_set_theme(Msg, skald.theme_system())
	case Quit:
		return skald.cmd_quit(Msg)
	case Redraw_Soon:
		return skald.cmd_delay(0, Msg(Redraw{}))
	}
	return {}
}

// The file dialog's result. Its path is heap-owned and ours to free; the
// Msg carries a temp copy, which lasts until update has run.
@(private = "file")
dialog_closed :: proc(result: skald.File_Dialog_Result) -> Msg {
	if result.cancelled || result.path == "" {
		delete(result.path)
		return Dialog_Cancelled{}
	}
	path := strings.clone(result.path, context.temp_allocator)
	delete(result.path)
	paths := make([]string, 1, context.temp_allocator)
	paths[0] = path
	return Open_Paths{paths = paths}
}

// Files dropped on the window. Their paths are already in the frame arena.
files_dropped :: proc(files: []string) -> Msg {
	return Open_Paths{paths = files}
}
