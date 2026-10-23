/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"

import "../models"

// load_mobs (riftshadow/code/db2.c).
@(private)
parse_mobs_section :: proc(p: ^Parser) -> Parse_Error {
	for {
		skip_whitespace(&p.r)
		record_line := p.r.line
		vnum := read_record_vnum(p) or_return
		if vnum == 0 {
			return nil
		}
		mob := parse_mobile(p, vnum) or_return
		mob.line = record_line
		append(&p.mobiles, mob)
	}
}

@(private)
read_dice :: proc(r: ^Reader) -> (d: models.Dice, err: Parse_Error) {
	d.count = read_number(r) or_return
	read_letter(r) or_return // 'd'
	d.sides = read_number(r) or_return
	read_letter(r) or_return // '+'
	d.bonus = read_number(r) or_return
	return d, nil
}

// First letters and second letters that start a flag-pair line (ACT, AFF,
// OFF, IMM, RES, VUL, CLASS, SPEECH). The game peeks at two letters and only
// treats the line as a flag pair when both are in these sets.
@(private)
FLAG_PAIR_FIRST :: "AOIRVCS"
@(private)
FLAG_PAIR_SECOND :: "CFMEUPL"

@(private)
starts_flag_pair :: proc(r: ^Reader) -> bool {
	saved := r^
	defer r^ = saved
	first, err1 := read_letter(r)
	if err1 != nil {
		return false
	}
	second, err2 := read_letter(r)
	if err2 != nil {
		return false
	}
	return strings.index_byte(FLAG_PAIR_FIRST, to_upper(first)) >= 0 && strings.index_byte(FLAG_PAIR_SECOND, to_upper(second)) >= 0
}

@(private)
parse_mobile :: proc(p: ^Parser, vnum: int) -> (mob: models.Mobile, err: Parse_Error) {
	r := &p.r
	mob.vnum = vnum
	mob.keywords = read_str(p) or_return
	mob.short_description = read_str(p) or_return
	mob.long_description = read_str(p) or_return
	mob.description = read_str(p) or_return
	mob.alignment = read_number(r) or_return
	mob.group = read_number(r) or_return
	mob.xp_mod = read_number(r) or_return
	mob.race = read_str(p) or_return
	mob.level = read_number(r) or_return
	mob.hit = read_dice(r) or_return
	mob.damage = read_dice(r) or_return
	mob.hitroll = read_number(r) or_return
	mob.damage_mod = read_number(r) or_return
	mob.damage_type = read_word(r) or_return
	for i in 0 ..< len(mob.armor) {
		mob.armor[i] = read_number(r) or_return
	}
	mob.start_position = read_word(r) or_return
	mob.sex = read_word(r) or_return
	mob.wealth = read_word(r) or_return
	mob.form = read_flag_token(r) or_return
	mob.parts = read_flag_token(r) or_return
	mob.size = read_word(r) or_return

	flags := make([dynamic]models.Mob_Flag, p.allocator)
	speeches := make([dynamic]models.Speech, p.allocator)
	for starts_flag_pair(r) {
		skip_whitespace(r)
		flag := models.Mob_Flag {
			line = r.line,
		}
		flag.kind = read_word(r) or_return
		flag.value = read_word(r) or_return
		if strings.equal_fold(flag.kind, "CLASS") {
			// Warriors list two fighting styles, sorcerers two elements.
			if strings.equal_fold(flag.value, "warrior") || strings.equal_fold(flag.value, "sorcerer") {
				flag.extra[0] = read_word(r) or_return
				flag.extra[1] = read_word(r) or_return
			}
		}
		if strings.equal_fold(flag.kind, "SPEECH") {
			append(&speeches, parse_speech(p, flag.value) or_return)
		}
		append(&flags, flag)
	}
	mob.flags = flags[:]
	mob.speeches = speeches[:]

	removals := make([dynamic]models.Mob_Flag_Removal, p.allocator)
	affects := make([dynamic]models.Mob_Affect, p.allocator)
	casts := make([dynamic]string, p.allocator)
	teaches := make([dynamic]string, p.allocator)
	trailer: for {
		before := r^
		// Unlike rooms and objects, mob trailer letters are case-sensitive.
		letter := read_letter(r) or_return
		switch letter {
		case 'F':
			removal: models.Mob_Flag_Removal
			removal.table = read_word(r) or_return
			removal.flags = read_flag_token(r) or_return
			append(&removals, removal)
		case 'A':
			affect: models.Mob_Affect
			affect.skill = read_word(r) or_return
			affect.flag = read_word(r) or_return
			append(&affects, affect)
		case 'C':
			// "CABAL <name>" or "C <spell>": the game checks whether the next
			// letter is 'A'.
			after_c := r^
			next, next_err := read_letter(r)
			if next_err == nil && next == 'A' {
				read_word(r) or_return // rest of CABAL
				mob.cabal = read_word(r) or_return
				continue
			}
			r^ = after_c
			append(&casts, read_word(r) or_return)
		case 'B':
			mob.barred = parse_barred_entry(p) or_return
		case 'N':
			read_word(r) or_return // rest of NOTES
			mob.notes = read_str(p) or_return
		case 'L':
			read_word(r) or_return // rest of LIMIT
			low := read_number(r) or_return
			high := read_number(r) or_return
			mob.level_limit = [2]int{low, high}
		case 'S':
			mob.shop = parse_shop(p) or_return
		case 'T':
			read_word(r) or_return // rest of TEACHES
			append(&teaches, read_str(p) or_return)
		case 'Y':
			read_word(r) or_return // rest of YELL
			mob.attack_yell = read_str(p) or_return
		case:
			r^ = before
			break trailer
		}
	}
	mob.flag_removals = removals[:]
	mob.affects = affects[:]
	mob.casts = casts[:]
	mob.teaches = teaches[:]
	return mob, nil
}

// SPEECH <name> then `LINE <delay> <type> text~` entries until END.
@(private)
parse_speech :: proc(p: ^Parser, name: string) -> (speech: models.Speech, err: Parse_Error) {
	r := &p.r
	speech.name = name
	lines := make([dynamic]models.Speech_Line, p.allocator)
	for {
		line, column := next_position(r)
		word := read_word(r) or_return
		if strings.equal_fold(word, "END") {
			break
		}
		if !strings.equal_fold(word, "LINE") {
			return speech, reader_fail_at(r, line, column, .Bad_Mobile, "SPEECH entries must be LINE or END", word)
		}
		entry: models.Speech_Line
		entry.delay = read_number(r) or_return
		entry.line_type = read_word(r) or_return
		entry.text = read_str(p) or_return
		append(&lines, entry)
	}
	speech.lines = lines[:]
	return speech, nil
}

// `B <criterion> <comparison> <value> <vnum> <SAY|EMOTE|ECHO> message~ [message~]`.
// The 'B' has already been read.
@(private)
parse_barred_entry :: proc(p: ^Parser) -> (bar: models.Barred_Entry, err: Parse_Error) {
	r := &p.r
	bar.criterion = read_word(r) or_return
	cmp_line, cmp_column := next_position(r)
	bar.comparison = read_word(r) or_return
	if !strings.equal_fold(bar.comparison, "EQUALTO") && !strings.equal_fold(bar.comparison, "LESSTHAN") && !strings.equal_fold(bar.comparison, "GREATERTHAN") {
		return bar, reader_fail_at(r, cmp_line, cmp_column, .Bad_Mobile, "barred entry comparison must be EQUALTO, LESSTHAN or GREATERTHAN", bar.comparison)
	}
	bar.value = read_number(r) or_return
	bar.vnum = read_number(r) or_return
	msg_line, msg_column := next_position(r)
	bar.message_type = read_word(r) or_return
	switch {
	case strings.equal_fold(bar.message_type, "ECHO"):
		bar.message = read_str(p) or_return
		bar.message_two = read_str(p) or_return
	case strings.equal_fold(bar.message_type, "SAY"), strings.equal_fold(bar.message_type, "EMOTE"):
		bar.message = read_str(p) or_return
	case:
		return bar, reader_fail_at(r, msg_line, msg_column, .Bad_Mobile, "barred entry message type must be SAY, EMOTE or ECHO", bar.message_type)
	}
	return bar, nil
}

// `SHOPKEEPER OPEN <hour> CLOSE <hour> EXIT <direction>`. The 'S' has already been read.
@(private)
parse_shop :: proc(p: ^Parser) -> (shop: models.Shop, err: Parse_Error) {
	r := &p.r
	read_word(r) or_return // rest of SHOPKEEPER
	read_word(r) or_return // OPEN
	shop.open_hour = read_number(r) or_return
	read_word(r) or_return // CLOSE
	shop.close_hour = read_number(r) or_return
	read_word(r) or_return // EXIT
	dir_line, dir_column := next_position(r)
	shop.exit = read_word(r) or_return
	if _, ok := lookup_direction(shop.exit); !ok {
		return shop, reader_fail_at(r, dir_line, dir_column, .Bad_Direction, "unknown shop exit direction", shop.exit)
	}
	return shop, nil
}
