/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:testing"

@(test)
test_dead_end_room :: proc(t: ^testing.T) {
	// 102 can be entered but has no way out (a look-only exit doesn't count).
	text := test_area("a", 100, 199, rooms(room(100, sections(exit("NORTH", 101), exit("EAST", 102))), room(101, exit("SOUTH", 100)), room(102, exit("WEST", 0))))
	diagnostics := run_one(t, text)
	expect_one(t, diagnostics, .Dead_End_Room, .Warning, line = line_of(text, "#102"), vnum = 102)
	expect_none(t, diagnostics, .Orphan_Room)
}

@(test)
test_orphan_room :: proc(t: ^testing.T) {
	// 102 leads out but nothing leads in.
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)), room(102, exit("WEST", 100))))
	diagnostics := run_one(t, text)
	expect_one(t, diagnostics, .Orphan_Room, .Warning, line = line_of(text, "#102"), vnum = 102)
	expect_none(t, diagnostics, .Dead_End_Room)
}

@(test)
test_isolated_room_is_both_orphan_and_dead_end :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)), room(102)))
	diagnostics := run_one(t, text)
	expect_one(t, diagnostics, .Orphan_Room, .Warning, vnum = 102)
	expect_one(t, diagnostics, .Dead_End_Room, .Warning, vnum = 102)
}

@(test)
test_exit_to_self_is_not_a_way_in_or_out :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)), room(102, exit("UP", 102))))
	diagnostics := run_one(t, text)
	expect_one(t, diagnostics, .Orphan_Room, .Warning, vnum = 102)
	expect_one(t, diagnostics, .Dead_End_Room, .Warning, vnum = 102)
}

// --- Whole-world checks ---

// Area a (100-199) and area b (200-299) joined at 101 <-> 200.
@(private = "file")
joined_areas :: proc(b_rooms: string, b_type := "normal") -> [2]string {
	a := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, sections(exit("SOUTH", 100), exit("EAST", 200)))))
	b := test_area("b", 200, 299, b_rooms, b_type)
	return {a, b}
}

@(test)
test_connected_world_is_clean :: proc(t: ^testing.T) {
	texts := joined_areas(rooms(room(200, sections(exit("WEST", 101), exit("NORTH", 201))), room(201, exit("SOUTH", 200))))
	expect_clean(t, run_validation(t, texts[:], true))
}

@(test)
test_unreachable_rooms :: proc(t: ^testing.T) {
	// 202 <-> 203 are joined to each other but not to the entrance (200).
	texts := joined_areas(rooms(room(200, exit("WEST", 101)), room(202, exit("NORTH", 203)), room(203, exit("SOUTH", 202))))
	diagnostics := run_validation(t, texts[:], true)
	unreachable := of_check(diagnostics, .Unreachable_Room)
	if testing.expect_value(t, len(unreachable), 2) {
		testing.expect_value(t, unreachable[0].vnum, 202)
		testing.expect_value(t, unreachable[0].area, 1)
		testing.expect_value(t, unreachable[0].severity, Severity.Warning)
		testing.expect_value(t, unreachable[1].vnum, 203)
	}
	expect_none(t, diagnostics, .Orphan_Room)
}

@(test)
test_unreachable_is_not_reported_for_orphans :: proc(t: ^testing.T) {
	// 202 is an orphan; reporting it as unreachable too would be noise.
	texts := joined_areas(rooms(room(200, sections(exit("WEST", 101), exit("NORTH", 202))), room(202, exit("SOUTH", 200)), room(203, exit("SOUTH", 200))))
	diagnostics := run_validation(t, texts[:], true)
	expect_one(t, diagnostics, .Orphan_Room, .Warning, area = 1, vnum = 203)
	expect_none(t, diagnostics, .Unreachable_Room)
}

@(test)
test_reachability_needs_the_whole_world :: proc(t: ^testing.T) {
	texts := joined_areas(rooms(room(200, exit("WEST", 101)), room(202, exit("NORTH", 203)), room(203, exit("SOUTH", 202))))
	diagnostics := run_validation(t, texts[:], false)
	expect_none(t, diagnostics, .Unreachable_Room)
	expect_none(t, diagnostics, .Area_Without_Entrance)
}

@(test)
test_area_without_entrance :: proc(t: ^testing.T) {
	a := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))))
	b := test_area("b", 200, 299, rooms(room(200, exit("NORTH", 201)), room(201, exit("SOUTH", 200))))
	diagnostics := run_validation(t, {a, b}, true)
	entrance := of_check(diagnostics, .Area_Without_Entrance)
	if testing.expect_value(t, len(entrance), 2) {
		testing.expect_value(t, entrance[0].area, 0)
		testing.expect_value(t, entrance[0].line, 1)
		testing.expect_value(t, entrance[0].severity, Severity.Warning)
		testing.expect_value(t, entrance[1].area, 1)
	}
}

@(test)
test_unopened_areas_are_info :: proc(t: ^testing.T) {
	a := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))), "unopened")
	expect_one(t, run_validation(t, {a}, true), .Area_Without_Entrance, .Info)

	texts := joined_areas(rooms(room(200, exit("WEST", 101)), room(202, exit("NORTH", 203)), room(203, exit("SOUTH", 202))), "unopened")
	for d in of_check(run_validation(t, texts[:], true), .Unreachable_Room) {
		testing.expect_value(t, d.severity, Severity.Info)
	}
}

@(test)
test_entrance_through_a_portal :: proc(t: ^testing.T) {
	// Area b's only way in is a portal placed in area a.
	a := test_area(
		"a",
		100,
		199,
		sections(objects(object(150, "portal", "-1 0 0 200 0")), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 200))), resets("OBJ 150 TO 100")),
	)
	b := test_area("b", 200, 299, rooms(room(200, sections(exit("NORTH", 201), exit("WEST", 100))), room(201, exit("SOUTH", 200))))
	diagnostics := run_validation(t, {a, b}, true)
	expect_none(t, diagnostics, .Area_Without_Entrance)
	expect_none(t, diagnostics, .Unreachable_Room)
}
