/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:fmt"
import "core:mem"

import "gui:skald"

/*
 The GUI: an Elm-style Skald app. state.odin and msg.odin hold the State
 and Msg types, update.odin advances the state, effects.odin turns effects
 into Skald commands, loading.odin opens worlds off the GUI thread, and
 there is one file per screen. Reusable pieces live in package components.
*/

// Open the window and run until it closes. `paths` (an area.lst, or .are
// files) are opened straight away if given. Debug builds report memory the
// GUI leaked when the window closes.
run :: proc(paths: []string) {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
		defer report_leaks(&track)
	}
	startup_paths = paths
	startup_store = settings_store_open()
	defer settings_store_close(startup_store)
	skald.run(
		skald.App(State, Msg) {
			title = "Mud Clarity",
			size = {1280, 800},
			theme = theme_for(startup_store.loaded.settings),
			init = init,
			update = update,
			view = view,
			on_system_theme_change = proc(_: skald.System_Theme) -> Msg {return Theme_Changed{}},
			on_close_request = proc() -> Msg {return Quit_Requested{}},
		},
	)
}

@(private = "file")
report_leaks :: proc(track: ^mem.Tracking_Allocator) {
	for _, leak in track.allocation_map {
		fmt.eprintfln("mudclarity: leaked %d bytes at %v", leak.size, leak.location)
	}
	for bad in track.bad_free_array {
		fmt.eprintfln("mudclarity: bad free at %v", bad.location)
	}
	mem.tracking_allocator_destroy(track)
}
