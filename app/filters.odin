/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "../clarity"
import "../components"
import "../validation"

/*
 Which findings the screens show: a set of severities and a set of review
 states. The room graph's outlines, the area map's outlines and the area
 inspector's counts all follow them. Plain values, so settings can keep
 them later.
*/
Filters :: struct {
	severities: bit_set[validation.Severity],
	states:     bit_set[clarity.State],
}

// Everything but accepted findings: accepted means "intended", so they
// are hidden until asked for.
DEFAULT_FILTERS :: Filters {
	severities = {.Error, .Warning, .Info},
	states     = {.Open, .Flagged, .Needs_Review},
}

// Whether `f` is shown under `filters`.
shows :: proc(filters: Filters, f: clarity.Reviewed_Finding) -> bool {
	return f.diagnostic.severity in filters.severities && f.state in filters.states
}

// Mark each room and each area with its worst finding that `filters`
// shows: rooms by their room-check findings, areas by all of theirs.
// Overwrites the marks in place, so it can run again when the filters
// change.
apply_filters :: proc(world: ^World, filters: Filters) {
	for &rooms in world.marks {
		for &mark in rooms {
			mark = {}
		}
	}
	for &mark in world.area_map.marks {
		mark = {}
	}
	for rooms, a in world.room_findings {
		for list, r in rooms {
			for n in list {
				f := world.findings[n]
				if shows(filters, f) {
					worsen(&world.marks[a][r], f.diagnostic.severity)
				}
			}
		}
	}
	for f in world.findings {
		a := f.diagnostic.area
		if a >= 0 && a < len(world.area_map.marks) && shows(filters, f) {
			worsen(&world.area_map.marks[a], f.diagnostic.severity)
		}
	}
}

@(private = "file")
worsen :: proc(mark: ^components.Room_Mark, severity: validation.Severity) {
	// Severity order is Error < Warning < Info: lower is worse.
	if !mark.has_finding || severity < mark.worst {
		mark^ = {has_finding = true, worst = severity}
	}
}
