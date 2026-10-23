/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:testing"

import "../models"

// --- File structure and section dispatch ---

@(test)
test_header_fields :: proc(t: ^testing.T) {
	loaded := must_parse(t, with_header(""))
	defer unload_area(loaded)
	if loaded == nil do return
	h := loaded.area.header
	testing.expect_value(t, h.file_name, "test.are")
	testing.expect_value(t, h.name, "Test Area")
	testing.expect_value(t, h.credits, "Tester")
	testing.expect_value(t, h.low_level, 1)
	testing.expect_value(t, h.high_level, 50)
	testing.expect_value(t, h.min_vnum, 100)
	testing.expect_value(t, h.max_vnum, 199)
	testing.expect_value(t, h.area_type, "normal")
	testing.expect_value(t, h.climate, "temperate")
	testing.expect_value(t, h.flags, "0")
	testing.expect_value(t, h.security, 1)
	testing.expect_value(t, h.builders, "None")
	testing.expect_value(t, h.line, 1)
}

@(test)
test_end_marker_only_is_an_empty_area :: proc(t: ^testing.T) {
	loaded := must_parse(t, "#$\n")
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, len(loaded.area.rooms), 0)
}

@(test)
test_end_marker_without_trailing_newline :: proc(t: ^testing.T) {
	loaded := must_parse(t, "#$")
	unload_area(loaded)
}

@(test)
test_missing_end_marker :: proc(t: ^testing.T) {
	expect_parse_failure(t, "", .Missing_End_Marker)
	expect_parse_failure(t, TEST_HEADER, .Missing_End_Marker)
}

@(test)
test_section_must_start_with_hash :: proc(t: ^testing.T) {
	expect_parse_failure(t, "AREA\n", .Expected_Hash, 1)
}

@(test)
test_section_before_area_header :: proc(t: ^testing.T) {
	failure := expect_parse_failure(t, "#ROOMS\n#0\n#$\n", .Missing_Area_Header, 1)
	testing.expect_value(t, failure.section, "ROOMS")
}

@(test)
test_unknown_section :: proc(t: ^testing.T) {
	failure := expect_parse_failure(t, with_header("#BOGUS\n"), .Unknown_Section, body_line(1))
	testing.expect_value(t, failure_token(&failure), "BOGUS")
}

@(test)
test_legacy_sections_are_unsupported :: proc(t: ^testing.T) {
	for name in ([]string{"#MOBILES", "#OBJECTS", "#SHOPS", "#SPECIALS", "#AREADATA", "#OLDRESETS"}) {
		expect_parse_failure(t, with_header(name), .Unsupported_Section, body_line(1))
	}
}

@(test)
test_section_names_ignore_case :: proc(t: ^testing.T) {
	loaded := must_parse(t, with_header("#rooms\n#0\n#Resets\nS\n"))
	unload_area(loaded)
}

// --- #ROOMS ---

@(test)
test_room_basic_fields :: proc(t: ^testing.T) {
	text := with_header(`#ROOMS
#101
The Square~
A busy square.
People everywhere.
~
city
ROOM LAW
ROOM INDOORS
D NORTH 102 0 -1
~
You see a road.
~
D up 150 AB 120
trapdoor~
~
S
#0
`)
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, len(loaded.area.rooms), 1)
	room := loaded.area.rooms[0]
	testing.expect_value(t, room.vnum, 101)
	testing.expect_value(t, room.line, body_line(2))
	testing.expect_value(t, room.name, "The Square")
	testing.expect_value(t, room.description, "A busy square.\nPeople everywhere.\n")
	testing.expect_value(t, room.sector, "city")
	testing.expect_value(t, len(room.flags), 2)
	testing.expect_value(t, room.flags[0], "LAW")
	testing.expect_value(t, room.flags[1], "INDOORS")
	testing.expect_value(t, room.heal_rate, 100)
	testing.expect_value(t, room.mana_rate, 100)

	north, has_north := room.exits[.North].?
	testing.expect(t, has_north)
	testing.expect_value(t, north.target, 102)
	testing.expect_value(t, north.flags, "0")
	testing.expect_value(t, north.key, -1)
	testing.expect_value(t, north.keyword, "")
	testing.expect_value(t, north.description, "You see a road.\n")
	testing.expect_value(t, north.line, body_line(10))

	up, has_up := room.exits[.Up].?
	testing.expect(t, has_up)
	testing.expect_value(t, up.target, 150)
	testing.expect_value(t, up.flags, "AB")
	testing.expect_value(t, up.key, 120)
	testing.expect_value(t, up.keyword, "trapdoor")

	_, has_south := room.exits[.South].?
	testing.expect(t, !has_south)
}

@(test)
test_room_optional_fields :: proc(t: ^testing.T) {
	text := with_header(`#ROOMS
#101
Temple~
~
inside
H 150
M 200
G 3
C CABAL HORDE
O OWNER Someone~
A ALTDESC 4 Ruined Temple~
Rubble.
~
T TRAP dart 5 3 10 You hear a click.~
Darts fly!~
E altar statue~
A stone altar.
~
E sign~
It reads "hi".~
S
#0
`)
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	room := loaded.area.rooms[0]
	testing.expect_value(t, room.heal_rate, 150)
	testing.expect_value(t, room.mana_rate, 200)
	testing.expect_value(t, room.guild, 3)
	testing.expect_value(t, room.cabal, "HORDE")
	testing.expect_value(t, room.owner, "Someone")

	alt, has_alt := room.alt_description.?
	testing.expect(t, has_alt)
	testing.expect_value(t, alt.condition, 4)
	testing.expect_value(t, alt.name, "Ruined Temple")
	testing.expect_value(t, alt.description, "Rubble.\n")

	trap, has_trap := room.trap.?
	testing.expect(t, has_trap)
	testing.expect_value(t, trap.trap_type, "dart")
	testing.expect_value(t, trap.quality, 5)
	testing.expect_value(t, trap.complexity, 3)
	testing.expect_value(t, trap.timer, 10)
	testing.expect_value(t, trap.trigger_echo, "You hear a click.")
	testing.expect_value(t, trap.execute_echo, "Darts fly!")

	testing.expect_value(t, len(room.extras), 2)
	testing.expect_value(t, room.extras[0].keyword, "altar statue")
	testing.expect_value(t, room.extras[1].description, `It reads "hi".`)
}

@(test)
test_room_field_letters_ignore_case :: proc(t: ^testing.T) {
	loaded := must_parse(t, with_header("#ROOMS\n#101\nA~\n~\ncity\nroom LAW\nd south 100 0 0\n~\n~\ns\n#0\n"))
	defer unload_area(loaded)
	if loaded == nil do return
	room := loaded.area.rooms[0]
	testing.expect_value(t, room.flags[0], "LAW")
	_, has_south := room.exits[.South].?
	testing.expect(t, has_south)
}

@(test)
test_room_can_end_without_s :: proc(t: ^testing.T) {
	// Riftshadow ends a room at any letter it doesn't recognise, so a room
	// with no `S` ends at the next `#`.
	text := with_header(`#ROOMS
#101
First~
~
city
D EAST 102 0 -1
~
~
#102
Second~
~
city
#0
`)
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, len(loaded.area.rooms), 2)
	testing.expect_value(t, loaded.area.rooms[1].vnum, 102)
	testing.expect_value(t, loaded.area.rooms[1].line, body_line(9))
}

@(test)
test_room_direction_prefixes :: proc(t: ^testing.T) {
	text := with_header("#ROOMS\n#101\nA~\n~\ncity\nD n 1 0 0\n~\n~\nD W 2 0 0\n~\n~\nD Dow 3 0 0\n~\n~\nS\n#0\n")
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	room := loaded.area.rooms[0]
	testing.expect_value(t, room.exits[.North].?.target, 1)
	testing.expect_value(t, room.exits[.West].?.target, 2)
	testing.expect_value(t, room.exits[.Down].?.target, 3)
}

@(test)
test_room_duplicate_exit_keeps_last :: proc(t: ^testing.T) {
	text := with_header("#ROOMS\n#101\nA~\n~\ncity\nD NORTH 1 0 0\n~\n~\nD NORTH 2 0 0\n~\n~\nS\n#0\n")
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	room := loaded.area.rooms[0]
	testing.expect_value(t, room.exits[.North].?.target, 2)
	testing.expect_value(t, len(room.replaced_exits), 1)
	testing.expect_value(t, room.replaced_exits[0].target, 1)
}

@(test)
test_room_bad_direction :: proc(t: ^testing.T) {
	failure := expect_parse_failure(t, with_header("#ROOMS\n#101\nA~\n~\ncity\nD 0 102 0 0\n~\n~\nS\n#0\n"), .Bad_Direction, body_line(6))
	testing.expect_value(t, failure.section, "ROOMS")
	testing.expect_value(t, failure.vnum, 101)
	testing.expect_value(t, failure_token(&failure), "0")
}

@(test)
test_room_vnum_range :: proc(t: ^testing.T) {
	expect_parse_failure(t, with_header("#ROOMS\n#40000\nA~\n~\ncity\nS\n#0\n"), .Vnum_Out_Of_Range, body_line(2))
	expect_parse_failure(t, with_header("#ROOMS\n#-5\nA~\n~\ncity\nS\n#0\n"), .Vnum_Out_Of_Range, body_line(2))
	loaded := must_parse(t, with_header("#ROOMS\n#32767\nA~\n~\ncity\nS\n#0\n"))
	unload_area(loaded)
}

@(test)
test_room_unrecognised_text_ends_section_badly :: proc(t: ^testing.T) {
	// "X" ends the room; the loader then expects '#' for the next vnum.
	failure := expect_parse_failure(t, with_header("#ROOMS\n#101\nA~\n~\ncity\nX\n#0\n"), .Expected_Hash, body_line(6))
	// The error names the record that went wrong.
	testing.expect_value(t, failure.vnum, 101)
}

@(test)
test_room_missing_terminator :: proc(t: ^testing.T) {
	expect_parse_failure(t, TEST_HEADER + "#ROOMS\n#101\nA~\n~\ncity\nS\n", .Unexpected_EOF)
}

@(test)
test_room_unterminated_description :: proc(t: ^testing.T) {
	expect_parse_failure(t, with_header("#ROOMS\n#101\nName~\nThis description\nnever ends\n"), .Unterminated_String, body_line(4))
}

// --- #RESETS ---

@(test)
test_resets_all_commands :: proc(t: ^testing.T) {
	text := with_header(`#RESETS
* A comment line
MOB 3073 TO 3001 GLIMIT 2 LLIMIT 1   * trailing comment
EQUIP 3380 BODY
GIVE 3381
FOLLOW 3000 1
OBJ 3010 TO 3005
PUT 3011 IN 3010 COUNT 3
DOOR 3001 NORTH CLOSED
DOOR 3002 s locked
RANDOM 3003 4
S
`)
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	resets := loaded.area.resets
	if !testing.expect_value(t, len(resets), 9) do return

	testing.expect_value(t, resets[0].command, models.Reset_Command.Mob)
	testing.expect_value(t, resets[0].vnum, 3073)
	testing.expect_value(t, resets[0].room, 3001)
	testing.expect_value(t, resets[0].global_limit, 2)
	testing.expect_value(t, resets[0].local_limit, 1)
	testing.expect_value(t, resets[0].line, body_line(3))

	testing.expect_value(t, resets[1].command, models.Reset_Command.Equip)
	testing.expect_value(t, resets[1].vnum, 3380)
	testing.expect_value(t, resets[1].wear_location, "BODY")
	testing.expect_value(t, resets[1].context_room, 3001)

	testing.expect_value(t, resets[2].command, models.Reset_Command.Give)
	testing.expect_value(t, resets[2].vnum, 3381)
	testing.expect_value(t, resets[2].context_room, 3001)

	testing.expect_value(t, resets[3].command, models.Reset_Command.Follow)
	testing.expect_value(t, resets[3].vnum, 3000)
	testing.expect_value(t, resets[3].leader_index, 1)

	testing.expect_value(t, resets[4].command, models.Reset_Command.Object)
	testing.expect_value(t, resets[4].room, 3005)

	testing.expect_value(t, resets[5].command, models.Reset_Command.Put)
	testing.expect_value(t, resets[5].vnum, 3011)
	testing.expect_value(t, resets[5].container, 3010)
	testing.expect_value(t, resets[5].count, 3)
	testing.expect_value(t, resets[5].context_room, 3005)

	testing.expect_value(t, resets[6].command, models.Reset_Command.Door)
	testing.expect_value(t, resets[6].room, 3001)
	testing.expect_value(t, resets[6].direction, models.Direction.North)
	testing.expect_value(t, resets[6].door_state, models.Door_State.Closed)

	testing.expect_value(t, resets[7].direction, models.Direction.South)
	testing.expect_value(t, resets[7].door_state, models.Door_State.Locked)

	testing.expect_value(t, resets[8].command, models.Reset_Command.Randomize)
	testing.expect_value(t, resets[8].room, 3003)
	testing.expect_value(t, resets[8].exit_count, 4)
}

@(test)
test_resets_context_before_any_room :: proc(t: ^testing.T) {
	loaded := must_parse(t, with_header("#RESETS\nGIVE 3381\nS\n"))
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, loaded.area.resets[0].context_room, 0)
}

@(test)
test_resets_errors :: proc(t: ^testing.T) {
	expect_parse_failure(t, with_header("#RESETS\nZAP 1 2\nS\n"), .Bad_Reset, body_line(2))
	expect_parse_failure(t, with_header("#RESETS\nDOOR 3001 NORTH AJAR\nS\n"), .Bad_Reset, body_line(2))
	expect_parse_failure(t, with_header("#RESETS\nDOOR 3001 SIDEWAYS OPEN\nS\n"), .Bad_Direction, body_line(2))
	expect_parse_failure(t, with_header("#RESETS\nRANDOM 3003 7\nS\n"), .Bad_Reset, body_line(2))
	expect_parse_failure(t, with_header("#RESETS\nMOB 3073 TO x GLIMIT 1 LLIMIT 1\nS\n"), .Bad_Number, body_line(2))
	expect_parse_failure(t, TEST_HEADER + "#RESETS\nMOB 1 TO 2 GLIMIT 1 LLIMIT 1\n", .Unexpected_EOF)
}

// --- #IMPROGS and #SPECS ---

@(test)
test_improgs :: proc(t: ^testing.T) {
	text := with_header(`#IMPROGS
* comment
M 3001 pulse_prog pulse_prog_shopkeeper
I 3010 wear_prog wear_prog_ring
R 3005 entry_prog entry_prog_gate
A tick_prog tick_prog_weather
S 3100 spec_cast_cleric
END
`)
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	programs := loaded.area.programs
	if !testing.expect_value(t, len(programs), 5) do return
	testing.expect_value(t, programs[0].target, models.Program_Target.Mob)
	testing.expect_value(t, programs[0].vnum, 3001)
	testing.expect_value(t, programs[0].program_type, "pulse_prog")
	testing.expect_value(t, programs[0].name, "pulse_prog_shopkeeper")
	testing.expect_value(t, programs[1].target, models.Program_Target.Object)
	testing.expect_value(t, programs[2].target, models.Program_Target.Room)
	testing.expect_value(t, programs[3].target, models.Program_Target.Area)
	testing.expect_value(t, programs[3].vnum, 0)
	testing.expect_value(t, programs[3].program_type, "tick_prog")
	testing.expect_value(t, programs[4].target, models.Program_Target.Ignored_Spec)
	testing.expect_value(t, programs[4].vnum, 3100)
	testing.expect_value(t, programs[4].name, "spec_cast_cleric")
	testing.expect_value(t, programs[4].line, body_line(7))
}

@(test)
test_improgs_ignored_line_may_be_malformed :: proc(t: ^testing.T) {
	// The game skips S lines without reading them, so junk is accepted.
	loaded := must_parse(t, with_header("#IMPROGS\nS whatever\nEND\n"))
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, loaded.area.programs[0].vnum, 0)
}

@(test)
test_improgs_bad_line :: proc(t: ^testing.T) {
	expect_parse_failure(t, with_header("#IMPROGS\nX 1 a b\nEND\n"), .Bad_Program_Line, body_line(2))
	expect_parse_failure(t, TEST_HEADER + "#IMPROGS\nM 1 a b\n", .Unexpected_EOF)
}

@(test)
test_specs :: proc(t: ^testing.T) {
	loaded := must_parse(t, with_header("#SPECS\n* comment\nM 3060 spec_guard\nI 3010 spec_ring\nEND\n"))
	defer unload_area(loaded)
	if loaded == nil do return
	specs := loaded.area.specs
	if !testing.expect_value(t, len(specs), 2) do return
	testing.expect_value(t, specs[0].target, models.Program_Target.Mob)
	testing.expect_value(t, specs[0].vnum, 3060)
	testing.expect_value(t, specs[0].name, "spec_guard")
	testing.expect_value(t, specs[1].target, models.Program_Target.Object)
}

@(test)
test_specs_bad_line :: proc(t: ^testing.T) {
	expect_parse_failure(t, with_header("#SPECS\nR 3005 spec_x\nEND\n"), .Bad_Program_Line, body_line(2))
}

// --- #SOCIALS ---

@(test)
test_socials_are_skipped :: proc(t: ^testing.T) {
	text := `#SOCIALS

handraise 0 0
You raise your hand.
$n's hand shoots into the air.
#

#0
#$
`
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, len(loaded.area.skipped_sections), 1)
	testing.expect_value(t, loaded.area.skipped_sections[0], "SOCIALS")
}

@(test)
test_socials_without_end :: proc(t: ^testing.T) {
	expect_parse_failure(t, "#SOCIALS\nwave 0 0\nYou wave.\n", .Unexpected_EOF, 1)
}
