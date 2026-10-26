/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:os"
import "core:testing"

import "../components"
import "../testkit"

// Area A is BASE_ROOMS; area B's room 200 leads west into A's room 101.
@(private = "file")
AREA_B :: "#AREA\nB~\nB~\nTester~\n1 50\n200 299\nnormal\ntemperate\n0\n1\nNone~\n#ROOMS\n#200\nGate~\n~\ncity\nD WEST 101 0 0\n~\n~\nS\n#0\n#$\n"

@(private = "file")
open_world :: proc(t: ^testing.T, name: string) -> (s: State, dir, list: string) {
	dir = testkit.temp_dir(t, name)
	list = testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS), AREA_B)
	s = init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	return
}

@(private = "file")
is_redraw :: proc(effect: Effect) -> bool {
	_, ok := effect.(Redraw_Soon)
	return ok
}

@(test)
test_switching_between_rooms_and_areas :: proc(t: ^testing.T) {
	_, effect := step(init(), Center_Chosen{.Areas})
	testing.expect(t, effect == nil, "no world, nothing to switch")

	s, dir, _ := open_world(t, "mudclarity_app_center_switch")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	testing.expect_value(t, s.center, Center_View.Rooms)

	// The map's canvas needs a frame to learn its size before it can fit.
	s, effect = step(s, Center_Chosen{.Areas})
	testing.expect_value(t, s.center, Center_View.Areas)
	testing.expect(t, is_redraw(effect))
	s, effect = step(s, Center_Chosen{.Areas})
	testing.expect(t, effect == nil, "already showing the map")

	s, _ = step(s, Area_Map{components.Fitted{{800, 600}}})
	testing.expect(t, !s.area_map.needs_fit)
	s, _ = step(s, Area_Map{components.Pan_Started{}})
	s, _ = step(s, Area_Map{components.Panned{{5, 7}}})
	pan := s.area_map.camera.pan
	s, _ = step(s, Area_Map{components.Pan_Ended{}})
	testing.expect(t, !s.area_map.is_panning)

	// The map keeps its camera while the room graph is shown.
	s, _ = step(s, Center_Chosen{.Rooms})
	s, _ = step(s, Center_Chosen{.Areas})
	testing.expect_value(t, s.area_map.camera.pan, pan)
}

@(test)
test_clicking_an_area_opens_it :: proc(t: ^testing.T) {
	s, dir, _ := open_world(t, "mudclarity_app_center_click")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	s.selected_room = 1
	effect: Effect

	// The area already shown: back to its graph, selection kept.
	s, _ = step(s, Center_Chosen{.Areas})
	s, effect = step(s, Area_Map{components.Area_Clicked{0}})
	testing.expect_value(t, s.center, Center_View.Rooms)
	testing.expect_value(t, s.area, 0)
	testing.expect_value(t, s.selected_room, 1)
	testing.expect(t, is_redraw(effect))

	// Another area: shown afresh.
	s, _ = step(s, Center_Chosen{.Areas})
	s, _ = step(s, Area_Map{components.Area_Clicked{1}})
	testing.expect_value(t, s.center, Center_View.Rooms)
	testing.expect_value(t, s.area, 1)
	testing.expect_value(t, s.selected_room, -1)
	testing.expect(t, s.graph.needs_fit)

	// An area that doesn't exist changes nothing but the view.
	s, _ = step(s, Center_Chosen{.Areas})
	s, _ = step(s, Area_Map{components.Area_Clicked{7}})
	testing.expect_value(t, s.area, 1)
}

@(test)
test_following_an_exit_leaves_the_map :: proc(t: ^testing.T) {
	s, dir, _ := open_world(t, "mudclarity_app_center_follow")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	effect: Effect

	s, effect = step(s, Exit_Followed{target = 101})
	testing.expect(t, effect == nil, "already on the room graph")

	s, _ = step(s, Center_Chosen{.Areas})
	s, effect = step(s, Exit_Followed{target = 200})
	testing.expect_value(t, s.center, Center_View.Rooms)
	testing.expect_value(t, s.area, 1)
	testing.expect_value(t, s.selected_room, 0)
	testing.expect(t, is_redraw(effect))
}

@(test)
test_a_new_world_starts_on_its_rooms :: proc(t: ^testing.T) {
	s, dir, list := open_world(t, "mudclarity_app_center_reload")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	s, _ = step(s, Center_Chosen{.Areas})
	s, _ = step(s, Area_Map{components.Fitted{{800, 600}}})

	s.generation = 2
	s, _ = step(s, load_now(2, list))
	testing.expect_value(t, s.center, Center_View.Rooms)
	testing.expect(t, s.area_map.needs_fit, "a new world's map is fitted afresh")
}
