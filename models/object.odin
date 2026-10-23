/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package models

// One of an object's five values: a number, or a raw word/flag token.
// Which slots hold which kind depends on the item type.
Object_Value :: union {
	int,
	string,
}

// `APPLY <location> <modifier>`.
Object_Apply :: struct {
	location: string,
	modifier: int,
}

// `FLAG AFF <skill> <flag> <SHOW|...>`, `FLAG IMM|RES|VUL <flag>`.
Object_Flag :: struct {
	kind:  string, // AFF, IMM, RES or VUL
	skill: string, // AFF only
	flag:  string,
	show:  string, // AFF only
}

// An object definition from the #OBJS section.
Object :: struct {
	vnum:              int,
	keywords:          string,
	short_description: string,
	description:       string,
	item_type:         string, // Raw item type word as written
	material:          string,
	values:            [5]Object_Value,
	level:             int,
	weight:            int,
	cost:              int,
	condition:         u8, // Condition letter (P, G, A, W, D, B, R)
	applies:           []Object_Apply,
	flags:             []Object_Flag,
	extra_flags:       []string,
	wear_flags:        []string,
	restrictions:      []string,
	extras:            []Extra_Description,
	cabal:             string,
	limit:             int,
	timer:             int, // -1 when not set
	verb:              string,
	wear_echo:         [2]string,
	remove_echo:       [2]string,
	wear_location:     string,
	notes:             string,
	line:              int,
}
