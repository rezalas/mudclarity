/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:mem/virtual"
import "core:slice"

import "../models"

// Validate a set of areas and return every finding, sorted by area, line
// and check. `is_complete` says whether these are all the game's areas
// (the whole area.lst); it decides how references to unknown vnums are
// reported (see missing_severity).
//
// The result and its messages are allocated with `allocator` and do not
// point into the areas, so they stay valid after the areas are unloaded.
validate :: proc(areas: []^models.Area, is_complete: bool, allocator := context.allocator) -> []Diagnostic {
	scratch_arena: virtual.Arena
	if virtual.arena_init_growing(&scratch_arena) != nil {
		return nil
	}
	defer virtual.arena_destroy(&scratch_arena)

	v := Validator {
		out       = make([dynamic]Diagnostic, allocator),
		allocator = allocator,
		scratch   = virtual.arena_allocator(&scratch_arena),
	}
	build_world(&v, areas, is_complete)
	check_records(&v)
	facts := check_resets(&v)
	check_exits(&v, &facts)
	check_reachability(&v, &facts)
	check_programs(&v)

	slice.stable_sort_by(v.out[:], proc(x, y: Diagnostic) -> bool {
		if x.area != y.area {
			return x.area < y.area
		}
		if x.line != y.line {
			return x.line < y.line
		}
		return x.check < y.check
	})
	return v.out[:]
}

// Count diagnostics per severity.
count_by_severity :: proc(diagnostics: []Diagnostic) -> (counts: [Severity]int) {
	for d in diagnostics {
		counts[d.severity] += 1
	}
	return counts
}

// Count diagnostics per check.
count_by_check :: proc(diagnostics: []Diagnostic) -> (counts: [Check]int) {
	for d in diagnostics {
		counts[d.check] += 1
	}
	return counts
}
