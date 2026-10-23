/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"
import "core:testing"

import "../models"

// An object with the given item type and value line, then `trailer`.
@(private = "file")
object_text :: proc(item_type, values, trailer: string) -> string {
	return with_header(strings.concatenate({`#OBJS
#3000
barrel beer~
a barrel of beer~
A beer barrel has been left here.~
`, item_type, "\nwood~\n", values, "\n0 16 75 P\n", trailer, "#0\n"}, context.temp_allocator))
}

@(private = "file")
parse_one_object :: proc(t: ^testing.T, item_type, values: string, trailer := "", loc := #caller_location) -> (^Loaded_Area, models.Object) {
	loaded := must_parse(t, object_text(item_type, values, trailer), loc)
	if loaded == nil || !testing.expect_value(t, len(loaded.area.objects), 1, loc = loc) {
		return loaded, {}
	}
	return loaded, loaded.area.objects[0]
}

@(test)
test_object_base_fields :: proc(t: ^testing.T) {
	loaded, obj := parse_one_object(t, "drink", "300 300 'beer' 0 0")
	defer unload_area(loaded)
	testing.expect_value(t, obj.vnum, 3000)
	testing.expect_value(t, obj.line, body_line(2))
	testing.expect_value(t, obj.keywords, "barrel beer")
	testing.expect_value(t, obj.short_description, "a barrel of beer")
	testing.expect_value(t, obj.description, "A beer barrel has been left here.")
	testing.expect_value(t, obj.item_type, "drink")
	testing.expect_value(t, obj.material, "wood")
	testing.expect_value(t, obj.level, 0)
	testing.expect_value(t, obj.weight, 16)
	testing.expect_value(t, obj.cost, 75)
	testing.expect_value(t, obj.condition, u8('P'))
	testing.expect_value(t, obj.timer, -1)
}

@(private = "file")
expect_values :: proc(t: ^testing.T, item_type, values: string, expected: [5]models.Object_Value, loc := #caller_location) {
	loaded, obj := parse_one_object(t, item_type, values, "", loc)
	defer unload_area(loaded)
	for v, i in expected {
		testing.expectf(t, obj.values[i] == v, "%s value %d: expected %v, got %v", item_type, i, v, obj.values[i], loc = loc)
	}
}

@(test)
test_object_value_layouts :: proc(t: ^testing.T) {
	expect_values(t, "weapon", "sword 2 6 slash AB", {"sword", 2, 6, "slash", "AB"})
	expect_values(t, "container", "50 AC 3001 10 100", {50, "AC", 3001, 10, 100})
	expect_values(t, "drink", "300 300 'beer' 0 0", {300, 300, "beer", 0, 0})
	expect_values(t, "fountain", "1000 1000 water 0 0", {1000, 1000, "water", 0, 0})
	expect_values(t, "wand", "20 5 5 'magic missile' 0", {20, 5, 5, "magic missile", 0})
	expect_values(t, "staff", "20 5 5 heal 0", {20, 5, 5, "heal", 0})
	expect_values(t, "potion", "20 'cure light' '' '' ''", {20, "cure light", "", "", ""})
	expect_values(t, "pill", "20 bless armor '' ''", {20, "bless", "armor", "", ""})
	expect_values(t, "scroll", "20 identify '' '' ''", {20, "identify", "", "", ""})
	expect_values(t, "armor", "4 4 4 0 0", {"4", "4", "4", "0", "0"})
	expect_values(t, "npc_corpse", "0 0 0 0 0", {"0", "0", "0", "0", "0"})
}

@(test)
test_object_item_type_is_a_prefix_lookup :: proc(t: ^testing.T) {
	// "cont" is a prefix of "container", so container values are read.
	expect_values(t, "cont", "50 AC 3001 10 100", {50, "AC", 3001, 10, 100})
	// "w" matches "wand" before "weapon" in table order.
	expect_values(t, "w", "20 5 5 heal 0", {20, 5, 5, "heal", 0})
	// Unknown types fall back to five flag values, as in the game.
	expect_values(t, "widget", "A B C D E", {"A", "B", "C", "D", "E"})
}

@(test)
test_object_trailer_fields :: proc(t: ^testing.T) {
	trailer := `WEAR TAKE
WEAR FINGER
ITEM GLOW
RESTRICT good
APPLY hitroll 2
APPLY damroll -1
FLAG AFF 'detect invis' DETECT_INVIS SHOW
FLAG IMM fire
CABAL HORDE
E ring band~
A plain band.
~
MSG WEAR You slip it on.~
$n slips it on.~
MSG REMOVE You take it off.~
$n takes it off.~
LIMIT 5
TIMER 30
VERB smite
NAMEOFLOC on the finger~
NOTES Quest reward.~
SPELL
`
	loaded, obj := parse_one_object(t, "jewelry", "0 0 0 0 0", trailer)
	defer unload_area(loaded)
	testing.expect_value(t, len(obj.wear_flags), 2)
	testing.expect_value(t, obj.wear_flags[1], "FINGER")
	testing.expect_value(t, obj.extra_flags[0], "GLOW")
	testing.expect_value(t, obj.restrictions[0], "good")
	if testing.expect_value(t, len(obj.applies), 2) {
		testing.expect_value(t, obj.applies[0].location, "hitroll")
		testing.expect_value(t, obj.applies[1].modifier, -1)
	}
	if testing.expect_value(t, len(obj.flags), 2) {
		testing.expect_value(t, obj.flags[0].kind, "AFF")
		testing.expect_value(t, obj.flags[0].skill, "detect invis")
		testing.expect_value(t, obj.flags[0].flag, "DETECT_INVIS")
		testing.expect_value(t, obj.flags[0].show, "SHOW")
		testing.expect_value(t, obj.flags[1].kind, "IMM")
		testing.expect_value(t, obj.flags[1].flag, "fire")
	}
	testing.expect_value(t, obj.cabal, "HORDE")
	if testing.expect_value(t, len(obj.extras), 1) {
		testing.expect_value(t, obj.extras[0].keyword, "ring band")
	}
	testing.expect_value(t, obj.wear_echo, [2]string{"You slip it on.", "$n slips it on."})
	testing.expect_value(t, obj.remove_echo, [2]string{"You take it off.", "$n takes it off."})
	testing.expect_value(t, obj.limit, 5)
	testing.expect_value(t, obj.timer, 30)
	testing.expect_value(t, obj.verb, "smite")
	testing.expect_value(t, obj.wear_location, "on the finger")
	testing.expect_value(t, obj.notes, "Quest reward.")
}

@(test)
test_object_trailer_errors :: proc(t: ^testing.T) {
	expect_parse_failure(t, object_text("trash", "0 0 0 0 0", "FLAG XYZ fire\n"), .Bad_Object, body_line(10))
	expect_parse_failure(t, object_text("trash", "0 0 0 0 0", "MSG DROP hi~\nhi~\n"), .Bad_Object, body_line(10))
	expect_parse_failure(t, object_text("weapon", "sword x 6 slash 0", ""), .Bad_Number, body_line(8))
}

@(test)
test_object_condition_letter_is_any_byte :: proc(t: ^testing.T) {
	text, _ := strings.replace(object_text("trash", "0 0 0 0 0", ""), "75 P", "75 R", 1, context.temp_allocator)
	loaded := must_parse(t, text)
	defer unload_area(loaded)
	if loaded == nil do return
	testing.expect_value(t, loaded.area.objects[0].condition, u8('R'))
}
