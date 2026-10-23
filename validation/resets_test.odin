/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:testing"

// Rooms 100 and 101 joined both ways, mob 120, objects 150 (trash) and 151
// (container), plus the given resets.
@(private = "file")
reset_world :: proc(reset_lines: ..string) -> string {
	return test_area(
		"a",
		100,
		199,
		sections(
			mobs(mob(120), mob(121)),
			objects(object(150), object(151, "container", "10 0 0 5 100"), object(152, "portal", "-1 0 0 101 0")),
			rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))),
			resets(..reset_lines),
		),
	)
}

@(test)
test_valid_resets_are_clean :: proc(t: ^testing.T) {
	text := reset_world(
		"MOB 120 TO 100 GLIMIT 1 LLIMIT 1",
		"EQUIP 150 BODY",
		"GIVE 150",
		"OBJ 151 TO 101",
		"PUT 150 IN 151 COUNT 2",
		"DOOR 100 NORTH CLOSED",
		"RANDOM 101 2",
	)
	expect_clean(t, run_one(t, text))
}

@(test)
test_reset_missing_mob :: proc(t: ^testing.T) {
	d, _ := expect_one(t, run_one(t, reset_world("MOB 130 TO 100 GLIMIT 1 LLIMIT 1")), .Reset_Missing_Mob, .Error, vnum = 130)
	testing.expect(t, d.line > HEADER_LINES)
	// Outside every loaded area's range, and the world isn't complete.
	expect_one(t, run_one(t, reset_world("MOB 9000 TO 100 GLIMIT 1 LLIMIT 1")), .Reset_Missing_Mob, .Info, vnum = 9000)
}

@(test)
test_reset_missing_object :: proc(t: ^testing.T) {
	expect_one(t, run_one(t, reset_world("OBJ 160 TO 100")), .Reset_Missing_Object, .Error, vnum = 160)
	diagnostics := run_one(t, reset_world("OBJ 151 TO 100", "PUT 150 IN 161 COUNT 1"))
	expect_one(t, diagnostics, .Reset_Missing_Object, .Error, vnum = 161)
}

@(test)
test_reset_missing_room :: proc(t: ^testing.T) {
	expect_one(t, run_one(t, reset_world("OBJ 150 TO 170")), .Reset_Missing_Room, .Error, vnum = 170)
	expect_one(t, run_one(t, reset_world("DOOR 170 NORTH OPEN")), .Reset_Missing_Room, .Error, vnum = 170)
	expect_one(t, run_one(t, reset_world("RANDOM 170 4")), .Reset_Missing_Room, .Error, vnum = 170)
}

@(test)
test_reset_without_mob :: proc(t: ^testing.T) {
	// GIVE before any MOB reset.
	expect_one(t, run_one(t, reset_world("GIVE 150")), .Reset_Without_Mob, .Warning, vnum = 150)
	// EQUIP after an OBJ into a room that never had a mob.
	expect_one(t, run_one(t, reset_world("MOB 120 TO 100 GLIMIT 1 LLIMIT 1", "OBJ 151 TO 101", "EQUIP 150 BODY")), .Reset_Without_Mob, .Warning, vnum = 150)
}

@(test)
test_reset_after_object_into_another_room :: proc(t: ^testing.T) {
	// The OBJ moves the context to 101, whose last mob is 121, not 120.
	text := reset_world("MOB 121 TO 101 GLIMIT 1 LLIMIT 1", "MOB 120 TO 100 GLIMIT 1 LLIMIT 1", "OBJ 151 TO 101", "EQUIP 150 BODY")
	d, _ := expect_one(t, run_one(t, text), .Reset_After_Object, .Warning, vnum = 150)
	testing.expect_value(t, d.related_vnum, 101)
}

@(test)
test_reset_after_object_in_same_room_is_fine :: proc(t: ^testing.T) {
	// minotaur.are does this: the GIVE still reaches the mob in 100.
	expect_clean(t, run_one(t, reset_world("MOB 120 TO 100 GLIMIT 1 LLIMIT 1", "OBJ 151 TO 100", "GIVE 150")))
}

@(test)
test_put_into_non_container :: proc(t: ^testing.T) {
	d, _ := expect_one(t, run_one(t, reset_world("OBJ 150 TO 100", "PUT 151 IN 150 COUNT 1")), .Put_Into_Non_Container, .Warning, vnum = 151)
	testing.expect_value(t, d.related_vnum, 150)
}

@(test)
test_put_uses_item_type_prefix_lookup :: proc(t: ^testing.T) {
	// "cont" is a container; "c" is clothing (it comes first in item_table).
	cont := test_area("a", 100, 199, sections(objects(object(150), object(151, "cont", "10 0 0 5 100")), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))), resets("OBJ 151 TO 100", "PUT 150 IN 151 COUNT 1")))
	expect_clean(t, run_one(t, cont))
	clothing := test_area("a", 100, 199, sections(objects(object(150), object(151, "c")), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))), resets("OBJ 151 TO 100", "PUT 150 IN 151 COUNT 1")))
	expect_one(t, run_one(t, clothing), .Put_Into_Non_Container, .Warning)
}

// --- Portals ---

@(test)
test_portal_counts_as_a_way_in :: proc(t: ^testing.T) {
	// Room 102 is only reachable through the portal placed in 100.
	text := test_area(
		"a",
		100,
		199,
		sections(objects(object(152, "portal", "-1 0 0 102 0")), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)), room(102, exit("WEST", 100))), resets("OBJ 152 TO 100")),
	)
	diagnostics := run_one(t, text)
	expect_none(t, diagnostics, .Orphan_Room)
	expect_none(t, diagnostics, .Portal_Missing_Target)
}

@(test)
test_portal_missing_target :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, sections(objects(object(152, "portal", "-1 0 0 190 0")), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))), resets("OBJ 152 TO 100")))
	d, _ := expect_one(t, run_one(t, text), .Portal_Missing_Target, .Error, vnum = 152)
	testing.expect_value(t, d.related_vnum, 190)
}

@(test)
test_random_portal_is_not_checked :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, sections(objects(object(152, "portal", "-1 0 0 -1 0")), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))), resets("OBJ 152 TO 100")))
	expect_clean(t, run_one(t, text))
}

// --- Programs and specs ---

@(private = "file")
program_world :: proc(section: string) -> string {
	return test_area("a", 100, 199, sections(mobs(mob(120)), objects(object(150)), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))), section))
}

@(test)
test_programs_with_existing_targets_are_clean :: proc(t: ^testing.T) {
	text := program_world("#IMPROGS\nM 120 pulse_prog p1\nI 150 wear_prog p2\nR 100 entry_prog p3\nA tick_prog p4\nEND\n#SPECS\nM 120 spec_guard\nI 150 spec_ring\nEND\n")
	expect_clean(t, run_one(t, text))
}

@(test)
test_program_missing_target :: proc(t: ^testing.T) {
	text := program_world("#IMPROGS\nM 130 pulse_prog p1\nEND\n")
	expect_one(t, run_one(t, text), .Program_Missing_Target, .Error, line = line_of(text, "M 130"), vnum = 130)
	expect_one(t, run_one(t, program_world("#IMPROGS\nI 160 wear_prog p1\nEND\n")), .Program_Missing_Target, .Error, vnum = 160)
	expect_one(t, run_one(t, program_world("#IMPROGS\nR 170 entry_prog p1\nEND\n")), .Program_Missing_Target, .Error, vnum = 170)
	expect_one(t, run_one(t, program_world("#SPECS\nM 130 spec_guard\nEND\n")), .Program_Missing_Target, .Error, vnum = 130)
}

@(test)
test_ignored_program_line :: proc(t: ^testing.T) {
	d, _ := expect_one(t, run_one(t, program_world("#IMPROGS\nS 120 spec_guard\nEND\n")), .Ignored_Program_Line, .Info, vnum = 120)
	testing.expect(t, len(d.message) > 0)
}

// --- Records and headers ---

@(test)
test_duplicate_vnums_across_areas :: proc(t: ^testing.T) {
	a := test_area("a", 100, 199, sections(mobs(mob(120)), objects(object(150)), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)))))
	b := test_area("b", 100, 199, sections(mobs(mob(120)), objects(object(150)), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)))))
	diagnostics := run_validation(t, {a, b}, false)
	duplicates := of_check(diagnostics, .Duplicate_Vnum)
	testing.expect_value(t, len(duplicates), 4) // rooms 100 and 101, mob 120, object 150
	for d in duplicates {
		testing.expect_value(t, d.area, 1)
		testing.expect_value(t, d.severity, Severity.Error)
	}
}

@(test)
test_duplicate_vnum_within_one_area :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)), room(101, exit("SOUTH", 100))))
	expect_one(t, run_one(t, text), .Duplicate_Vnum, .Error, vnum = 101)
}

@(test)
test_vnum_out_of_range :: proc(t: ^testing.T) {
	text := test_area("a", 100, 199, sections(mobs(mob(220)), rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100)))))
	expect_one(t, run_one(t, text), .Vnum_Out_Of_Range, .Warning, line = line_of(text, "#220"), vnum = 220)
}

@(test)
test_bad_area_header :: proc(t: ^testing.T) {
	expect_one(t, run_one(t, test_area("a", 199, 100, rooms(room(100, exit("NORTH", 101)), room(101, exit("SOUTH", 100))))), .Bad_Area_Header, .Warning, line = 1)
}
