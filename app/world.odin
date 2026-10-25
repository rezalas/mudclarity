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
	ws:      ^workspace.Workspace,
	layouts: []layout.Layout,         // layouts[i] lays out ws.areas[i]
	marks:   [][]components.Room_Mark, // marks[i][r]: area i's room r
	labels:  []string,                // Area picker entries, in area order
	summary: Summary,
	arena:   virtual.Arena,
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

	result := workspace.merge(ws, context.temp_allocator)
	world.layouts = make([]layout.Layout, len(ws.areas), allocator)
	world.marks = make([][]components.Room_Mark, len(ws.areas), allocator)
	world.labels = make([]string, len(ws.areas), allocator)
	for area, i in ws.areas {
		world.layouts[i] = layout.compute(area, allocator)
		world.marks[i] = make([]components.Room_Mark, len(area.rooms), allocator)
		name := components.display_text(area.header.name, allocator = context.temp_allocator)
		world.labels[i] = fmt.aprintf("%s · %s", ws.names[i], name, allocator = allocator)
		world.summary.rooms += len(area.rooms)
	}
	mark_rooms(world, result)
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

// The index of the first area that has rooms (0 if none do).
first_area_with_rooms :: proc(world: ^World) -> int {
	for area, i in world.ws.areas {
		if len(area.rooms) > 0 {
			return i
		}
	}
	return 0
}

// Mark each room with its worst finding that isn't accepted. Only checks
// whose vnum is a room count (validation.ROOM_CHECKS).
@(private = "file")
mark_rooms :: proc(world: ^World, result: clarity.Review_Result) {
	indexes := make([]map[int]int, len(world.ws.areas), context.temp_allocator)
	for area, i in world.ws.areas {
		indexes[i] = layout.vnum_index(area, context.temp_allocator)
	}
	for f in result.findings {
		d := f.diagnostic
		if f.state == .Accepted || d.check not_in validation.ROOM_CHECKS {
			continue
		}
		room, ok := indexes[d.area][d.vnum]
		if !ok {
			continue
		}
		mark := &world.marks[d.area][room]
		// Severity order is Error < Warning < Info: lower is worse.
		if !mark.has_finding || d.severity < mark.worst {
			mark^ = {has_finding = true, worst = d.severity}
		}
	}
}
