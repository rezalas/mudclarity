/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:mem/virtual"
import "core:strconv"
import "core:strings"

import "../formats"
import "../models"

// A door, identified by room and direction.
@(private)
Door :: struct {
	room:      int,
	direction: models.Direction,
}

// A portal placed in a room by an OBJ reset.
@(private)
Portal :: struct {
	from_room: int,
	to_room:   int,
	object:    int,
	area:      int,
	line:      int,
}

// What the resets do to the world, used by the exit and reachability checks.
@(private)
Reset_Facts :: struct {
	placed_objects: map[int]bool, // Objects some reset puts into the world
	door_resets:    map[Door]models.Door_State,
	portals:        [dynamic]Portal,
}

// Check every area's resets in file order and collect Reset_Facts.
// Mirrors reset_room (riftshadow/code/db.c): missing vnums are skipped, and
// EQUIP/GIVE/FOLLOW act on the last mob reset in the room they attach to.
@(private)
check_resets :: proc(v: ^Validator) -> Reset_Facts {
	w := &v.world
	facts := Reset_Facts {
		placed_objects = make(map[int]bool, v.scratch),
		door_resets    = make(map[Door]models.Door_State, v.scratch),
		portals        = make([dynamic]Portal, v.scratch),
	}
	for area, a in w.areas {
		rooms_with_mob := make(map[int]bool, v.scratch)
		last_mob_room := 0
		for reset in area.resets {
			switch reset.command {
			case .Mob:
				check_mob_ref(v, a, reset, reset.vnum)
				check_room_ref(v, a, reset, reset.room)
				rooms_with_mob[reset.room] = true
				last_mob_room = reset.room
			case .Object:
				check_object_ref(v, a, reset, reset.vnum)
				check_room_ref(v, a, reset, reset.room)
				facts.placed_objects[reset.vnum] = true
				record_portal(v, &facts, a, reset)
			case .Put:
				check_object_ref(v, a, reset, reset.vnum)
				if container, ok := check_object_ref(v, a, reset, reset.container); ok {
					entry, known := formats.lookup_item_type(container.item_type)
					if !known || entry.name != "container" {
						report_default(v, .Put_Into_Non_Container, a, reset.line, reset.vnum, reset.container, "PUT targets object #%d, which is a %q, not a container", reset.container, container.item_type)
					}
				}
				facts.placed_objects[reset.vnum] = true
			case .Give, .Equip:
				check_object_ref(v, a, reset, reset.vnum)
				facts.placed_objects[reset.vnum] = true
				check_reset_has_mob(v, a, reset, rooms_with_mob, last_mob_room)
			case .Follow:
				check_reset_has_mob(v, a, reset, rooms_with_mob, last_mob_room)
			case .Door:
				room, _, found := find_room(w, reset.room)
				if !found {
					check_room_ref(v, a, reset, reset.room)
				} else if _, has_exit := room.exits[reset.direction].?; !has_exit {
					report_default(v, .Door_Reset_No_Exit, a, reset.line, reset.room, 0, "DOOR reset for %s, but room #%d has no exit that way; the game ignores it", formats.DIRECTION_NAMES[reset.direction], reset.room)
				}
				facts.door_resets[Door{reset.room, reset.direction}] = reset.door_state
			case .Randomize:
				check_room_ref(v, a, reset, reset.room)
			}
		}
	}
	return facts
}

// EQUIP, GIVE and FOLLOW attach to the room of the last MOB or OBJ reset and
// act on the last mob reset in that room. If an OBJ put a different room in
// context, they reach a different mob than the last MOB line, or none.
@(private)
check_reset_has_mob :: proc(v: ^Validator, a: int, reset: models.Reset, rooms_with_mob: map[int]bool, last_mob_room: int) {
	name := RESET_NAMES[reset.command]
	if reset.context_room == 0 || !rooms_with_mob[reset.context_room] {
		report_default(v, .Reset_Without_Mob, a, reset.line, reset.vnum, reset.context_room, "%s has no earlier MOB reset in its room; the game skips it", name)
	} else if reset.context_room != last_mob_room {
		report_default(v, .Reset_After_Object, a, reset.line, reset.vnum, reset.context_room, "%s follows an OBJ reset into room #%d, so it goes to the last mob reset there, not the mob loaded into #%d", name, reset.context_room, last_mob_room)
	}
}

@(private)
RESET_NAMES := [models.Reset_Command]string {
	.Mob       = "MOB",
	.Object    = "OBJ",
	.Put       = "PUT",
	.Give      = "GIVE",
	.Equip     = "EQUIP",
	.Door      = "DOOR",
	.Randomize = "RANDOM",
	.Follow    = "FOLLOW",
}

@(private)
check_mob_ref :: proc(v: ^Validator, a: int, reset: models.Reset, vnum: int) {
	if !has_mobile(&v.world, vnum) {
		severity := missing_severity(&v.world, vnum)
		report(v, .Reset_Missing_Mob, severity, a, reset.line, vnum, reset.room, "%s reset loads mob #%d, which doesn't exist%s", RESET_NAMES[reset.command], vnum, missing_note(severity))
	}
}

@(private)
check_object_ref :: proc(v: ^Validator, a: int, reset: models.Reset, vnum: int) -> (obj: ^models.Object, ok: bool) {
	obj, ok = find_object(&v.world, vnum)
	if !ok {
		severity := missing_severity(&v.world, vnum)
		report(v, .Reset_Missing_Object, severity, a, reset.line, vnum, reset.context_room, "%s reset uses object #%d, which doesn't exist%s", RESET_NAMES[reset.command], vnum, missing_note(severity))
	}
	return obj, ok
}

@(private)
check_room_ref :: proc(v: ^Validator, a: int, reset: models.Reset, vnum: int) {
	if _, _, found := find_room(&v.world, vnum); !found {
		severity := missing_severity(&v.world, vnum)
		report(v, .Reset_Missing_Room, severity, a, reset.line, vnum, reset.vnum, "%s reset targets room #%d, which doesn't exist%s", RESET_NAMES[reset.command], vnum, missing_note(severity))
	}
}

// Portals send players to the room in value[3] (act_ente.c); -1 is random.
@(private)
record_portal :: proc(v: ^Validator, facts: ^Reset_Facts, a: int, reset: models.Reset) {
	destination, is_portal := portal_destination(&v.world, reset)
	if !is_portal {
		return
	}
	if _, _, found := find_room(&v.world, destination); !found {
		severity := missing_severity(&v.world, destination)
		report(v, .Portal_Missing_Target, severity, a, reset.line, reset.vnum, destination, "portal #%d leads to room #%d, which doesn't exist%s", reset.vnum, destination, missing_note(severity))
		return
	}
	append(&facts.portals, Portal{from_room = reset.room, to_room = destination, object = reset.vnum, area = a, line = reset.line})
}

// The room an OBJ reset's object leads to, if it is a portal with a fixed
// destination (not -1, random). The destination may not exist.
@(private)
portal_destination :: proc(w: ^World, reset: models.Reset) -> (destination: int, ok: bool) {
	obj := find_object(w, reset.vnum) or_return
	entry, known := formats.lookup_item_type(obj.item_type)
	if !known || entry.name != "portal" {
		return 0, false
	}
	destination = object_value_int(obj.values[3]) or_return
	return destination, destination != -1
}

// A portal an OBJ reset places: from the reset's room to an existing room.
Placed_Portal :: struct {
	area:      int, // Index of the area whose reset places it
	from_room: int, // Vnum
	to_room:   int, // Vnum
	object:    int, // The portal object's vnum
	line:      int, // The reset's line
}

// Every portal that resets place and that leads to a room in `areas`, in
// area and reset order. Random portals (-1) and missing destinations are
// left out (validate reports the latter). Allocated with `allocator`.
placed_portals :: proc(areas: []^models.Area, allocator := context.allocator) -> []Placed_Portal {
	scratch_arena: virtual.Arena
	if virtual.arena_init_growing(&scratch_arena) != nil {
		return nil
	}
	defer virtual.arena_destroy(&scratch_arena)
	scratch := virtual.arena_allocator(&scratch_arena)
	v := Validator {
		out       = make([dynamic]Diagnostic, scratch), // Discarded: only the index is needed
		allocator = scratch,
		scratch   = scratch,
	}
	build_world(&v, areas, false)

	out := make([dynamic]Placed_Portal, allocator)
	for area, a in areas {
		for reset in area.resets {
			if reset.command != .Object || reset.room == 0 {
				continue
			}
			destination, is_portal := portal_destination(&v.world, reset)
			if !is_portal {
				continue
			}
			if _, _, found := find_room(&v.world, destination); found {
				append(&out, Placed_Portal{area = a, from_room = reset.room, to_room = destination, object = reset.vnum, line = reset.line})
			}
		}
	}
	return out[:]
}

// Portal values are read as flag tokens; a plain (optionally negative)
// number is a room vnum.
@(private)
object_value_int :: proc(value: models.Object_Value) -> (n: int, ok: bool) {
	switch v in value {
	case int:
		return v, true
	case string:
		return strconv.parse_int(v, 10)
	}
	return 0, false
}

// Check #IMPROGS and #SPECS references.
@(private)
check_programs :: proc(v: ^Validator) {
	w := &v.world
	for area, a in w.areas {
		for program in area.programs {
			switch program.target {
			case .Ignored_Spec:
				report_default(v, .Ignored_Program_Line, a, program.line, program.vnum, 0, "#IMPROGS 'S' lines are skipped by the game; move %q to #SPECS", program.name)
			case .Area:
			case .Mob:
				check_program_target(v, a, program.line, "mob", program.vnum, has_mobile(w, program.vnum), program.name)
			case .Object:
				check_program_target(v, a, program.line, "object", program.vnum, program.vnum in w.objects, program.name)
			case .Room:
				check_program_target(v, a, program.line, "room", program.vnum, program.vnum in w.rooms, program.name)
			}
		}
		for spec in area.specs {
			#partial switch spec.target {
			case .Mob:
				check_program_target(v, a, spec.line, "mob", spec.vnum, has_mobile(w, spec.vnum), spec.name)
			case .Object:
				check_program_target(v, a, spec.line, "object", spec.vnum, spec.vnum in w.objects, spec.name)
			}
		}
	}
}

@(private)
check_program_target :: proc(v: ^Validator, a, line: int, kind: string, vnum: int, exists: bool, name: string) {
	if exists {
		return
	}
	severity := missing_severity(&v.world, vnum)
	report(v, .Program_Missing_Target, severity, a, line, vnum, 0, "%q is attached to %s #%d, which doesn't exist%s", name, kind, vnum, missing_note(severity))
}

// Check area headers and that records fall inside their area's vnum range.
@(private)
check_records :: proc(v: ^Validator) {
	for area, a in v.world.areas {
		h := area.header
		if h.min_vnum > h.max_vnum {
			report_default(v, .Bad_Area_Header, a, h.line, 0, 0, "vnum range %d-%d is backwards", h.min_vnum, h.max_vnum)
			continue
		}
		if h.low_level > h.high_level {
			report_default(v, .Bad_Area_Header, a, h.line, 0, 0, "level range %d-%d is backwards", h.low_level, h.high_level)
		}
		for room in area.rooms {
			check_in_range(v, a, "room", room.vnum, room.line, h)
		}
		for mob in area.mobiles {
			check_in_range(v, a, "mob", mob.vnum, mob.line, h)
		}
		for obj in area.objects {
			check_in_range(v, a, "object", obj.vnum, obj.line, h)
		}
	}
}

@(private)
check_in_range :: proc(v: ^Validator, a: int, kind: string, vnum, line: int, h: models.Area_Header) {
	if vnum < h.min_vnum || vnum > h.max_vnum {
		report_default(v, .Vnum_Out_Of_Range, a, line, vnum, 0, "%s #%d is outside the area's vnum range %d-%d", kind, vnum, h.min_vnum, h.max_vnum)
	}
}

// True if a raw flag token contains `letter` (flags are letters, e.g. "ABC").
@(private)
has_flag_letter :: proc(token: string, letter: u8) -> bool {
	return strings.index_byte(token, letter) >= 0
}
