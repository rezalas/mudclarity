/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package models

// Highest vnum Riftshadow can store (vnums are a C `short`).
VNUM_MAX :: 32767

// Exit directions, in Riftshadow's `direction_table` order (tables.c).
// The numeric values match the game's door numbers, so keep this order.
Direction :: enum u8 {
	North,
	East,
	South,
	West,
	Up,
	Down,
}

// Dice expression written as `NdS+B` (count, sides, bonus).
Dice :: struct {
	count: int,
	sides: int,
	bonus: int,
}

// Extra description attached to a room or object (`E` lines).
Extra_Description :: struct {
	keyword:     string,
	description: string,
	line:        int,
}
