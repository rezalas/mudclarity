/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"

import "../models"

/*
 Lookup tables mirrored from Riftshadow. Only the tables the parser needs to
 decide *how* to read a field live here; flag-name validation comes later.
*/

// Item types whose five values are not all read as flags (load_objs in db2.c).
Item_Value_Layout :: enum {
	Flags,     // default: five fread_flag values
	Weapon,    // word, number, number, word, flag
	Container, // number, flag, number, number, number
	Drink,     // number, number, word, number, number (drink containers, fountains)
	Charged,   // number, number, number, word, number (wands, staves)
	Spells,    // number, word, word, word, word (potions, pills, scrolls)
}

Item_Type_Entry :: struct {
	name:   string,
	layout: Item_Value_Layout,
}

// item_table from riftshadow/code/const.c, in table order. Order matters:
// item_lookup returns the first entry the word is a prefix of.
ITEM_TYPES := [?]Item_Type_Entry {
	{"light", .Flags},
	{"scroll", .Spells},
	{"wand", .Charged},
	{"staff", .Charged},
	{"weapon", .Weapon},
	{"null6", .Flags},
	{"dice", .Flags},
	{"stone", .Flags},
	{"treasure", .Flags},
	{"armor", .Flags},
	{"potion", .Spells},
	{"clothing", .Flags},
	{"furniture", .Flags},
	{"trash", .Flags},
	{"container", .Container},
	{"drink", .Drink},
	{"key", .Flags},
	{"food", .Flags},
	{"money", .Flags},
	{"boat", .Flags},
	{"npc_corpse", .Flags},
	{"pc_corpse", .Flags},
	{"fountain", .Drink},
	{"pill", .Spells},
	{"protect", .Flags},
	{"map", .Flags},
	{"portal", .Flags},
	{"warp_stone", .Flags},
	{"room_key", .Flags},
	{"gem", .Flags},
	{"jewelry", .Flags},
	{"skeleton", .Flags},
	{"urn", .Flags},
	{"gravitywell", .Flags},
	{"book", .Flags},
	{"pen", .Flags},
	{"altar", .Flags},
	{"campfire", .Flags},
}

// Case-insensitive "is `word` a prefix of `name`", like Riftshadow's
// !str_prefix(word, name). An empty word matches everything, as in the game.
has_prefix_fold :: proc(name, word: string) -> bool {
	if len(word) > len(name) {
		return false
	}
	return strings.equal_fold(name[:len(word)], word)
}

// item_lookup: find the item type `word` names. ok is false for unknown
// types, which the game reads with the default Flags layout.
lookup_item_type :: proc(word: string) -> (entry: Item_Type_Entry, ok: bool) {
	for e in ITEM_TYPES {
		if has_prefix_fold(e.name, word) {
			return e, true
		}
	}
	return {}, false
}

DIRECTION_NAMES := [models.Direction]string {
	.North = "north",
	.East  = "east",
	.South = "south",
	.West  = "west",
	.Up    = "up",
	.Down  = "down",
}

// flag_lookup on direction_table: first letters must match (ignoring case)
// and the word must be a prefix of the direction name.
lookup_direction :: proc(word: string) -> (dir: models.Direction, ok: bool) {
	if len(word) == 0 {
		return {}, false
	}
	for name, d in DIRECTION_NAMES {
		if to_upper(word[0]) == to_upper(name[0]) && has_prefix_fold(name, word) {
			return d, true
		}
	}
	return {}, false
}
