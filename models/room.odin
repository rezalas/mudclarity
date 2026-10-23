/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package models

// An exit from a room (`D <dir> <vnum> <flags> <key>` then keyword~ description~).
Exit :: struct {
	direction:   Direction,
	target:      int,    // Target room vnum; may belong to another area
	flags:       string, // Raw exit flag token as written, e.g. "0" or "AB"
	key:         int,    // Key object vnum (0 or -1 means none)
	keyword:     string,
	description: string,
	line:        int,
}

// Alternate room name/description shown under a condition (`A` lines).
Alt_Description :: struct {
	condition:   int,
	name:        string,
	description: string,
}

// Room trap (`T` lines).
Room_Trap :: struct {
	trap_type:     string, // Raw trap type word
	quality:       int,
	complexity:    int,
	timer:         int,
	trigger_echo:  string,
	execute_echo:  string,
}

// A room from the #ROOMS section.
Room :: struct {
	vnum:            int,
	name:            string,
	description:     string,
	sector:          string,   // Raw sector word, e.g. "city"
	flags:           []string, // Raw room flag words from `R` lines, e.g. "LAW"
	exits:           [Direction]Maybe(Exit),
	replaced_exits:  []Exit,   // Earlier exits overwritten by a later exit in the same direction
	extras:          []Extra_Description,
	heal_rate:       int,      // Defaults to 100
	mana_rate:       int,      // Defaults to 100
	guild:           int,
	cabal:           string,
	owner:           string,
	alt_description: Maybe(Alt_Description),
	trap:            Maybe(Room_Trap),
	line:            int,
}
