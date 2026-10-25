/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:os"
import "core:testing"

@(test)
test_open_button_shows_dialog :: proc(t: ^testing.T) {
	s, effect := step(init(), Open_Requested{})
	_, is_dialog := effect.(Show_Open_Dialog)
	testing.expect(t, is_dialog)

	// Not while a load is running.
	s.loading_path = "busy"
	_, effect = step(s, Open_Requested{})
	testing.expect(t, effect == nil)
}

@(test)
test_world_paths :: proc(t: ^testing.T) {
	// An area list wins, wherever it is.
	got := world_paths(paths("a.are", "/w/AREA.LST", "b.are"))
	testing.expect_value(t, len(got), 1)
	testing.expect_value(t, got[0], "/w/AREA.LST")
	// Otherwise every area file, in order.
	got = world_paths(paths("a.are", "notes.txt", "B.ARE"))
	testing.expect_value(t, len(got), 2)
	testing.expect_value(t, got[1], "B.ARE")
	testing.expect_value(t, len(world_paths(paths("notes.txt"))), 0)
	testing.expect_value(t, len(world_paths(nil)), 0)
}

@(test)
test_open_paths_starts_a_load :: proc(t: ^testing.T) {
	s, effect := step(init(), Open_Paths{paths = paths("/w/area.lst")})
	defer finish(s)
	request, ok := effect.(Load_Request)
	if !testing.expect(t, ok) do return
	defer free_request(request)
	testing.expect_value(t, s.generation, 1)
	testing.expect_value(t, request.generation, 1)
	testing.expect_value(t, s.loading_path, "/w/area.lst")
	testing.expect(t, is_loading(s))
	testing.expect_value(t, request.paths[0], "/w/area.lst")
}

@(test)
test_open_paths_refuses_other_files :: proc(t: ^testing.T) {
	s, effect := step(init(), Open_Paths{paths = paths("notes.txt")})
	defer finish(s)
	testing.expect(t, effect == nil)
	testing.expect(t, s.error != "")
	testing.expect(t, !is_loading(s))
	// Counted anyway, so a refused startup request isn't sent again.
	testing.expect_value(t, s.generation, 1)

	s, _ = step(s, Dismiss_Error{})
	testing.expect_value(t, s.error, "")
}

@(test)
test_loaded_world_opens :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_loaded")
	defer os.remove_all(dir)
	s := init()
	s.generation = 1
	s.loading_path = ""

	s, _ = step(s, load_now(1, list))
	defer finish(s)
	testing.expect_value(t, s.screen, Screen.World)
	testing.expect(t, s.world != nil)
	testing.expect(t, !is_loading(s))
	testing.expect_value(t, s.world.summary.rooms, 3)
	testing.expect_value(t, s.world.summary.severities[.Error], 1)
	testing.expect_value(t, s.world.summary.state_counts[.Open], len(s.world.ws.diagnostics))

	// Opening another world replaces (and frees) the first.
	first := s.world
	s.generation = 2
	s, _ = step(s, load_now(2, list))
	testing.expect(t, s.world != nil && s.world != first)

	s, _ = step(s, Close_World{})
	testing.expect_value(t, s.screen, Screen.Welcome)
	testing.expect(t, s.world == nil)
}

@(test)
test_stale_load_is_dropped :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_stale")
	defer os.remove_all(dir)
	s := init()
	s.generation = 2 // A newer load has started since generation 1

	s, _ = step(s, load_now(1, list)) // Its world must be freed
	defer finish(s)
	testing.expect(t, s.world == nil)
	testing.expect_value(t, s.screen, Screen.Welcome)
}

@(test)
test_failed_load_shows_error :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_failed")
	defer os.remove_all(dir)
	os.remove(list)
	s := init()
	s.generation = 1

	loaded := load_now(1, list)
	testing.expect(t, loaded.world == nil)
	s, _ = step(s, loaded)
	defer finish(s)
	testing.expect_value(t, s.screen, Screen.Welcome)
	testing.expect(t, s.error != "", "the error is shown")
}

@(test)
test_quit_frees_everything :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_quit")
	defer os.remove_all(dir)
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	s, _ = step(s, Open_Paths{paths = paths("notes.txt")}) // Leaves an error string

	effect: Effect
	s, effect = step(s, Quit_Requested{})
	_, is_quit := effect.(Quit)
	testing.expect(t, is_quit)
	testing.expect(t, s.world == nil)
	testing.expect_value(t, s.error, "")
}

@(test)
test_theme_change_follows_system :: proc(t: ^testing.T) {
	_, effect := step(init(), Theme_Changed{})
	_, ok := effect.(Follow_System_Theme)
	testing.expect(t, ok)
}

@(test)
test_loaded_world_asks_for_another_frame :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_redraw")
	defer os.remove_all(dir)
	s := init()
	s.generation = 1
	effect: Effect
	s, effect = step(s, load_now(1, list))
	defer finish(s)
	_, ok := effect.(Redraw_Soon)
	testing.expect(t, ok, "the graph needs a frame with a known size to fit itself")
}
