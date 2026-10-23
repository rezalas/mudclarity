/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package models

// What a program or special procedure is attached to.
Program_Target :: enum u8 {
	Object, // I
	Room,   // R
	Area,   // A
	Mob,    // M
	Ignored_Spec, // S: present in #IMPROGS but skipped by the game's loader
}

// A line in #IMPROGS: `<I|R|M> <vnum> <type> <name>`, `A <type> <name>`,
// or `S <vnum> <name>` (ignored by the game).
Program_Binding :: struct {
	target:       Program_Target,
	vnum:         int, // 0 for Area bindings
	program_type: string,
	name:         string,
	line:         int,
}

// A line in #SPECS: `<M|I> <vnum> <spec_name>`.
Spec_Binding :: struct {
	target: Program_Target, // Mob or Object
	vnum:   int,
	name:   string,
	line:   int,
}
