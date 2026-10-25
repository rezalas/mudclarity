/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:os"
import "core:testing"

import "../clarity"
import "../components"
import "../testkit"
import "../workspace"

@(test)
test_world_has_a_layout_and_marks_per_area :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_world")
	defer os.remove_all(dir)
	list := testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS), testkit.area_text("B", ""))

	world, error := world_open(paths(list))
	defer world_close(world)
	if !testing.expectf(t, error == "", "%s", error) do return
	testing.expect_value(t, len(world.layouts), 2)
	testing.expect_value(t, len(world.layouts[0].rooms), 3)
	testing.expect_value(t, world.labels[0], "A (a.are)")
	testing.expect_value(t, first_area_with_rooms(world), 0)

	// BASE_ROOMS: 100 has the broken exit (an error); 102 is an orphan and a
	// dead end (warnings); 101 is fine.
	marks := world.marks[0]
	testing.expect_value(t, marks[0], components.Room_Mark{has_finding = true, worst = .Error})
	testing.expect(t, !marks[1].has_finding)
	testing.expect_value(t, marks[2], components.Room_Mark{has_finding = true, worst = .Warning})
}

@(test)
test_accepted_findings_do_not_mark_rooms :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_world_accepted")
	defer os.remove_all(dir)
	list := testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS))
	{
		world, _ := world_open(paths(list))
		defer world_close(world)
		key, _ := workspace.current_finding_key(world.ws, testkit.BROKEN_EXIT_ID)
		testing.expect(t, workspace.set_review(world.ws, key, clarity.REVIEW_ACCEPTED, "", "2026-10-25") == nil)
		testing.expect(t, workspace.save(world.ws) == nil)
	}
	world, _ := world_open(paths(list))
	defer world_close(world)
	testing.expect(t, !world.marks[0][0].has_finding, "room 100's only error is accepted")
}

@(test)
test_area_picker_and_graph_messages :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_areas")
	defer os.remove_all(dir)
	list := testkit.write_world(t, dir, testkit.area_text("A", "#100\nA~\n~\ncity\nS\n"), testkit.area_text("B", testkit.BASE_ROOMS))
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	testing.expect_value(t, s.area, 0)

	s, _ = step(s, Graph{components.Room_Clicked{room = 0}})
	testing.expect_value(t, s.selected_room, 0)
	s, _ = step(s, Graph{components.Pan_Started{}})
	s, _ = step(s, Graph{components.Panned{delta = {5, 7}}})
	testing.expect_value(t, s.graph.camera.pan, [2]f32{5, 7})

	// Picking another area starts it afresh.
	s, _ = step(s, Area_Picked{label = s.world.labels[1]})
	testing.expect_value(t, s.area, 1)
	testing.expect_value(t, s.selected_room, -1)
	testing.expect(t, s.graph.needs_fit)
	testing.expect_value(t, s.graph.camera.pan, [2]f32{})

	// An unknown label changes nothing.
	s, _ = step(s, Area_Picked{label = "nope"})
	testing.expect_value(t, s.area, 1)
}
