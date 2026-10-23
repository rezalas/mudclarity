/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package models

// A flag pair such as `ACT SENTINEL` or `CLASS warrior none none`.
// `extra` holds the two additional words read for warrior and sorcerer classes.
Mob_Flag :: struct {
	kind:  string,
	value: string,
	extra: [2]string,
	line:  int,
}

// One `LINE <delay> <type> text~` entry in a SPEECH block.
Speech_Line :: struct {
	delay:     int,
	line_type: string,
	text:      string,
}

// A `SPEECH <name> ... END` block.
Speech :: struct {
	name:  string,
	lines: []Speech_Line,
}

// `F <table> <flags>`: removes flags inherited from the race.
Mob_Flag_Removal :: struct {
	table: string,
	flags: string,
}

// `A <skill> <affect flag>`: a permanent affect.
Mob_Affect :: struct {
	skill: string,
	flag:  string,
}

// `B ...`: blocks entry through the mob's room.
Barred_Entry :: struct {
	criterion:    string,
	comparison:   string, // EQUALTO, LESSTHAN or GREATERTHAN
	value:        int,
	vnum:         int,
	message_type: string, // SAY, EMOTE or ECHO
	message:      string,
	message_two:  string, // Only for ECHO
}

// `SHOPKEEPER OPEN <h> CLOSE <h> EXIT <dir>`.
Shop :: struct {
	open_hour:  int,
	close_hour: int,
	exit:       string, // Raw direction word
}

// A mob definition from the #MOBS section.
Mobile :: struct {
	vnum:              int,
	keywords:          string,
	short_description: string,
	long_description:  string,
	description:       string,
	alignment:         int,
	group:             int,
	xp_mod:            int,
	race:              string,
	level:             int,
	hit:               Dice,
	damage:            Dice,
	hitroll:           int,
	damage_mod:        int,
	damage_type:       string,
	armor:             [4]int, // pierce, bash, slash, exotic
	start_position:    string,
	sex:               string,
	wealth:            string,
	form:              string, // Raw flag token
	parts:             string, // Raw flag token
	size:              string,
	flags:             []Mob_Flag,
	speeches:          []Speech,
	flag_removals:     []Mob_Flag_Removal,
	affects:           []Mob_Affect,
	casts:             []string,
	cabal:             string,
	barred:            Maybe(Barred_Entry),
	notes:             string,
	level_limit:       Maybe([2]int), // `LIMIT <low> <high>`
	shop:              Maybe(Shop),
	teaches:           []string,
	attack_yell:       string,
	line:              int,
}
