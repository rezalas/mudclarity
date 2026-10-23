/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"
import "core:testing"

// Mob fields up to and including size, for vnum 3000.
@(private = "file")
MOB_BASE :: `#3000
wizard~
the wizard~
A wizard walks around behind the counter.
~
The wizard looks old.
~
900 2 100 human~
38 1d1+999 4d8+37 5 100 magic
-1 2 3 4
standing male none
AB 0 medium
`

@(private = "file")
mobs_text :: proc(mob_body: string) -> string {
	return with_header(strings.concatenate({"#MOBS\n", mob_body, "#0\n"}, context.temp_allocator))
}

@(test)
test_mob_base_fields :: proc(t: ^testing.T) {
	loaded := must_parse(t, mobs_text(MOB_BASE))
	defer unload_area(loaded)
	if loaded == nil do return
	if !testing.expect_value(t, len(loaded.area.mobiles), 1) do return
	mob := loaded.area.mobiles[0]
	testing.expect_value(t, mob.vnum, 3000)
	testing.expect_value(t, mob.line, body_line(2))
	testing.expect_value(t, mob.keywords, "wizard")
	testing.expect_value(t, mob.short_description, "the wizard")
	testing.expect_value(t, mob.long_description, "A wizard walks around behind the counter.\n")
	testing.expect_value(t, mob.description, "The wizard looks old.\n")
	testing.expect_value(t, mob.alignment, 900)
	testing.expect_value(t, mob.group, 2)
	testing.expect_value(t, mob.xp_mod, 100)
	testing.expect_value(t, mob.race, "human")
	testing.expect_value(t, mob.level, 38)
	testing.expect_value(t, mob.hit.count, 1)
	testing.expect_value(t, mob.hit.sides, 1)
	testing.expect_value(t, mob.hit.bonus, 999)
	testing.expect_value(t, mob.damage.count, 4)
	testing.expect_value(t, mob.damage.sides, 8)
	testing.expect_value(t, mob.damage.bonus, 37)
	testing.expect_value(t, mob.hitroll, 5)
	testing.expect_value(t, mob.damage_mod, 100)
	testing.expect_value(t, mob.damage_type, "magic")
	testing.expect_value(t, mob.armor, [4]int{-1, 2, 3, 4})
	testing.expect_value(t, mob.start_position, "standing")
	testing.expect_value(t, mob.sex, "male")
	testing.expect_value(t, mob.wealth, "none")
	testing.expect_value(t, mob.form, "AB")
	testing.expect_value(t, mob.parts, "0")
	testing.expect_value(t, mob.size, "medium")
	testing.expect_value(t, len(mob.flags), 0)
}

@(test)
test_mob_flag_pairs :: proc(t: ^testing.T) {
	body := strings.concatenate({MOB_BASE, `ACT NPC
ACT SENTINEL
AFF DETECT_INVIS
OFF DODGE
IMM SUMMON
RES FIRE
VUL COLD
CLASS warrior Barbarian none
CLASS sorcerer fire water
CLASS thief
`}, context.temp_allocator)
	loaded := must_parse(t, mobs_text(body))
	defer unload_area(loaded)
	if loaded == nil do return
	flags := loaded.area.mobiles[0].flags
	if !testing.expect_value(t, len(flags), 10) do return
	testing.expect_value(t, flags[0].kind, "ACT")
	testing.expect_value(t, flags[0].value, "NPC")
	testing.expect_value(t, flags[0].line, body_line(14))
	testing.expect_value(t, flags[6].kind, "VUL")
	testing.expect_value(t, flags[7].value, "warrior")
	testing.expect_value(t, flags[7].extra, [2]string{"Barbarian", "none"})
	testing.expect_value(t, flags[8].extra, [2]string{"fire", "water"})
	testing.expect_value(t, flags[9].value, "thief")
	testing.expect_value(t, flags[9].extra, [2]string{"", ""})
}

@(test)
test_mob_speech :: proc(t: ^testing.T) {
	body := strings.concatenate({MOB_BASE, `SPEECH greeting
LINE 0 say Hello there.~
LINE 3 emote waves.~
END
ACT NPC
`}, context.temp_allocator)
	loaded := must_parse(t, mobs_text(body))
	defer unload_area(loaded)
	if loaded == nil do return
	mob := loaded.area.mobiles[0]
	if !testing.expect_value(t, len(mob.speeches), 1) do return
	speech := mob.speeches[0]
	testing.expect_value(t, speech.name, "greeting")
	if !testing.expect_value(t, len(speech.lines), 2) do return
	testing.expect_value(t, speech.lines[1].delay, 3)
	testing.expect_value(t, speech.lines[1].line_type, "emote")
	testing.expect_value(t, speech.lines[1].text, "waves.")
	testing.expect_value(t, len(mob.flags), 2)
}

@(test)
test_mob_speech_bad_entry :: proc(t: ^testing.T) {
	body := strings.concatenate({MOB_BASE, "SPEECH greeting\nTALK 0 say hi~\nEND\n"}, context.temp_allocator)
	expect_parse_failure(t, mobs_text(body), .Bad_Mobile, body_line(15))
}

@(test)
test_mob_trailer_fields :: proc(t: ^testing.T) {
	body := strings.concatenate({MOB_BASE, `ACT NPC
F act AB
A 'armor' (null)
C 'acid stream'
C ''
CABAL HORDE
NOTES Quest mob.
~
LIMIT 10 20
SHOPKEEPER OPEN 6 CLOSE 22 EXIT north
TEACHES bandaging~
TEACHES ancient languages~
YELL $n is here!~
B level LESSTHAN 10 3001 SAY You are too young.~
`}, context.temp_allocator)
	loaded := must_parse(t, mobs_text(body))
	defer unload_area(loaded)
	if loaded == nil do return
	mob := loaded.area.mobiles[0]
	testing.expect_value(t, len(mob.flags), 1)
	if testing.expect_value(t, len(mob.flag_removals), 1) {
		testing.expect_value(t, mob.flag_removals[0].table, "act")
		testing.expect_value(t, mob.flag_removals[0].flags, "AB")
	}
	if testing.expect_value(t, len(mob.affects), 1) {
		testing.expect_value(t, mob.affects[0].skill, "armor")
		testing.expect_value(t, mob.affects[0].flag, "(null)")
	}
	if testing.expect_value(t, len(mob.casts), 2) {
		testing.expect_value(t, mob.casts[0], "acid stream")
		testing.expect_value(t, mob.casts[1], "")
	}
	testing.expect_value(t, mob.cabal, "HORDE")
	testing.expect_value(t, mob.notes, "Quest mob.\n")
	testing.expect_value(t, mob.level_limit.?, [2]int{10, 20})
	shop, has_shop := mob.shop.?
	testing.expect(t, has_shop)
	testing.expect_value(t, shop.open_hour, 6)
	testing.expect_value(t, shop.close_hour, 22)
	testing.expect_value(t, shop.exit, "north")
	if testing.expect_value(t, len(mob.teaches), 2) {
		testing.expect_value(t, mob.teaches[1], "ancient languages")
	}
	testing.expect_value(t, mob.attack_yell, "$n is here!")
	bar, has_bar := mob.barred.?
	testing.expect(t, has_bar)
	testing.expect_value(t, bar.criterion, "level")
	testing.expect_value(t, bar.comparison, "LESSTHAN")
	testing.expect_value(t, bar.value, 10)
	testing.expect_value(t, bar.vnum, 3001)
	testing.expect_value(t, bar.message_type, "SAY")
	testing.expect_value(t, bar.message, "You are too young.")
}

@(test)
test_mob_barred_echo_reads_two_messages :: proc(t: ^testing.T) {
	body := strings.concatenate({MOB_BASE, "B class EQUALTO 2 3001 ECHO First.~\nSecond.~\n"}, context.temp_allocator)
	loaded := must_parse(t, mobs_text(body))
	defer unload_area(loaded)
	if loaded == nil do return
	bar := loaded.area.mobiles[0].barred.?
	testing.expect_value(t, bar.message, "First.")
	testing.expect_value(t, bar.message_two, "Second.")
}

@(test)
test_mob_barred_errors :: proc(t: ^testing.T) {
	bad_cmp := strings.concatenate({MOB_BASE, "B level ABOUT 10 3001 SAY hi~\n"}, context.temp_allocator)
	expect_parse_failure(t, mobs_text(bad_cmp), .Bad_Mobile, body_line(14))
	bad_msg := strings.concatenate({MOB_BASE, "B level EQUALTO 10 3001 SHOUT hi~\n"}, context.temp_allocator)
	expect_parse_failure(t, mobs_text(bad_msg), .Bad_Mobile, body_line(14))
}

@(test)
test_mob_shop_bad_direction :: proc(t: ^testing.T) {
	body := strings.concatenate({MOB_BASE, "SHOPKEEPER OPEN 0 CLOSE 23 EXIT sideways\n"}, context.temp_allocator)
	expect_parse_failure(t, mobs_text(body), .Bad_Direction, body_line(14))
}

@(test)
test_mob_trailer_letters_are_case_sensitive :: proc(t: ^testing.T) {
	// A lowercase letter is not a mob trailer, so the mob ends and the
	// loader expects '#'.
	body := strings.concatenate({MOB_BASE, "notes hi~\n"}, context.temp_allocator)
	expect_parse_failure(t, mobs_text(body), .Expected_Hash, body_line(14))
}

@(test)
test_two_mobs_in_a_row :: proc(t: ^testing.T) {
	second, _ := strings.replace(MOB_BASE, "#3000", "#3001", 1, context.temp_allocator)
	body := strings.concatenate({MOB_BASE, "ACT NPC\n", second}, context.temp_allocator)
	loaded := must_parse(t, mobs_text(body))
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, len(loaded.area.mobiles), 2)
	testing.expect_value(t, loaded.area.mobiles[1].vnum, 3001)
	testing.expect_value(t, len(loaded.area.mobiles[1].flags), 0)
}

@(test)
test_mob_bad_dice :: proc(t: ^testing.T) {
	bad, _ := strings.replace(MOB_BASE, "1d1+999", "1dx+999", 1, context.temp_allocator)
	expect_parse_failure(t, mobs_text(bad), .Bad_Number, body_line(10))
}
