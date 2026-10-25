/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:os"
import "core:testing"

import "../testkit"

// Area A is BASE_ROOMS (100 <-> 101, 100 east to the missing 150, lone 102).
// Area B (vnums 200-299) has room 200, with an exit west into area A's
// room 101 and a look-only exit north.
@(private = "file")
TWO_AREAS_B :: "#AREA\nB~\nB~\nTester~\n1 50\n200 299\nnormal\ntemperate\n0\n1\nNone~\n#ROOMS\n#200\nGate~\n~\ncity\nD WEST 101 0 0\n~\n~\nD NORTH 0 0 0\n~\n~\nS\n#0\n#$\n"

@(private = "file")
open_two_areas :: proc(t: ^testing.T, name: string) -> (s: State, dir: string) {
	dir = testkit.temp_dir(t, name)
	list := testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS), TWO_AREAS_B)
	s = init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	return s, dir
}

@(test)
test_inspector_data_resolves_exits_and_findings :: proc(t: ^testing.T) {
	s, dir := open_two_areas(t, "mudclarity_app_inspector")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return

	testing.expect(t, inspector_data(s).room == nil, "nothing selected yet")

	s.selected_room = 0 // Room 100
	d := inspector_data(s)
	testing.expect_value(t, d.room.vnum, 100)
	testing.expect_value(t, len(d.exits), 2)
	north, east := d.exits[0], d.exits[1] // Direction order
	testing.expect_value(t, north.exit.target, 101)
	testing.expect_value(t, north.target_name, "B")
	testing.expect_value(t, north.elsewhere, "")
	testing.expect(t, !north.is_missing)
	testing.expect_value(t, east.exit.target, 150)
	testing.expect(t, east.is_missing)
	testing.expect_value(t, len(d.findings), 1)
	testing.expect_value(t, d.findings[0].diagnostic.check, .Broken_Exit)

	// Area B's room: an exit into area A, and a look-only one.
	s.area, s.selected_room = 1, 0
	d = inspector_data(s)
	testing.expect_value(t, len(d.exits), 2)
	look, west := d.exits[0], d.exits[1]
	testing.expect_value(t, look.exit.target, 0)
	testing.expect(t, !look.is_missing, "look-only exits are not missing")
	testing.expect_value(t, west.elsewhere, s.world.labels[0])
	testing.expect_value(t, west.target_name, "B")
}

@(test)
test_following_exits :: proc(t: ^testing.T) {
	s, dir := open_two_areas(t, "mudclarity_app_follow")
	defer os.remove_all(dir)
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return

	// Within the area: selects the room and asks the graph to centre on it.
	s, _ = step(s, Exit_Followed{target = 101})
	testing.expect_value(t, s.area, 0)
	testing.expect_value(t, s.selected_room, 1)
	testing.expect_value(t, s.graph.focus, 1) // Not fitted yet, so pending

	// Into another area: switches area first.
	s, _ = step(s, Exit_Followed{target = 200})
	testing.expect_value(t, s.area, 1)
	testing.expect_value(t, s.selected_room, 0)

	// Unknown and look-only vnums change nothing.
	before := s
	s, _ = step(s, Exit_Followed{target = 150})
	testing.expect_value(t, s.selected_room, before.selected_room)
	s, _ = step(s, Exit_Followed{target = 0})
	testing.expect_value(t, s.area, before.area)
}
