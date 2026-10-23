/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "base:runtime"
import "core:fmt"

import "../models"

// Location of a record: index of its area, and of the record in that area.
Ref :: struct {
	area:  int,
	index: int,
}

// The loaded areas plus indexes from vnum to record. Duplicate vnums keep
// the first definition, matching the game's lookup by vnum.
@(private)
World :: struct {
	areas:       []^models.Area,
	is_complete: bool, // The whole area.lst is loaded
	rooms:       map[int]Ref,
	mobiles:     map[int]Ref,
	objects:     map[int]Ref,
}

// Collects diagnostics while checks run.
@(private)
Validator :: struct {
	world:     World,
	out:       [dynamic]Diagnostic,
	allocator: runtime.Allocator, // For diagnostics and their messages
	scratch:   runtime.Allocator, // For working data, freed after validation
}

@(private)
report :: proc(v: ^Validator, check: Check, severity: Severity, area, line, vnum, related: int, format: string, args: ..any) {
	append(
		&v.out,
		Diagnostic {
			check = check,
			severity = severity,
			area = area,
			line = line,
			vnum = vnum,
			related_vnum = related,
			message = fmt.aprintf(format, ..args, allocator = v.allocator),
		},
	)
}

// Report with the check's default severity.
@(private)
report_default :: proc(v: ^Validator, check: Check, area, line, vnum, related: int, format: string, args: ..any) {
	report(v, check, CHECK_SEVERITY[check], area, line, vnum, related, format, ..args)
}

// Severity for a reference to a vnum that isn't loaded. It is an Error if
// every area is loaded, or if the vnum falls inside a loaded area's range.
// Otherwise it may belong to an area that wasn't loaded, so it is Info.
@(private)
missing_severity :: proc(w: ^World, vnum: int) -> Severity {
	if w.is_complete {
		return .Error
	}
	for area in w.areas {
		h := area.header
		if h.min_vnum <= h.max_vnum && vnum >= h.min_vnum && vnum <= h.max_vnum {
			return .Error
		}
	}
	return .Info
}

// Explanation appended to messages about vnums that aren't loaded.
@(private)
missing_note :: proc(severity: Severity) -> string {
	return " (may be in an area that isn't loaded)" if severity == .Info else ""
}

// Build vnum indexes and report duplicate vnums.
@(private)
build_world :: proc(v: ^Validator, areas: []^models.Area, is_complete: bool) {
	w := &v.world
	w.areas = areas
	w.is_complete = is_complete
	w.rooms = make(map[int]Ref, v.scratch)
	w.mobiles = make(map[int]Ref, v.scratch)
	w.objects = make(map[int]Ref, v.scratch)

	for area, a in areas {
		for room, i in area.rooms {
			index_record(v, &w.rooms, "room", a, i, room.vnum, room.line)
		}
		for mob, i in area.mobiles {
			index_record(v, &w.mobiles, "mob", a, i, mob.vnum, mob.line)
		}
		for obj, i in area.objects {
			index_record(v, &w.objects, "object", a, i, obj.vnum, obj.line)
		}
	}
}

@(private)
index_record :: proc(v: ^Validator, index: ^map[int]Ref, kind: string, area, i, vnum, line: int) {
	if first, exists := index[vnum]; exists {
		first_area := v.world.areas[first.area]
		report_default(v, .Duplicate_Vnum, area, line, vnum, vnum, "%s #%d is already defined in %s; the game refuses to boot", kind, vnum, first_area.source_name)
		return
	}
	index[vnum] = Ref{area, i}
}

@(private)
find_room :: proc(w: ^World, vnum: int) -> (room: ^models.Room, ref: Ref, ok: bool) {
	ref = w.rooms[vnum] or_return
	return &w.areas[ref.area].rooms[ref.index], ref, true
}

@(private)
find_object :: proc(w: ^World, vnum: int) -> (obj: ^models.Object, ok: bool) {
	ref := w.objects[vnum] or_return
	return &w.areas[ref.area].objects[ref.index], true
}

@(private)
has_mobile :: proc(w: ^World, vnum: int) -> bool {
	return vnum in w.mobiles
}
