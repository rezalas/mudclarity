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

// Area A: 100 north to 101, 101 up to 102 (level 1) and east to B's 200.
// Area B: 200, west back to 101.
@(private = "file")
A_ROOMS :: "#100\nA~\n~\ncity\nD NORTH 101 0 0\n~\n~\nS\n#101\nB~\n~\ncity\nD SOUTH 100 0 0\n~\n~\nD UP 102 0 0\n~\n~\nD EAST 200 0 0\n~\n~\nS\n#102\nC~\n~\ncity\nD DOWN 101 0 0\n~\n~\nS\n"
@(private = "file")
B_AREA :: "#AREA\nB~\nB~\nTester~\n1 50\n200 299\nnormal\ntemperate\n0\n1\nNone~\n#ROOMS\n#200\nGate~\n~\ncity\nD WEST 101 0 0\n~\n~\nS\n#0\n#$\n"

@(private = "file")
open_keys_world :: proc(t: ^testing.T, name: string) -> (s: State, dir: string) {
	dir = testkit.temp_dir(t, name)
	list := testkit.write_world(t, dir, testkit.area_text("A", A_ROOMS), B_AREA)
	s = init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	return
}

@(test)
test_arrow_keys_follow_exits :: proc(t: ^testing.T) {
	s, dir := open_keys_world(t, "mudclarity_app_room_keys")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return

	// No room selected: the host does nothing (the graph selects one).
	s, _ = step(s, Graph{components.Exit_Key{.North}})
	testing.expect_value(t, s.selected_room, -1)

	s, _ = step(s, Graph{components.Room_Clicked{0}}) // Room 100
	s, _ = step(s, Graph{components.Exit_Key{.North}})
	testing.expect_value(t, s.selected_room, 1) // 101
	s, _ = step(s, Graph{components.Exit_Key{.West}})
	testing.expect_value(t, s.selected_room, 1) // No exit west: stays

	// Up follows the up exit, which changes level.
	s, _ = step(s, Graph{components.Exit_Key{.Up}})
	testing.expect_value(t, s.selected_room, 2)
	testing.expect_value(t, s.graph.level, 1)
	s, _ = step(s, Graph{components.Exit_Key{.Down}})
	testing.expect_value(t, s.selected_room, 1)
	testing.expect_value(t, s.graph.level, 0)

	// An exit into another area switches to it.
	s, _ = step(s, Graph{components.Exit_Key{.East}})
	testing.expect_value(t, s.area, 1)
	testing.expect_value(t, s.selected_room, 0)
	s, _ = step(s, Graph{components.Exit_Key{.West}})
	testing.expect_value(t, s.area, 0)
	testing.expect_value(t, s.selected_room, 1)
}

@(test)
test_page_keys_change_level_without_an_exit :: proc(t: ^testing.T) {
	s, dir := open_keys_world(t, "mudclarity_app_room_keys_level")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	s, _ = step(s, Graph{components.Room_Clicked{0}}) // 100 has no up exit
	s, _ = step(s, Graph{components.Exit_Key{.Up}})
	testing.expect_value(t, s.selected_room, 0)
	testing.expect_value(t, s.graph.level, 1)
	s, _ = step(s, Graph{components.Exit_Key{.Down}})
	testing.expect_value(t, s.graph.level, 0)
}

@(test)
test_escape_and_click_away_deselect :: proc(t: ^testing.T) {
	s, dir := open_keys_world(t, "mudclarity_app_room_keys_deselect")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return

	s, _ = step(s, Graph{components.Room_Clicked{1}})
	s, _ = step(s, Graph{components.Room_Deselected{}})
	testing.expect_value(t, s.selected_room, -1)

	// A press on empty space that barely moves is a click: deselect.
	s, _ = step(s, Graph{components.Room_Clicked{1}})
	s, _ = step(s, Graph{components.Pan_Started{}})
	s, _ = step(s, Graph{components.Panned{{2, 1}}})
	s, _ = step(s, Graph{components.Pan_Ended{}})
	testing.expect_value(t, s.selected_room, -1)

	// A real drag pans and keeps the selection.
	s, _ = step(s, Graph{components.Room_Clicked{1}})
	s, _ = step(s, Graph{components.Pan_Started{}})
	s, _ = step(s, Graph{components.Panned{{30, 0}}})
	s, _ = step(s, Graph{components.Pan_Ended{}})
	testing.expect_value(t, s.selected_room, 1)
}

@(test)
test_room_graph_keys_are_listed :: proc(t: ^testing.T) {
	n := 0
	for b in key_bindings() {
		if b.scope == .Room_Graph {
			n += 1
		}
	}
	testing.expect_value(t, n, len(components.ROOM_GRAPH_KEYS))
}
