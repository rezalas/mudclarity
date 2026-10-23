/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:strings"

/*
 Room graph checks. Nodes are rooms; edges are exits to existing rooms plus
 portals placed by resets. Loops back into the same room are ignored.

 - Dead_End_Room: no edge out.
 - Orphan_Room: no edge in.
 - Entrances of an area are its rooms with an edge in from another area.
   With the whole world loaded, rooms not reachable from their area's
   entrances are Unreachable_Room, and an area with no entrance is
   Area_Without_Entrance. With part of the world loaded, entrances can't be
   known, so those two checks are skipped. In areas whose type is
   "unopened" they are Info, since those areas are closed on purpose.
*/

@(private)
Graph :: struct {
	refs:     [dynamic]Ref,   // Node id -> room
	ids:      map[int]int,    // Room vnum -> node id
	outgoing: [dynamic][dynamic]int,
	incoming: [dynamic]int,   // Count of edges in from other rooms
	entrance: [dynamic]bool,  // Has an edge in from another area
}

@(private)
build_graph :: proc(v: ^Validator, facts: ^Reset_Facts) -> Graph {
	w := &v.world
	g := Graph {
		refs     = make([dynamic]Ref, v.scratch),
		ids      = make(map[int]int, v.scratch),
		outgoing = make([dynamic][dynamic]int, v.scratch),
		incoming = make([dynamic]int, v.scratch),
		entrance = make([dynamic]bool, v.scratch),
	}
	// Nodes, in a stable order. Duplicate vnums map to their first room.
	for area, a in w.areas {
		for room, i in area.rooms {
			if ref := w.rooms[room.vnum]; ref != (Ref{a, i}) {
				continue
			}
			g.ids[room.vnum] = len(g.refs)
			append(&g.refs, Ref{a, i})
			append(&g.outgoing, make([dynamic]int, v.scratch))
			append(&g.incoming, 0)
			append(&g.entrance, false)
		}
	}
	for ref, id in g.refs {
		room := &w.areas[ref.area].rooms[ref.index]
		for maybe_exit in room.exits {
			exit := maybe_exit.? or_continue
			add_edge(&g, w, id, exit.target)
		}
	}
	for portal in facts.portals {
		if from, ok := g.ids[portal.from_room]; ok {
			add_edge(&g, w, from, portal.to_room)
		}
	}
	return g
}

@(private)
add_edge :: proc(g: ^Graph, w: ^World, from: int, to_vnum: int) {
	to, ok := g.ids[to_vnum]
	if !ok || to == from {
		return
	}
	append(&g.outgoing[from], to)
	g.incoming[to] += 1
	if g.refs[from].area != g.refs[to].area {
		g.entrance[to] = true
	}
}

@(private)
check_reachability :: proc(v: ^Validator, facts: ^Reset_Facts) {
	w := &v.world
	g := build_graph(v, facts)

	is_orphan := make([]bool, len(g.refs), v.scratch)
	for ref, id in g.refs {
		room := &w.areas[ref.area].rooms[ref.index]
		if len(g.outgoing[id]) == 0 {
			report_default(v, .Dead_End_Room, ref.area, room.line, room.vnum, 0, "room #%d has no way out; the game also stops mobs from entering it", room.vnum)
		}
		if g.incoming[id] == 0 {
			is_orphan[id] = true
			report_default(v, .Orphan_Room, ref.area, room.line, room.vnum, 0, "no exit or portal leads into room #%d", room.vnum)
		}
	}

	if !w.is_complete {
		return
	}
	// Breadth-first search from each area's entrances.
	visited := make([]bool, len(g.refs), v.scratch)
	queue := make([dynamic]int, v.scratch)
	for area, a in w.areas {
		if len(area.rooms) == 0 {
			continue
		}
		for &seen in visited {
			seen = false
		}
		clear(&queue)
		for ref, id in g.refs {
			if ref.area == a && g.entrance[id] {
				visited[id] = true
				append(&queue, id)
			}
		}
		// Unopened areas are closed to players on purpose, so being cut off
		// is expected there.
		unopened := strings.equal_fold(area.header.area_type, "unopened")
		severity := Severity.Info if unopened else .Warning
		note := " (the area is unopened)" if unopened else ""
		if len(queue) == 0 {
			report(v, .Area_Without_Entrance, severity, a, area.header.line, 0, 0, "no exit or portal from another area leads into %s%s", area.header.name, note)
			continue
		}
		for head := 0; head < len(queue); head += 1 {
			for next in g.outgoing[queue[head]] {
				if !visited[next] {
					visited[next] = true
					append(&queue, next)
				}
			}
		}
		for ref, id in g.refs {
			if ref.area == a && !visited[id] && !is_orphan[id] {
				room := &area.rooms[ref.index]
				report(v, .Unreachable_Room, severity, a, room.line, room.vnum, 0, "room #%d can't be reached from any entrance to the area%s", room.vnum, note)
			}
		}
	}
}
