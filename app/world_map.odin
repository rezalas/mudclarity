/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:path/filepath"
import "core:strings"

import "../components"
import "../layout"
import "../validation"

/*
 The area map's data, computed once per load: a circle per area (named,
 sized by its rooms, and marked by apply_filters) and a link wherever
 exits or placed portals lead from one area to another, laid out with
 layout.force_layout. Areas keep their indexes, as everywhere but the
 picker.
*/

// Fill world.area_map. Needs rooms_by_vnum. Everything is
// allocated with `allocator` (the world's arena).
build_area_map :: proc(world: ^World, allocator: runtime.Allocator) {
	areas := world.ws.areas
	m := &world.area_map
	m.names = make([]string, len(areas), allocator)
	m.rooms = make([]int, len(areas), allocator)
	m.is_unopened = make([]bool, len(areas), allocator)
	m.marks = make([]components.Room_Mark, len(areas), allocator) // Set by apply_filters
	radii := make([]f32, len(areas), context.temp_allocator)
	for area, i in areas {
		m.names[i] = area_map_name(area.header.name, world.ws.names[i], allocator)
		m.rooms[i] = len(area.rooms)
		m.is_unopened[i] = strings.equal_fold(area.header.area_type, "unopened")
		radii[i] = components.area_node_radius(m.rooms[i])
	}
	m.links = area_links(world, allocator)
	edges := make([]layout.Graph_Edge, len(m.links), context.temp_allocator)
	for link, i in m.links {
		edges[i] = {link.a, link.b, f32(link.exits_ab + link.exits_ba + link.portals_ab + link.portals_ba)}
	}
	m.positions = layout.force_layout(radii, edges, allocator)
}

// A circle's caption: the area's name, or its file's base name if it has
// none. Display text, safe to draw.
@(private = "file")
area_map_name :: proc(name, file: string, allocator: runtime.Allocator) -> string {
	shown := strings.trim_space(components.display_text(name, allocator = context.temp_allocator))
	if shown == "" {
		shown = filepath.base(file)
	}
	return strings.clone(shown, allocator)
}

// Links between areas, counted from every exit (look-only exits to vnum 0
// aside) and every placed portal whose two rooms are in different areas.
// In order of first appearance, so a world always gets the same links.
@(private = "file")
area_links :: proc(world: ^World, allocator: runtime.Allocator) -> []components.Area_Link {
	links := make([dynamic]components.Area_Link, allocator)
	index := make(map[[2]int]int, context.temp_allocator)
	link_for :: proc(links: ^[dynamic]components.Area_Link, index: ^map[[2]int]int, a, b: int) -> ^components.Area_Link {
		key := [2]int{min(a, b), max(a, b)}
		n, ok := index[key]
		if !ok {
			n = len(links)
			index[key] = n
			append(links, components.Area_Link{a = key[0], b = key[1]})
		}
		return &links[n]
	}

	for area, from in world.ws.areas {
		for room in area.rooms {
			for exit in room.exits {
				e := exit.? or_continue
				target, found := world.rooms_by_vnum[e.target]
				if e.target == 0 || !found || target.area == from {
					continue
				}
				link := link_for(&links, &index, from, target.area)
				if from < target.area {
					link.exits_ab += 1
				} else {
					link.exits_ba += 1
				}
			}
		}
	}
	for portal in validation.placed_portals(world.ws.areas, context.temp_allocator) {
		from := portal.area
		if ref, ok := world.rooms_by_vnum[portal.from_room]; ok {
			from = ref.area
		}
		target, found := world.rooms_by_vnum[portal.to_room]
		if !found || target.area == from {
			continue
		}
		link := link_for(&links, &index, from, target.area)
		if from < target.area {
			link.portals_ab += 1
		} else {
			link.portals_ba += 1
		}
	}
	return links[:]
}
