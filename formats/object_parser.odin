/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"

import "../models"

// load_objs (riftshadow/code/db2.c).
@(private)
parse_objs_section :: proc(p: ^Parser) -> Parse_Error {
	for {
		skip_whitespace(&p.r)
		record_line := p.r.line
		vnum := read_record_vnum(p) or_return
		if vnum == 0 {
			return nil
		}
		obj := parse_object(p, vnum) or_return
		obj.line = record_line
		append(&p.objects, obj)
	}
}

@(private)
Value_Kind :: enum {
	Number,
	Word,
	Flag,
}

@(private)
VALUE_LAYOUTS := [Item_Value_Layout][5]Value_Kind {
	.Flags     = {.Flag, .Flag, .Flag, .Flag, .Flag},
	.Weapon    = {.Word, .Number, .Number, .Word, .Flag},
	.Container = {.Number, .Flag, .Number, .Number, .Number},
	.Drink     = {.Number, .Number, .Word, .Number, .Number},
	.Charged   = {.Number, .Number, .Number, .Word, .Number},
	.Spells    = {.Number, .Word, .Word, .Word, .Word},
}

@(private)
parse_object :: proc(p: ^Parser, vnum: int) -> (obj: models.Object, err: Parse_Error) {
	r := &p.r
	obj.vnum = vnum
	obj.timer = -1
	obj.keywords = read_str(p) or_return
	obj.short_description = read_str(p) or_return
	obj.description = read_str(p) or_return
	obj.item_type = read_word(r) or_return
	obj.material = read_str(p) or_return

	// Unknown item types use the default (all flags) layout, as in the game.
	layout := Item_Value_Layout.Flags
	if entry, ok := lookup_item_type(obj.item_type); ok {
		layout = entry.layout
	}
	for kind, i in VALUE_LAYOUTS[layout] {
		switch kind {
		case .Number:
			obj.values[i] = read_number(r) or_return
		case .Word:
			obj.values[i] = read_word(r) or_return
		case .Flag:
			obj.values[i] = read_flag_token(r) or_return
		}
	}
	obj.level = read_number(r) or_return
	obj.weight = read_number(r) or_return
	obj.cost = read_number(r) or_return
	obj.condition = read_letter(r) or_return

	applies := make([dynamic]models.Object_Apply, p.allocator)
	flags := make([dynamic]models.Object_Flag, p.allocator)
	extra_flags := make([dynamic]string, p.allocator)
	wear_flags := make([dynamic]string, p.allocator)
	restrictions := make([dynamic]string, p.allocator)
	extras := make([dynamic]models.Extra_Description, p.allocator)
	trailer: for {
		before := r^
		skip_whitespace(r)
		field_line := r.line
		letter := to_upper(read_letter(r) or_return)
		switch letter {
		case 'A':
			read_word(r) or_return // rest of APPLY
			apply: models.Object_Apply
			apply.location = read_word(r) or_return
			apply.modifier = read_number(r) or_return
			append(&applies, apply)
		case 'C':
			read_word(r) or_return // rest of CABAL
			obj.cabal = read_word(r) or_return
		case 'F':
			read_word(r) or_return // rest of FLAG
			kind_line, kind_column := next_position(r)
			flag: models.Object_Flag
			flag.kind = read_word(r) or_return
			switch {
			case strings.equal_fold(flag.kind, "AFF"):
				flag.skill = read_word(r) or_return
				flag.flag = read_word(r) or_return
				flag.show = read_word(r) or_return
			case strings.equal_fold(flag.kind, "IMM"), strings.equal_fold(flag.kind, "RES"), strings.equal_fold(flag.kind, "VUL"):
				flag.flag = read_word(r) or_return
			case:
				return obj, reader_fail_at(r, kind_line, kind_column, .Bad_Object, "FLAG must be AFF, IMM, RES or VUL", flag.kind)
			}
			append(&flags, flag)
		case 'E':
			extra := models.Extra_Description {
				line = field_line,
			}
			extra.keyword = read_str(p) or_return
			extra.description = read_str(p) or_return
			append(&extras, extra)
		case 'I':
			read_word(r) or_return
			append(&extra_flags, read_word(r) or_return)
		case 'M':
			read_word(r) or_return // rest of MSG
			kind_line, kind_column := next_position(r)
			kind := read_word(r) or_return
			switch {
			case strings.equal_fold(kind, "WEAR"):
				obj.wear_echo[0] = read_str(p) or_return
				obj.wear_echo[1] = read_str(p) or_return
			case strings.equal_fold(kind, "REMOVE"):
				obj.remove_echo[0] = read_str(p) or_return
				obj.remove_echo[1] = read_str(p) or_return
			case:
				return obj, reader_fail_at(r, kind_line, kind_column, .Bad_Object, "MSG must be WEAR or REMOVE", kind)
			}
		case 'R':
			read_word(r) or_return
			append(&restrictions, read_word(r) or_return)
		case 'L':
			read_word(r) or_return
			obj.limit = read_number(r) or_return
		case 'S':
			read_word(r) or_return // SPELL: read and ignored by the game
		case 'W':
			read_word(r) or_return
			append(&wear_flags, read_word(r) or_return)
		case 'V':
			read_word(r) or_return
			obj.verb = read_word(r) or_return
		case 'T':
			read_word(r) or_return
			obj.timer = read_number(r) or_return
		case 'N':
			// The game compares the rest of the word, so NAMEOFLOC is "AMEOFLOC".
			rest := read_word(r) or_return
			if strings.equal_fold(rest, "AMEOFLOC") {
				obj.wear_location = read_str(p) or_return
			} else {
				obj.notes = read_str(p) or_return
			}
		case:
			r^ = before
			break trailer
		}
	}
	obj.applies = applies[:]
	obj.flags = flags[:]
	obj.extra_flags = extra_flags[:]
	obj.wear_flags = wear_flags[:]
	obj.restrictions = restrictions[:]
	obj.extras = extras[:]
	return obj, nil
}
