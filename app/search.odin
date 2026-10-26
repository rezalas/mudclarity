/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:strconv"
import "core:strings"

import "../components"

/*
 Finding rooms by vnum or name across the world. The index is built once
 per load; a search is a pass over it in step when the query changes,
 never in view. About 10k rooms take well under a millisecond.
*/

// Results shown at once; the rest are counted ("12 of 340").
SEARCH_LIMIT :: 12

// A room as search sees it.
Search_Entry :: struct {
	ref:  Room_Ref,
	vnum: int,
	name: string, // Display text, in lower case
}

// Every room of the world, in picker order and then file order, so
// results read like the picker. Allocated with `allocator`.
build_search_index :: proc(world: ^World, allocator: runtime.Allocator) -> []Search_Entry {
	count := 0
	for area in world.ws.areas {
		count += len(area.rooms)
	}
	index := make([]Search_Entry, count, allocator)
	n := 0
	for a in world.picker {
		for room, r in world.ws.areas[a].rooms {
			name := components.display_text(room.name, allocator = context.temp_allocator)
			index[n] = {Room_Ref{a, r}, room.vnum, strings.to_lower(strings.trim_space(name), allocator)}
			n += 1
		}
	}
	return index
}

// The rooms matching `query`, best first, at most `limit`, and how many
// matched in all. A query that is a vnum (`3001` or `#3001`) finds that
// room in every area that defines it, first; then names equal to the
// query, starting with it, and containing it (ignoring case). A blank
// query matches nothing. Allocated with `allocator`.
search_rooms :: proc(index: []Search_Entry, query: string, limit: int, allocator := context.allocator) -> (hits: []Room_Ref, total: int) {
	q := strings.to_lower(strings.trim_space(query), context.temp_allocator)
	if q == "" || limit <= 0 {
		return nil, 0
	}
	vnum, is_vnum := strconv.parse_int(strings.trim_prefix(q, "#"), 10)
	// Tiers: vnum, exact name, name prefix, name contains.
	tiers: [4][dynamic]Room_Ref
	for &tier in tiers {
		tier = make([dynamic]Room_Ref, context.temp_allocator)
	}
	for e in index {
		tier := -1
		switch {
		case is_vnum && e.vnum == vnum: tier = 0
		case e.name == q: tier = 1
		case strings.has_prefix(e.name, q): tier = 2
		case strings.contains(e.name, q): tier = 3
		}
		if tier < 0 {
			continue
		}
		total += 1
		if len(tiers[tier]) < limit {
			append(&tiers[tier], e.ref)
		}
	}
	out := make([dynamic]Room_Ref, 0, min(total, limit), allocator)
	for tier in tiers {
		for ref in tier {
			if len(out) == limit {
				break
			}
			append(&out, ref)
		}
	}
	return out[:], total
}
