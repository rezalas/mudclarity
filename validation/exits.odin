/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "../formats"
import "../models"

// Exit flag letters (exit_flags in riftshadow/code/tables.c).
@(private)
EXIT_FLAG_ISDOOR :: 'A'
@(private)
EXIT_FLAG_CLOSED :: 'B'
@(private)
EXIT_FLAG_LOCKED :: 'C'

@(private)
REVERSE_DIRECTION := [models.Direction]models.Direction {
	.North = .South,
	.East  = .West,
	.South = .North,
	.West  = .East,
	.Up    = .Down,
	.Down  = .Up,
}

// An exit to vnum 0 only gives a direction a description: players can look
// that way but not go. Riftshadow's area editor writes all six exits, so
// most rooms have several of these. They are not reported as broken.
@(private)
is_look_only :: proc(exit: models.Exit) -> bool {
	return exit.target == 0
}

// Check every exit: targets, return paths, replaced exits, doors and keys.
@(private)
check_exits :: proc(v: ^Validator, facts: ^Reset_Facts) {
	w := &v.world
	for area, a in w.areas {
		for &room in area.rooms {
			for replaced in room.replaced_exits {
				report_default(v, .Replaced_Exit, a, replaced.line, room.vnum, replaced.target, "room #%d has a second %s exit; this one (to #%d) is ignored", room.vnum, formats.DIRECTION_NAMES[replaced.direction], replaced.target)
			}
			for maybe_exit, dir in room.exits {
				exit := maybe_exit.? or_continue
				if is_look_only(exit) {
					continue
				}
				check_exit_target(v, a, &room, dir, exit)
				check_door(v, a, &room, dir, exit, facts)
			}
		}
	}
}

@(private)
check_exit_target :: proc(v: ^Validator, a: int, room: ^models.Room, dir: models.Direction, exit: models.Exit) {
	w := &v.world
	dir_name := formats.DIRECTION_NAMES[dir]
	if exit.target == 0 {
		return // Look-only exit (see is_look_only)
	}
	if exit.target < 0 {
		// fix_exits treats these as no exit at all.
		report_default(v, .Broken_Exit, a, exit.line, room.vnum, exit.target, "%s exit from #%d leads to vnum %d; the game treats it as no exit", dir_name, room.vnum, exit.target)
		return
	}
	target, _, found := find_room(w, exit.target)
	if !found {
		severity := missing_severity(w, exit.target)
		report(v, .Broken_Exit, severity, a, exit.line, room.vnum, exit.target, "%s exit from #%d leads to room #%d, which doesn't exist%s", dir_name, room.vnum, exit.target, missing_note(severity))
		return
	}
	if target.vnum == room.vnum {
		return // A loop back into the same room needs no return path.
	}
	reverse := REVERSE_DIRECTION[dir]
	if back, has_back := target.exits[reverse].?; has_back && !is_look_only(back) && back.target != room.vnum {
		report_default(v, .Mismatched_Return, a, exit.line, room.vnum, exit.target, "%s from #%d leads to #%d, but %s from #%d leads to #%d", dir_name, room.vnum, target.vnum, formats.DIRECTION_NAMES[reverse], target.vnum, back.target)
		return
	}
	for maybe_back in target.exits {
		if back, ok := maybe_back.?; ok && back.target == room.vnum {
			return
		}
	}
	report_default(v, .One_Way_Exit, a, exit.line, room.vnum, exit.target, "%s from #%d leads to #%d, which has no exit back", dir_name, room.vnum, target.vnum)
}

// What an exit's flags, as written in the file, say about its door. Door
// resets can also make or lock a door; check_door takes those into account.
Door_Flags :: struct {
	is_door:   bool, // A door of any kind (flag A, or closed or locked)
	is_closed: bool,
	is_locked: bool,
}

door_flags :: proc(exit: models.Exit) -> Door_Flags {
	closed := has_flag_letter(exit.flags, EXIT_FLAG_CLOSED)
	locked := has_flag_letter(exit.flags, EXIT_FLAG_LOCKED)
	return Door_Flags{is_door = has_flag_letter(exit.flags, EXIT_FLAG_ISDOOR) || closed || locked, is_closed = closed, is_locked = locked}
}

// Locked doors need a key that exists and that something places in the world.
// A key below zero means the door can never be locked or unlocked (act_move.c).
@(private)
check_door :: proc(v: ^Validator, a: int, room: ^models.Room, dir: models.Direction, exit: models.Exit, facts: ^Reset_Facts) {
	reset_state, has_door_reset := facts.door_resets[Door{room.vnum, dir}]
	flags := door_flags(exit)
	if !has_door_reset && !flags.is_door {
		return
	}
	is_locked := flags.is_locked || (has_door_reset && reset_state == .Locked)
	dir_name := formats.DIRECTION_NAMES[dir]

	if exit.key > 0 {
		if _, found := find_object(&v.world, exit.key); !found {
			severity := missing_severity(&v.world, exit.key)
			report(v, .Missing_Key, severity, a, exit.line, room.vnum, exit.key, "%s door in #%d uses key #%d, which doesn't exist%s", dir_name, room.vnum, exit.key, missing_note(severity))
		} else if is_locked && !facts.placed_objects[exit.key] {
			report_default(v, .Key_Never_Placed, a, exit.line, room.vnum, exit.key, "%s door in #%d is locked with key #%d, but no reset places that key", dir_name, room.vnum, exit.key)
		}
		return
	}
	if is_locked {
		reason := "it can never be unlocked" if exit.key < 0 else "no key opens it"
		report_default(v, .Locked_Door_No_Key, a, exit.line, room.vnum, exit.key, "%s door in #%d is locked with key %d; %s", dir_name, room.vnum, exit.key, reason)
	}
}
