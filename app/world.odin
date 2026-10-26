/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:fmt"
import "core:mem/virtual"

import "../clarity"
import "../components"
import "../layout"
import "../validation"
import "../workspace"

/*
 An open world as the GUI shows it: the workspace plus what the screens
 need that is worth computing once, on the loading thread. Everything but
 the workspace lives in `arena`; world_close frees it all.

 Like the workspace, a World is created and freed with the heap allocator
 (see loading.odin).
*/
World :: struct {
	ws:            ^workspace.Workspace,
	layouts:       []layout.Layout,          // layouts[i] lays out ws.areas[i]
	marks:         [][]components.Room_Mark, // marks[i][r]: area i's room r
	labels:        []string,                 // Area picker entries ("Name (file)"), in area order
	picker:        []int,                    // Area indexes in picker order (area_order.odin)
	picker_labels: []string,                 // labels in picker order, for the picker
	rooms_by_vnum: map[int]Room_Ref,         // Every room in the world (first definition wins)
	findings:      []clarity.Reviewed_Finding, // This run's findings, merged with the review file
	room_findings: [][][]int,                // [area][room]: indexes into findings (ROOM_CHECKS only)
	area_map:      components.Area_Map_Data, // The map of areas (world_map.odin); state and current are the view's
	search_index:  []Search_Entry,           // Every room, for room search (search.odin)
	summary:       Summary,
	arena:         virtual.Arena,
}

// Where a room is: its area and its index in that area's rooms.
Room_Ref :: struct {
	area: int,
	room: int,
}

// Counts about a world for its summary.
Summary :: struct {
	rooms:        int,
	severities:   [validation.Severity]int,
	state_counts: [clarity.State]int,
}

// Open, validate and lay out a world. On failure the error text is
// allocated with the heap allocator and nothing else needs freeing.
world_open :: proc(paths: []string) -> (world: ^World, error: string) {
	context.allocator = runtime.heap_allocator()
	ws, err := workspace.open(paths)
	if err != nil {
		return nil, workspace.error_message(err)
	}
	world = new(World)
	world.ws = ws
	if virtual.arena_init_growing(&world.arena) != nil {
		world_close(world)
		return nil, fmt.aprint("out of memory")
	}
	allocator := virtual.arena_allocator(&world.arena)

	result := workspace.merge(ws, allocator)
	world.findings = result.findings
	world.rooms_by_vnum = make(map[int]Room_Ref, allocator)
	world.layouts = make([]layout.Layout, len(ws.areas), allocator)
	world.marks = make([][]components.Room_Mark, len(ws.areas), allocator)
	world.labels = make([]string, len(ws.areas), allocator)
	for area, i in ws.areas {
		world.layouts[i] = layout.compute(area, allocator)
		world.marks[i] = make([]components.Room_Mark, len(area.rooms), allocator)
		world.labels[i] = unique_label(world.labels[:i], area_label(area.header.name, ws.names[i], allocator), area.header.name, ws.names[i], allocator)
		world.summary.rooms += len(area.rooms)
		for room, r in area.rooms {
			if !(room.vnum in world.rooms_by_vnum) {
				world.rooms_by_vnum[room.vnum] = Room_Ref{i, r}
			}
		}
	}
	world.picker = area_picker_order(ws.areas, ws.names, allocator)
	world.picker_labels = make([]string, len(ws.areas), allocator)
	for area, i in world.picker {
		world.picker_labels[i] = world.labels[area]
	}
	index_room_findings(world, allocator)
	build_area_map(world, allocator)
	apply_filters(world, DEFAULT_FILTERS)
	world.search_index = build_search_index(world, allocator)
	world.summary.severities = validation.count_by_severity(ws.diagnostics)
	world.summary.state_counts = result.state_counts
	return world, ""
}

// Free a world. Safe to call with nil.
world_close :: proc(world: ^World) {
	if world == nil {
		return
	}
	context.allocator = runtime.heap_allocator()
	workspace.close(world.ws)
	virtual.arena_destroy(&world.arena)
	free(world)
}

// The first area in picker order that has rooms (0 if none do).
first_area_with_rooms :: proc(world: ^World) -> int {
	for area in world.picker {
		if len(world.ws.areas[area].rooms) > 0 {
			return area
		}
	}
	return 0
}

// `label`, or the same with the area's full path if an earlier area already
// has that label (loose files with the same name in different folders), so
// the picker can tell them apart.
@(private = "file")
unique_label :: proc(earlier: []string, label, name, path: string, allocator: runtime.Allocator) -> string {
	for other in earlier {
		if other == label {
			shown := components.display_text(name, allocator = context.temp_allocator)
			return fmt.aprintf("%s (%s)", shown, path, allocator = allocator)
		}
	}
	return label
}

// File each room-check finding under the room it is about, in its own
// area (two areas can reuse a vnum by mistake, so this goes by area).
@(private = "file")
index_room_findings :: proc(world: ^World, allocator: runtime.Allocator) {
	areas := world.ws.areas
	indexes := make([]map[int]int, len(areas), context.temp_allocator)
	lists := make([][][dynamic]int, len(areas), context.temp_allocator)
	for area, i in areas {
		indexes[i] = layout.vnum_index(area, context.temp_allocator)
		lists[i] = make([][dynamic]int, len(area.rooms), context.temp_allocator)
	}
	for f, n in world.findings {
		d := f.diagnostic
		if d.check not_in validation.ROOM_CHECKS {
			continue
		}
		if room, ok := indexes[d.area][d.vnum]; ok {
			if lists[d.area][room] == nil {
				lists[d.area][room] = make([dynamic]int, context.temp_allocator)
			}
			append(&lists[d.area][room], n)
		}
	}
	world.room_findings = make([][][]int, len(areas), allocator)
	for area, i in areas {
		world.room_findings[i] = make([][]int, len(area.rooms), allocator)
		for list, r in lists[i] {
			if len(list) > 0 {
				world.room_findings[i][r] = make([]int, len(list), allocator)
				copy(world.room_findings[i][r], list[:])
			}
		}
	}
}
