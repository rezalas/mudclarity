/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "base:runtime"
import "core:os"
import "core:strings"

import "../models"

/*
 Parser for Riftshadow .are files. Each section procedure mirrors the loader
 of the same name in riftshadow/code (bootup.c, db.c, db2.c), reading fields
 in the same order. The first structural error stops the parse, as it stops
 the game's boot.

 Memory: everything is allocated with the `allocator` passed in, and strings
 may point into `data`. Use an arena (see Loaded_Area) and keep `data` alive
 for as long as the Area is used.
*/

// Files larger than this are rejected before reading (largest real file is ~0.5 MB).
MAX_AREA_FILE_SIZE :: 10 * 1024 * 1024

@(private)
Parser :: struct {
	r:          Reader,
	allocator:  runtime.Allocator,
	has_header: bool,
	mobiles:    [dynamic]models.Mobile,
	objects:    [dynamic]models.Object,
	rooms:      [dynamic]models.Room,
	resets:     [dynamic]models.Reset,
	programs:   [dynamic]models.Program_Binding,
	specs:      [dynamic]models.Spec_Binding,
	skipped:    [dynamic]string,
}

// Read and parse the area file at `file_path`.
// Returns the area and the file contents it references; both are allocated
// with `allocator`. Files over MAX_AREA_FILE_SIZE are rejected.
parse_area_file :: proc(
	file_path: string,
	allocator := context.allocator,
) -> (
	area: models.Area,
	data: []u8,
	err: Parse_Error,
) {
	data = read_file_capped(file_path, MAX_AREA_FILE_SIZE, allocator) or_return
	area = parse_area(data, file_path, allocator) or_return
	return area, data, nil
}

// Read a whole file, refusing files larger than `max_size` bytes.
read_file_capped :: proc(file_path: string, max_size: i64, allocator := context.allocator) -> (data: []u8, err: Parse_Error) {
	f, open_err := os.open(file_path)
	if open_err != nil {
		return nil, make_failure(.Io_Error, 0, 0, "", 0, "could not open file")
	}
	defer os.close(f)
	size, size_err := os.file_size(f)
	if size_err != nil {
		return nil, make_failure(.Io_Error, 0, 0, "", 0, "could not read file size")
	}
	if size > max_size {
		return nil, make_failure(.File_Too_Large, 0, 0, "", 0, "file is larger than the size limit")
	}
	bytes, read_err := os.read_entire_file_from_file(f, allocator)
	if read_err != nil {
		return nil, make_failure(.Io_Error, 0, 0, "", 0, "could not read file")
	}
	if i64(len(bytes)) > max_size {
		return nil, make_failure(.File_Too_Large, 0, 0, "", 0, "file is larger than the size limit")
	}
	return bytes, nil
}

// Parse an area file already in memory. `source_name` is used for display.
// Mirrors the section loop in boot_db (riftshadow/code/bootup.c).
parse_area :: proc(data: []u8, source_name: string, allocator := context.allocator) -> (area: models.Area, err: Parse_Error) {
	p := Parser {
		r         = reader_make(data),
		allocator = allocator,
		mobiles   = make([dynamic]models.Mobile, allocator),
		objects   = make([dynamic]models.Object, allocator),
		rooms     = make([dynamic]models.Room, allocator),
		resets    = make([dynamic]models.Reset, allocator),
		programs  = make([dynamic]models.Program_Binding, allocator),
		specs     = make([dynamic]models.Spec_Binding, allocator),
		skipped   = make([dynamic]string, allocator),
	}
	area.source_name = source_name

	for {
		p.r.section = ""
		p.r.vnum = 0
		skip_whitespace(&p.r)
		if at_eof(&p.r) {
			return area, reader_fail(&p.r, .Missing_End_Marker, "file ends without #$")
		}
		letter_line, letter_column := p.r.line, p.r.column
		letter := read_letter(&p.r) or_return
		if letter != '#' {
			return area, reader_fail_at(&p.r, letter_line, letter_column, .Expected_Hash, "expected # to start a section", string([]u8{letter}))
		}
		word := read_word(&p.r) or_return
		if len(word) > 0 && word[0] == '$' {
			break
		}
		section := section_name(word)
		p.r.section = section
		switch section {
		case "AREA":
			area.header = parse_area_header(&p) or_return
			p.has_header = true
		case "MOBS":
			require_header(&p) or_return
			parse_mobs_section(&p) or_return
		case "OBJS":
			require_header(&p) or_return
			parse_objs_section(&p) or_return
		case "ROOMS":
			require_header(&p) or_return
			parse_rooms_section(&p) or_return
		case "RESETS":
			require_header(&p) or_return
			parse_resets_section(&p) or_return
		case "IMPROGS":
			parse_improgs_section(&p) or_return
		case "SPECS":
			parse_specs_section(&p) or_return
		case "SOCIALS":
			skip_socials_section(&p) or_return
			append(&p.skipped, "SOCIALS")
		case "AREADATA", "OLDRESETS", "MOBILES", "OBJECTS", "SHOPS", "SPECIALS", "HELPS":
			return area, reader_fail_at(&p.r, letter_line, letter_column, .Unsupported_Section, "section is not in Riftshadow's format (legacy ROM/OLC area file?)", word)
		case:
			return area, reader_fail_at(&p.r, letter_line, letter_column, .Unknown_Section, "unknown section name", word)
		}
	}

	area.mobiles = p.mobiles[:]
	area.objects = p.objects[:]
	area.rooms = p.rooms[:]
	area.resets = p.resets[:]
	area.programs = p.programs[:]
	area.specs = p.specs[:]
	area.skipped_sections = p.skipped[:]
	return area, nil
}

// Known section names, uppercased. Section names are matched case-insensitively
// (str_cmp in the game); returns "" for anything else.
@(private)
KNOWN_SECTIONS := [?]string{"AREA", "MOBS", "OBJS", "ROOMS", "RESETS", "IMPROGS", "SPECS", "SOCIALS", "AREADATA", "OLDRESETS", "MOBILES", "OBJECTS", "SHOPS", "SPECIALS", "HELPS"}

@(private)
section_name :: proc(word: string) -> string {
	for s in KNOWN_SECTIONS {
		if strings.equal_fold(s, word) {
			return s
		}
	}
	return ""
}

@(private)
require_header :: proc(p: ^Parser) -> Parse_Error {
	if !p.has_header {
		return reader_fail(&p.r, .Missing_Area_Header, "section appears before #AREA")
	}
	return nil
}

@(private)
read_str :: proc(p: ^Parser) -> (string, Parse_Error) {
	return read_string(&p.r, p.allocator)
}

// Read the vnum after '#' in a #MOBS/#OBJS/#ROOMS record list.
// Returns 0 at the `#0` terminator. Until the new vnum is read, errors keep
// the previous record's vnum: a missing '#' usually means that record (for
// example an unterminated string) is what went wrong.
@(private)
read_record_vnum :: proc(p: ^Parser) -> (vnum: int, err: Parse_Error) {
	line, column := next_position(&p.r)
	letter := read_letter(&p.r) or_return
	if letter != '#' {
		return 0, reader_fail_at(&p.r, line, column, .Expected_Hash, "expected # before a vnum", string([]u8{letter}))
	}
	line, column = next_position(&p.r)
	vnum = read_number(&p.r) or_return
	if vnum < 0 || vnum > models.VNUM_MAX {
		return 0, reader_fail_at(&p.r, line, column, .Vnum_Out_Of_Range, "vnum must be between 0 and 32767")
	}
	p.r.vnum = vnum
	return vnum, nil
}

// load_area (db.c).
@(private)
parse_area_header :: proc(p: ^Parser) -> (h: models.Area_Header, err: Parse_Error) {
	h.line = p.r.line
	h.file_name = read_str(p) or_return
	h.name = read_str(p) or_return
	h.credits = read_str(p) or_return
	h.low_level = read_number(&p.r) or_return
	h.high_level = read_number(&p.r) or_return
	h.min_vnum = read_number(&p.r) or_return
	h.max_vnum = read_number(&p.r) or_return
	h.area_type = read_word(&p.r) or_return
	h.climate = read_word(&p.r) or_return
	h.flags = read_flag_token(&p.r) or_return
	h.security = read_number(&p.r) or_return
	h.builders = read_str(p) or_return
	return h, nil
}

// load_rooms (db.c).
@(private)
parse_rooms_section :: proc(p: ^Parser) -> Parse_Error {
	for {
		skip_whitespace(&p.r)
		record_line := p.r.line
		vnum := read_record_vnum(p) or_return
		if vnum == 0 {
			return nil
		}
		room := models.Room {
			vnum      = vnum,
			heal_rate = 100,
			mana_rate = 100,
			line      = record_line,
		}
		flags := make([dynamic]string, p.allocator)
		extras := make([dynamic]models.Extra_Description, p.allocator)
		replaced := make([dynamic]models.Exit, p.allocator)

		room.name = read_str(p) or_return
		room.description = read_str(p) or_return
		room.sector = read_word(&p.r) or_return

		fields: for {
			before := p.r
			skip_whitespace(&p.r)
			field_line := p.r.line
			letter := to_upper(read_letter(&p.r) or_return)
			switch letter {
			case 'S':
				break fields
			case 'H':
				room.heal_rate = read_number(&p.r) or_return
			case 'M':
				room.mana_rate = read_number(&p.r) or_return
			case 'G':
				room.guild = read_number(&p.r) or_return
			case 'A':
				read_word(&p.r) or_return
				alt: models.Alt_Description
				alt.condition = read_number(&p.r) or_return
				alt.name = read_str(p) or_return
				alt.description = read_str(p) or_return
				room.alt_description = alt
			case 'C':
				read_word(&p.r) or_return
				room.cabal = read_word(&p.r) or_return
			case 'D':
				exit := models.Exit {
					line = field_line,
				}
				dir_line, dir_column := next_position(&p.r)
				dir_word := read_word(&p.r) or_return
				dir, ok := lookup_direction(dir_word)
				if !ok {
					return reader_fail_at(&p.r, dir_line, dir_column, .Bad_Direction, "unknown exit direction", dir_word)
				}
				exit.direction = dir
				exit.target = read_number(&p.r) or_return
				exit.flags = read_flag_token(&p.r) or_return
				exit.key = read_number(&p.r) or_return
				exit.keyword = read_str(p) or_return
				exit.description = read_str(p) or_return
				if previous, has_previous := room.exits[dir].?; has_previous {
					append(&replaced, previous)
				}
				room.exits[dir] = exit
			case 'E':
				extra := models.Extra_Description {
					line = field_line,
				}
				extra.keyword = read_str(p) or_return
				extra.description = read_str(p) or_return
				append(&extras, extra)
			case 'T':
				read_word(&p.r) or_return
				trap: models.Room_Trap
				trap.trap_type = read_word(&p.r) or_return
				trap.quality = read_number(&p.r) or_return
				trap.complexity = read_number(&p.r) or_return
				trap.timer = read_number(&p.r) or_return
				trap.trigger_echo = read_str(p) or_return
				trap.execute_echo = read_str(p) or_return
				room.trap = trap
			case 'O':
				read_word(&p.r) or_return
				room.owner = read_str(p) or_return
			case 'R':
				read_word(&p.r) or_return
				append(&flags, read_word(&p.r) or_return)
			case:
				// Not a room field: the room ends here (the game ungetc's the letter).
				p.r = before
				break fields
			}
		}
		room.flags = flags[:]
		room.extras = extras[:]
		room.replaced_exits = replaced[:]
		append(&p.rooms, room)
	}
}

// load_newresets (db.c). Only the first letter of each command matters.
@(private)
parse_resets_section :: proc(p: ^Parser) -> Parse_Error {
	last_room := 0
	for {
		p.r.vnum = 0
		line, column := next_position(&p.r)
		letter := read_letter(&p.r) or_return
		if letter == 'S' {
			return nil
		}
		if letter == '*' {
			read_to_eol(&p.r)
			continue
		}
		read_word(&p.r) or_return // rest of the command word, e.g. "OB" in "MOB"
		reset := models.Reset {
			line = line,
		}
		switch letter {
		case 'F':
			reset.command = .Follow
			reset.vnum = read_number(&p.r) or_return
			reset.leader_index = read_number(&p.r) or_return
			reset.context_room = last_room
		case 'M':
			reset.command = .Mob
			reset.vnum = read_number(&p.r) or_return
			read_word(&p.r) or_return // TO
			reset.room = read_number(&p.r) or_return
			read_word(&p.r) or_return // GLIMIT
			reset.global_limit = read_number(&p.r) or_return
			read_word(&p.r) or_return // LLIMIT
			reset.local_limit = read_number(&p.r) or_return
			last_room = reset.room
			reset.context_room = reset.room
		case 'O':
			reset.command = .Object
			reset.vnum = read_number(&p.r) or_return
			read_word(&p.r) or_return // TO
			reset.room = read_number(&p.r) or_return
			last_room = reset.room
			reset.context_room = reset.room
		case 'P':
			reset.command = .Put
			reset.vnum = read_number(&p.r) or_return
			read_word(&p.r) or_return // IN
			reset.container = read_number(&p.r) or_return
			read_word(&p.r) or_return // COUNT
			reset.count = read_number(&p.r) or_return
			reset.context_room = last_room
		case 'G':
			reset.command = .Give
			reset.vnum = read_number(&p.r) or_return
			reset.context_room = last_room
		case 'E':
			reset.command = .Equip
			reset.vnum = read_number(&p.r) or_return
			reset.wear_location = read_word(&p.r) or_return
			reset.context_room = last_room
		case 'D':
			reset.command = .Door
			reset.room = read_number(&p.r) or_return
			dir_line, dir_column := next_position(&p.r)
			dir_word := read_word(&p.r) or_return
			dir, ok := lookup_direction(dir_word)
			if !ok {
				return reader_fail_at(&p.r, dir_line, dir_column, .Bad_Direction, "unknown direction in door reset", dir_word)
			}
			reset.direction = dir
			state_line, state_column := next_position(&p.r)
			switch to_upper(read_letter(&p.r) or_return) {
			case 'O':
				reset.door_state = .Open
			case 'C':
				reset.door_state = .Closed
			case 'L':
				reset.door_state = .Locked
			case:
				return reader_fail_at(&p.r, state_line, state_column, .Bad_Reset, "door state must be OPEN, CLOSED or LOCKED")
			}
			reset.context_room = reset.room
		case 'R':
			reset.command = .Randomize
			reset.room = read_number(&p.r) or_return
			count_line, count_column := next_position(&p.r)
			reset.exit_count = read_number(&p.r) or_return
			if reset.exit_count < 0 || reset.exit_count > 6 {
				return reader_fail_at(&p.r, count_line, count_column, .Bad_Reset, "randomize exit count must be 0-6")
			}
			reset.context_room = reset.room
		case:
			return reader_fail_at(&p.r, line, column, .Bad_Reset, "unknown reset command", string([]u8{letter}))
		}
		read_to_eol(&p.r)
		append(&p.resets, reset)
	}
}

// load_improgs (db2.c).
@(private)
parse_improgs_section :: proc(p: ^Parser) -> Parse_Error {
	for {
		line, column := next_position(&p.r)
		letter := read_letter(&p.r) or_return
		binding := models.Program_Binding {
			line = line,
		}
		switch letter {
		case 'E':
			read_word(&p.r) or_return // rest of END
			return nil
		case '*':
		case 'I', 'R', 'M':
			binding.target = .Object if letter == 'I' else .Room if letter == 'R' else .Mob
			binding.vnum = read_number(&p.r) or_return
			binding.program_type = read_word(&p.r) or_return
			binding.name = read_word(&p.r) or_return
			append(&p.programs, binding)
		case 'A':
			binding.target = .Area
			binding.program_type = read_word(&p.r) or_return
			binding.name = read_word(&p.r) or_return
			append(&p.programs, binding)
		case 'S':
			// The game skips the rest of the line. Record what it says so a
			// validator can point out that it has no effect.
			after_letter := p.r
			binding.target = .Ignored_Spec
			vnum, vnum_err := read_number(&p.r)
			if vnum_err == nil {
				binding.vnum = vnum
				name, name_err := read_word(&p.r)
				if name_err == nil {
					binding.name = name
				}
			}
			p.r = after_letter
			append(&p.programs, binding)
		case:
			return reader_fail_at(&p.r, line, column, .Bad_Program_Line, "#IMPROGS lines must start with I, R, A, M, S, * or END", string([]u8{letter}))
		}
		read_to_eol(&p.r)
	}
}

// load_specs (db2.c).
@(private)
parse_specs_section :: proc(p: ^Parser) -> Parse_Error {
	for {
		line, column := next_position(&p.r)
		letter := read_letter(&p.r) or_return
		switch letter {
		case 'E':
			read_word(&p.r) or_return // rest of END
			return nil
		case '*':
		case 'I', 'M':
			spec := models.Spec_Binding {
				target = .Object if letter == 'I' else .Mob,
				line   = line,
			}
			spec.vnum = read_number(&p.r) or_return
			spec.name = read_word(&p.r) or_return
			append(&p.specs, spec)
		case:
			return reader_fail_at(&p.r, line, column, .Bad_Program_Line, "#SPECS lines must start with I, M, * or END", string([]u8{letter}))
		}
		read_to_eol(&p.r)
	}
}

// #SOCIALS is not modeled. Skip to the line that holds only "#0", which is
// where load_socials (db2.c) stops.
@(private)
skip_socials_section :: proc(p: ^Parser) -> Parse_Error {
	start_line, start_column := p.r.line, p.r.column
	for !at_eof(&p.r) {
		line_start := p.r.pos
		for !at_eof(&p.r) && p.r.data[p.r.pos] != '\n' && p.r.data[p.r.pos] != '\r' {
			advance(&p.r)
		}
		text := strings.trim_space(string(p.r.data[line_start:p.r.pos]))
		read_to_eol(&p.r)
		if text == "#0" {
			return nil
		}
	}
	return reader_fail_at(&p.r, start_line, start_column, .Unexpected_EOF, "#SOCIALS has no closing #0")
}
