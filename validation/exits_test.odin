/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:testing"

// Two rooms joined both ways: the baseline every exit test starts from.
@(private = "file")
linked_pair :: proc() -> string {
	return rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)))
}

@(test)
test_linked_rooms_are_clean :: proc(t: ^testing.T) {
	expect_clean(t, run_one(t, test_area("a", 100, 199, linked_pair())))
}

// --- Broken_Exit and the completeness rule ---

@(test)
test_broken_exit_inside_loaded_range_is_error :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 150)), room(101, exit("SOUTH", 100))))
	d, _ := expect_one(t, run_one(t, text), .Broken_Exit, .Error, line = body_line(6), vnum = 100)
	testing.expect_value(t, d.related_vnum, 150)
}

@(test)
test_broken_exit_outside_loaded_areas_is_info :: proc(t: ^testing.T) {
	// 5000 may belong to an area that isn't loaded.
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 5000)), room(101, exit("SOUTH", 100))))
	d, _ := expect_one(t, run_one(t, text), .Broken_Exit, .Info, vnum = 100)
	testing.expect(t, len(d.message) > 0)
}

@(test)
test_broken_exit_in_complete_world_is_error :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 5000)), room(101, exit("SOUTH", 100))))
	expect_one(t, run_validation(t, {text}, true), .Broken_Exit, .Error, vnum = 100)
}

@(test)
test_broken_exit_to_another_loaded_area_is_error :: proc(t: ^testing.T) {
	// 250 is inside area b's range, so it should exist.
	a := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 250)), room(101, exit("SOUTH", 100))))
	b := test_area("b", 200, 299, rooms(room(200, exit("NORTH", 201)), room(201, exit("SOUTH", 200))))
	expect_one(t, run_validation(t, {a, b}, false), .Broken_Exit, .Error, area = 0, vnum = 100)
}

@(test)
test_negative_exit_target_is_broken :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, sections(exit("NORTH", 101), exit("EAST", -1))), room(101, exit("SOUTH", 100))))
	expect_one(t, run_one(t, text), .Broken_Exit, .Error, vnum = 100)
}

@(test)
test_look_only_exits_are_not_reported :: proc(t: ^testing.T) {
	// Exits to vnum 0 only describe a direction.
	text := test_area("a", 100, 199, rooms(room(100, sections(exit("NORTH", 101), exit("WEST", 0), exit("UP", 0))), room(101, sections(exit("SOUTH", 100), exit("EAST", 0)))))
	expect_clean(t, run_one(t, text))
}

@(test)
test_exit_into_another_area_resolves :: proc(t: ^testing.T) {
	a := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 200)), room(101, exit("SOUTH", 100))))
	b := test_area("b", 200, 299, rooms(room(200, sections(exit("SOUTH", 100), exit("EAST", 201))), room(201, exit("WEST", 200))))
	diagnostics := run_validation(t, {a, b}, false)
	expect_none(t, diagnostics, .Broken_Exit)
	expect_none(t, diagnostics, .One_Way_Exit)
}

// --- Return paths ---

@(test)
test_mismatched_return :: proc(t: ^testing.T) {
	// 100 north -> 101, but 101 south -> 102.
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, sections(exit("SOUTH", 102), exit("EAST", 100))), room(102, exit("NORTH", 101))))
	d, _ := expect_one(t, run_one(t, text), .Mismatched_Return, .Warning, vnum = 100)
	testing.expect_value(t, d.related_vnum, 101)
}

@(test)
test_one_way_exit :: proc(t: ^testing.T) {
	// 101 -> 102 has no way back; 102 -> 100 closes the loop so no room is
	// an orphan or a dead end.
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, sections(exit("SOUTH", 100), exit("EAST", 102))), room(102, exit("DOWN", 100))))
	diagnostics := run_one(t, text)
	expect_one(t, of_check(diagnostics, .One_Way_Exit)[:1], .One_Way_Exit, .Info, vnum = 101)
	testing.expect_value(t, len(of_check(diagnostics, .One_Way_Exit)), 2) // 101->102 and 102->100
	expect_none(t, diagnostics, .Mismatched_Return)
}

@(test)
test_return_by_another_direction_is_not_one_way :: proc(t: ^testing.T) {
	// 100 north -> 101 and 101 east -> 100: geometry is odd, but there is a way back.
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, exit("EAST", 100))))
	diagnostics := run_one(t, text)
	expect_none(t, diagnostics, .One_Way_Exit)
	expect_none(t, diagnostics, .Mismatched_Return)
}

@(test)
test_look_only_reverse_exit_is_not_mismatched :: proc(t: ^testing.T) {
	// 101's south exit only describes the view; it isn't a wrong way back.
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, sections(exit("SOUTH", 0), exit("EAST", 100)))))
	expect_none(t, run_one(t, text), .Mismatched_Return)
}

@(test)
test_exit_into_same_room_is_ignored :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, sections(exit("NORTH", 101), exit("UP", 100))), room(101, exit("SOUTH", 100))))
	expect_clean(t, run_one(t, text))
}

@(test)
test_replaced_exit :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, sections(exit("NORTH", 102), exit("NORTH", 101))), room(101, exit("SOUTH", 100))))
	d, _ := expect_one(t, run_one(t, text), .Replaced_Exit, .Warning, line = body_line(6), vnum = 100)
	testing.expect_value(t, d.related_vnum, 102)
}

// --- Doors and keys ---

@(private = "file")
door_world :: proc(flags: string, key: int, extra_resets := "", extra_objects := "") -> string {
	room_records := rooms(room(100, exit("NORTH", 101, flags, key, "door")), room(101, exit("SOUTH", 100)))
	objs := objects(object(150, "key"), extra_objects)
	reset_section := resets(extra_resets) if extra_resets != "" else ""
	return test_area("a", 100, 199, sections(objs, room_records, reset_section))
}

@(test)
test_locked_door_with_negative_key :: proc(t: ^testing.T) {
	d, _ := expect_one(t, run_one(t, door_world("ABC", -1)), .Locked_Door_No_Key, .Warning, vnum = 100)
	testing.expect_value(t, d.related_vnum, -1)
}

@(test)
test_door_locked_by_reset_with_no_key :: proc(t: ^testing.T) {
	expect_one(t, run_one(t, door_world("0", 0, "DOOR 100 NORTH LOCKED")), .Locked_Door_No_Key, .Warning, vnum = 100)
}

@(test)
test_unlocked_door_without_key_is_fine :: proc(t: ^testing.T) {
	expect_clean(t, run_one(t, door_world("AB", 0, "DOOR 100 NORTH CLOSED")))
}

@(test)
test_missing_key :: proc(t: ^testing.T) {
	d, _ := expect_one(t, run_one(t, door_world("ABC", 160)), .Missing_Key, .Error, vnum = 100)
	testing.expect_value(t, d.related_vnum, 160)
}

@(test)
test_key_never_placed :: proc(t: ^testing.T) {
	d, _ := expect_one(t, run_one(t, door_world("ABC", 150)), .Key_Never_Placed, .Warning, vnum = 100)
	testing.expect_value(t, d.related_vnum, 150)
}

@(test)
test_key_placed_by_any_reset :: proc(t: ^testing.T) {
	expect_clean(t, run_one(t, door_world("ABC", 150, "OBJ 150 TO 101")))
	expect_clean(t, run_one(t, door_world("ABC", 150, "OBJ 151 TO 101\nPUT 150 IN 151 COUNT 1", object(151, "container", "10 0 0 5 100"))))
}

@(test)
test_key_given_to_mob :: proc(t: ^testing.T) {
	room_records := rooms(room(100, exit("NORTH", 101, "ABC", 150, "door")), room(101, exit("SOUTH", 100)))
	text := test_area("a", 100, 199, sections(mobs(mob(120)), objects(object(150, "key")), room_records, resets("MOB 120 TO 101 GLIMIT 1 LLIMIT 1", "GIVE 150")))
	expect_clean(t, run_one(t, text))
}

@(test)
test_door_reset_without_exit :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, sections(linked_pair(), resets("DOOR 100 EAST CLOSED")))
	expect_one(t, run_one(t, text), .Door_Reset_No_Exit, .Warning, vnum = 100)
}
